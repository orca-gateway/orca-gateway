package com.orcagateway.core.subpage

import com.orcagateway.core.json.JsonValue
import java.math.BigDecimal
import kotlin.math.abs

/**
 * The pure core of the SubPage widget and the updateSubPage action.
 *
 * No Android, no I/O: [JsonValue] in, [JsonValue] out. The contract (S1 to S8) and the normative table of
 * rewritten fields are in `schema/fixtures/subpage/README.md`; every function here is pinned by the fixtures of
 * that folder, and the Flutter (`sub_page_core.dart`) and Swift SDKs carry the same functions one to one.
 *
 * A page mounted in a SubPage lives in the host page's node store and page state. What keeps the two apart is
 * a prefix, put by [merge] in front of every id and every page-state key of the mounted page.
 *
 * Nodes and actions are raw JSON objects, not the typed models: the rewrite walks every field, those of custom
 * actions included, and copies what it does not know as it is.
 */
public object SubPage {
    /**
     * The prefix of a page mounted in the SubPage whose node id is [subPageKey]: `K:` for page 0, `K#j:` for
     * the [join]-th joined page (from 1).
     */
    public fun prefix(subPageKey: String, join: Int = 0): String = if (join == 0) "$subPageKey:" else "$subPageKey#$join:"

    /**
     * Rewrites a page [response] (`components` and `state`) for mounting under [prefix]: ids, children, slot
     * props, page-state references and keys, watches and node-addressing ids get the prefix; each page-scoped
     * state definition gives one seed. The response is not changed.
     */
    public fun merge(prefix: String, response: JsonValue): SubPageMerge {
        val nodes = response["components"].arrayValue.orEmpty().mapNotNull { it.objectValue }.map { node(prefix, it) }
        val state = LinkedHashMap<String, JsonValue>()
        for (def in response["state"].arrayValue.orEmpty()) {
            val key = def["key"].stringValue ?: continue
            if (isPage(def["scope"])) state[prefix + key] = def["initial"]
        }
        return SubPageMerge(nodes, state)
    }

    /**
     * Rewrites a bare action list (what a server returns to a serverAction fired inside the page mounted under
     * [prefix]) by the rules [merge] applies to a node's actions. The list is not changed.
     */
    public fun rewriteActions(prefix: String, actions: List<JsonValue>): List<JsonValue> = actions.map { walk(prefix, it, true) }

    /**
     * The fetch of [pageId] with the resolved [params]. The path is the page id without its leading slashes,
     * each segment between slashes percent-encoded (so a `?` or a `#` in it stays in the path). The query: keys
     * sorted by code point, keys and values percent-encoded, null params left out.
     */
    public fun request(pageId: String, params: Map<String, JsonValue>? = null): SubPageRequest {
        val query = params.orEmpty().filterValues { !it.isNull }.keys.sortedWith(codePointOrder)
            .joinToString("&") { "${percent(it)}=${percent(text(params!!.getValue(it)))}" }
        val path = pageId.trimStart('/').split('/').joinToString("/") { percent(it) }
        return SubPageRequest(path, query)
    }

    /**
     * The mounted page a node belongs to: the longest of [prefixes] that [sourceId] starts with (an id equal to
     * a prefix starts with it), or null (a host node, an empty id, or no source).
     */
    public fun prefixOf(prefixes: Iterable<String>, sourceId: String?): String? {
        if (sourceId == null) return null
        var best: String? = null
        for (prefix in prefixes) {
            if (sourceId.startsWith(prefix) && (best == null || prefix.length > best.length)) best = prefix
        }
        return best
    }

    /**
     * The page state a serverAction posts when its source belongs to [prefix] (see [prefixOf]): the keys under
     * the prefix, with the prefix removed. A null prefix posts the whole [pageState].
     */
    public fun postedState(prefix: String?, pageState: Map<String, JsonValue>): Map<String, JsonValue> {
        if (prefix == null) return pageState
        val out = LinkedHashMap<String, JsonValue>()
        for ((key, value) in pageState) {
            if (key.startsWith(prefix)) out[key.substring(prefix.length)] = value
        }
        return out
    }

    /** Code point order, which is the order of the UTF-8 bytes (and not the UTF-16 order of `String.compareTo`). */
    public val codePointOrder: Comparator<String> = Comparator { a, b ->
        var i = 0
        var j = 0
        var result = 0
        while (result == 0 && i < a.length && j < b.length) {
            val x = a.codePointAt(i)
            val y = b.codePointAt(j)
            result = x.compareTo(y)
            i += Character.charCount(x)
            j += Character.charCount(y)
        }
        if (result != 0) result else (a.length - i).compareTo(b.length - j)
    }

    // ── The rewrite ─────────────────────────────────────────────

    private fun isPage(scope: JsonValue): Boolean = scope.isNull || scope.stringValue == "page"

    /** Props that name a page-state key or a node of the page as a plain string. */
    private val nodeProps = setOf("animationId", "stateKey")

    /** Actions whose `key` is a state key in `scope`. */
    private val stateActions = setOf("setState", "clearState", "persistState")

    /** Per action kind, the field that holds the id of a node of the page. */
    private val idFields = mapOf(
        "openDialog" to "dialogId",
        "animateForward" to "animationId",
        "animateReverse" to "animationId",
        "updateComponent" to "id",
        "deleteComponent" to "id",
        "addComponent" to "parentId",
        "replaceComponent" to "targetId",
        "updateSubPage" to "subPageId",
    )

    private fun node(prefix: String, node: Map<String, JsonValue>): JsonValue.Object {
        val out = LinkedHashMap(node)
        val children = node["children"]?.arrayValue.orEmpty().mapNotNull { it.stringValue }
        val props = node["props"]?.objectValue
        node["id"]?.stringValue?.let { out["id"] = JsonValue.String(prefix + it) }
        if ("children" in node) out["children"] = JsonValue.Array(children.map { JsonValue.String(prefix + it) })
        if (props != null) out["props"] = props(prefix, props, children)

        val pageKeys = HashSet<String>()
        val appKeys = HashSet<String>()
        if (props != null) refs(JsonValue.Object(props), pageKeys, appKeys)
        node["watches"]?.arrayValue?.let { watches ->
            val rewritten = ArrayList<JsonValue>()
            for (watch in watches) {
                val key = watch.stringValue
                if (key != null && key in pageKeys) {
                    rewritten += JsonValue.String(prefix + key)
                    if (key in appKeys) rewritten += watch
                } else {
                    rewritten += watch
                }
            }
            out["watches"] = JsonValue.Array(rewritten)
        }
        node["actions"]?.let { out["actions"] = walk(prefix, it, true) }
        return JsonValue.Object(out)
    }

    /**
     * A props map: a string that is one of the node's [children] is a slot, the strings of [nodeProps] name a
     * key or a node; everything else is walked.
     */
    private fun props(prefix: String, props: Map<String, JsonValue>, children: List<String>): JsonValue.Object {
        val out = LinkedHashMap<String, JsonValue>()
        for ((key, value) in props) {
            val s = value.stringValue
            out[key] = if (s != null && (s in children || key in nodeProps)) JsonValue.String(prefix + s) else walk(prefix, value, false)
        }
        return JsonValue.Object(out)
    }

    /** A static Value is data, whatever it holds and with or without a `value`. */
    private fun isStatic(map: Map<String, JsonValue>): Boolean = map["type"]?.stringValue == "static"

    /**
     * Deep copy of [value] with every page-state reference and every targeted tween rewritten; with [actions],
     * the action fields too.
     */
    private fun walk(prefix: String, value: JsonValue, actions: Boolean): JsonValue {
        if (value is JsonValue.Array) return JsonValue.Array(value.items.map { walk(prefix, it, actions) })
        val map = value.objectValue ?: return value
        if (isStatic(map)) return value

        val type = map["type"]?.stringValue
        val out = LinkedHashMap<String, JsonValue>()
        for ((key, v) in map) {
            out[key] = when {
                actions && type == "updateComponent" && key == "props" && v is JsonValue.Object ->
                    props(prefix, v.members, emptyList())
                actions && (type == "addComponent" || type == "replaceComponent") && key == "components" && v is JsonValue.Array ->
                    JsonValue.Array(v.items.map { n -> n.objectValue?.let { node(prefix, it) } ?: n })
                else -> walk(prefix, v, actions)
            }
        }

        fun put(field: String) {
            out[field]?.stringValue?.let { out[field] = JsonValue.String(prefix + it) }
        }

        val pageScoped = isPage(value["scope"])
        if (type == "state" && pageScoped) put("key")
        if (type == "tween" || type == "tweenSequence") put("animationId")
        if (actions) {
            if (type in stateActions && pageScoped) put("key")
            idFields[type]?.let { put(it) }
        }
        return JsonValue.Object(out)
    }

    /** Collects the keys of the state references under [value], by scope. */
    private fun refs(value: JsonValue, pageKeys: MutableSet<String>, appKeys: MutableSet<String>) {
        if (value is JsonValue.Array) {
            value.items.forEach { refs(it, pageKeys, appKeys) }
        } else if (value is JsonValue.Object && !isStatic(value.members)) {
            val key = value["key"].stringValue
            if (value["type"].stringValue == "state" && key != null) {
                (if (isPage(value["scope"])) pageKeys else appKeys) += key
            }
            value.members.values.forEach { refs(it, pageKeys, appKeys) }
        }
    }

    // ── The query string ────────────────────────────────────────

    private const val UNRESERVED = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    private const val HEX = "0123456789ABCDEF"

    /** RFC 3986 percent-encoding of everything but the unreserved characters. */
    private fun percent(text: String): String = buildString {
        for (byte in text.toByteArray(Charsets.UTF_8)) {
            val b = byte.toInt() and 0xFF
            if (b < 0x80 && b.toChar() in UNRESERVED) {
                append(b.toChar())
            } else {
                append('%').append(HEX[b shr 4]).append(HEX[b and 0xF])
            }
        }
    }

    /** A resolved param as text: a string as it is, a list or a map as JSON. */
    private fun text(value: JsonValue): String = value.stringValue ?: json(value)

    /** 2^53: up to it, either way, every whole number is exact in a double. */
    private const val MAX_WHOLE = 9007199254740992.0

    /**
     * A whole number up to 2^53 as its digits, however it was spelt (`3.0`, `1e3`, `-0.0`); any other number as
     * the shortest decimal that reads back the same, in plain form: `Double.toString` uses an exponent from
     * 10^7 up and below 10^-3, so it goes through [BigDecimal]. Outside 0.0001 to 2^53 the contract pins none.
     */
    private fun number(d: Double): String = when {
        !d.isFinite() -> d.toString()
        d == Math.rint(d) && abs(d) <= MAX_WHOLE -> d.toLong().toString()
        else -> BigDecimal(d.toString()).stripTrailingZeros().toPlainString()
    }

    /** Compact JSON with sorted keys, the same on every platform. */
    private fun json(value: JsonValue): String = when (value) {
        JsonValue.Null -> "null"
        is JsonValue.Bool -> if (value.value) "true" else "false"
        is JsonValue.Int -> value.value.toString()
        is JsonValue.Double -> number(value.value)
        is JsonValue.String -> quoted(value.value)
        is JsonValue.Array -> value.items.joinToString(",", "[", "]") { json(it) }
        is JsonValue.Object -> value.members.keys.sortedWith(codePointOrder)
            .joinToString(",", "{", "}") { "${quoted(it)}:${json(value.members.getValue(it))}" }
    }

    /** A JSON string: only the quote, the backslash and the control characters are escaped. */
    private fun quoted(text: String): String = buildString {
        append('"')
        for (unit in text) {
            when {
                unit == '"' -> append("\\\"")
                unit == '\\' -> append("\\\\")
                unit == '\b' -> append("\\b")
                unit == '\u000C' -> append("\\f")
                unit == '\n' -> append("\\n")
                unit == '\r' -> append("\\r")
                unit == '\t' -> append("\\t")
                unit.code < 0x20 -> append("\\u").append(unit.code.toString(16).padStart(4, '0'))
                else -> append(unit)
            }
        }
        append('"')
    }
}

/** What [SubPage.merge] gives: the rewritten [nodes], in the response's order (the root first), and the [state] seeds (prefixed key to initial value). */
public class SubPageMerge(public val nodes: List<JsonValue.Object>, public val state: Map<String, JsonValue>)

/** Where a sub-page is fetched: [path] on the normal page route and [query], without its question mark, empty when no param is sent. */
public class SubPageRequest(public val path: String, public val query: String) {
    /** The path with its query: what is handed to the page fetch. */
    public val location: String get() = if (query.isEmpty()) path else "$path?$query"
}

/** One page mounted in a SubPage: its [prefix] and its merged [nodes], the root first. */
public class SubPageMounted(public val prefix: String, public val nodes: List<JsonValue.Object>) {
    /** Id of the node to draw, null for a page without components. */
    public val rootId: String? get() = nodes.firstOrNull()?.get("id")?.stringValue
}

/**
 * What one [SubPageMounts.apply] asks of the host page, in this order: take [removedNodeIds] out of the node
 * store and [removedStateKeys] out of the page state, then put [nodes] in the store and write [seeds].
 * [prefix] is the prefix of the page the step mounted.
 */
public class SubPageChange(
    public val prefix: String,
    public val nodes: List<JsonValue.Object>,
    public val seeds: Map<String, JsonValue>,
    public val removedNodeIds: List<String>,
    public val removedStateKeys: List<String>,
)

/** The pages mounted in one SubPage, oldest first. [subPageKey] is the id of the SubPage node in the host page's node store. */
public class SubPageMounts(public val subPageKey: String) {
    private val mounted = ArrayList<SubPageMounted>()
    private var joins = 0

    /** The mounted pages, oldest first. */
    public val pages: List<SubPageMounted> get() = mounted.toList()

    /** Prefix of each mounted page, oldest first. */
    public val prefixes: List<String> get() = mounted.map { it.prefix }

    /** Root id of each mounted page that has one: the drawing order. */
    public val roots: List<String> get() = mounted.mapNotNull { it.rootId }

    /** Id of every node this SubPage has in the host's node store. */
    public val nodeIds: List<String> get() = mounted.flatMap { page -> page.nodes.mapNotNull { it["id"].stringValue } }

    /**
     * Mounts a fetched [response]. Mode `join`, with a page already mounted, adds it after the others under the
     * next `K#j:` prefix and removes nothing. Any other mode (the first load is a `replace`) removes every
     * mounted page and every key of [pageStateKeys] under `K:` or `K#<digits>:`, and mounts the response as
     * page 0.
     */
    public fun apply(mode: String, response: JsonValue, pageStateKeys: Iterable<String>): SubPageChange {
        val join = mode == "join" && mounted.isNotEmpty()
        val removedNodeIds = if (join) emptyList() else nodeIds
        val removedStateKeys = if (join) emptyList() else pageStateKeys.filter { owns(it) }
        if (!join) {
            mounted.clear()
            joins = 0
        }
        val prefix = SubPage.prefix(subPageKey, if (join) ++joins else 0)
        val merged = SubPage.merge(prefix, response)
        mounted += SubPageMounted(prefix, merged.nodes)
        return SubPageChange(prefix, merged.nodes, merged.state, removedNodeIds, removedStateKeys)
    }

    /** Whether a page-state key is under `K:` or `K#<digits>:`. */
    private fun owns(key: String): Boolean {
        if (!key.startsWith(subPageKey)) return false
        var i = subPageKey.length
        if (i >= key.length) return false
        if (key[i] == ':') return true
        if (key[i] != '#') return false
        val digits = ++i
        while (i < key.length && key[i] in '0'..'9') i++
        return i > digits && i < key.length && key[i] == ':'
    }
}
