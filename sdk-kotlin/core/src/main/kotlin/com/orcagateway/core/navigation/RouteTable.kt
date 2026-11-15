package com.orcagateway.core.navigation

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.RouteTransitionDef

/** What a location resolved to: a page to request, or the "page not found" screen. */
public enum class RouteResolutionKind { Page, Error }

/**
 * Where a location ends up ([RouteTable.resolve]). The fields are those of
 * `expected` in schema/fixtures/navigation, plus [transition] and [queryParameters].
 * For [RouteResolutionKind.Error] only [kind], [location], [redirected] and
 * [queryParameters] carry anything: nothing is requested.
 */
public data class RouteResolution(
    val kind: RouteResolutionKind,
    /** The final location: the asked one, query kept, or the redirect target. */
    val location: String,
    /** The final path differs from the asked path. */
    val redirected: Boolean = false,
    /** Page request path of the top page: the matched path without its leading slash and query. */
    val pagePath: String? = null,
    /** The full matched pattern, with a leading slash (`/product/:id`). */
    val routePath: String? = null,
    /** Path parameters of every matched level, percent-decoded. */
    val params: Map<String, String> = emptyMap(),
    /** Page request paths bottom to top: the parent chain, then the page itself. */
    val stack: List<String> = emptyList(),
    /** Index into `config.tabs` of the tab the route belongs to, or null. */
    val tabIndex: Int? = null,
    /** Fallback title when the page is drawn under a title bar (a top-level route beside tabs), else null. */
    val scaffoldTitle: String? = null,
    /** The matched route's transition, when it declares one. */
    val transition: RouteTransitionDef? = null,
    /** Query parameters of [location], decoded; a repeated key keeps its last value. */
    val queryParameters: Map<String, String> = emptyMap(),
)

/**
 * Route resolution for a [NavConfig], pure: given a location and the app
 * state, which page is requested and how it is shown. A port of what the
 * GoRouter built by `NavigationHandler.buildRouter`
 * (sdk/lib/src/navigation/navigation_handler.dart) does, pinned by
 * schema/fixtures/navigation:
 *
 * - The routes of all flows are tried in flow order and the first match
 *   wins. A `:name` segment matches any one segment. A child is matched
 *   under its parent, and a matched child comes with its parent chain
 *   ([RouteResolution.stack]).
 * - With tabs, the tab branches come first (a route belongs to a tab when its
 *   path is the tab's `initialRoute` or lies under it; a tab with no route
 *   gets one at its `initialRoute`), then the routes whose path starts with
 *   no tab's `initialRoute` as a plain string. A route that is neither
 *   (`/homework` beside tab `/home`) is unreachable. Only those top-level
 *   routes get a [RouteResolution.scaffoldTitle], their children do not.
 * - The redirect rule of the asked location is applied once: the target's own
 *   rule is not evaluated, so there is no chain and no loop.
 */
public class RouteTable(
    /** The configuration the table was built from. */
    public val config: NavConfig,
) {
    private class Node(val segments: List<String>, val route: NavRoute?, val children: List<Node>)

    private class Entry(val node: Node, val tabIndex: Int?, val scaffoldTitle: String?)

    private class Match(val node: Node, val end: Int)

    private val allRoutes: List<NavRoute> = config.flows.flatMap { it.routes }
    private val entries: List<Entry> = buildEntries(config)

    /**
     * Resolves [location] (leading slash, query allowed) against [appState],
     * the whole app state at this moment (`initialAppState` included).
     */
    public fun resolve(location: String, appState: Map<String, JsonValue>): RouteResolution {
        val askedPath = pathOf(location)
        val rule = findRouteByPath(allRoutes, segmentsOf(askedPath))?.redirect
        // Dart `appState[rule.when] == rule.equals`: an absent key is null,
        // and two lists or maps are never equal (identity).
        val holds = rule != null && rule.equals !is JsonValue.Array && rule.equals !is JsonValue.Object &&
            (appState[rule.`when`] ?: JsonValue.Null) == rule.equals
        val final = if (holds) rule.to else location
        val path = pathOf(final)
        val redirected = path != askedPath
        val query = queryOf(final)

        val segments = segmentsOf(path)
        for (entry in entries) {
            val chain = match(entry.node, segments, 0, emptyList()) ?: continue
            val top = chain.last().node
            val params = LinkedHashMap<String, String>()
            var offset = 0
            for (level in chain) {
                for (pattern in level.node.segments) {
                    if (pattern.startsWith(":")) params[pattern.substring(1)] = decode(segments[offset], plusIsSpace = false)
                    offset++
                }
            }
            return RouteResolution(
                kind = RouteResolutionKind.Page,
                location = final,
                redirected = redirected,
                pagePath = segments.joinToString("/"),
                routePath = "/" + chain.flatMap { it.node.segments }.joinToString("/"),
                params = params,
                stack = chain.map { segments.subList(0, it.end).joinToString("/") },
                tabIndex = entry.tabIndex,
                scaffoldTitle = if (chain.size == 1) entry.scaffoldTitle else null,
                transition = top.route?.transition,
                queryParameters = query,
            )
        }
        return RouteResolution(RouteResolutionKind.Error, final, redirected, queryParameters = query)
    }

    // MARK: Building (Dart `buildRouter`)

    private fun buildEntries(config: NavConfig): List<Entry> {
        if (config.tabs.isEmpty()) return allRoutes.map { Entry(node(it, ""), null, null) }

        val entries = ArrayList<Entry>()
        config.tabs.forEachIndexed { index, tab ->
            // `_findTabRoutes`
            val tabPath = slashed(tab.initialRoute)
            val tabRoutes = allRoutes.filter {
                val routePath = slashed(it.path)
                routePath == tabPath || routePath.startsWith("$tabPath/")
            }
            if (tabRoutes.isEmpty()) {
                entries.add(Entry(Node(segmentsOf(tab.initialRoute), null, emptyList()), index, null))
            } else {
                tabRoutes.forEach { entries.add(Entry(node(it, ""), index, null)) }
            }
        }

        val tabPrefixes = config.tabs.map { it.initialRoute }
        val drawerLabels = config.drawerItems.associate { it.route to it.label }
        for (route in allRoutes) {
            val path = slashed(route.path)
            if (tabPrefixes.any { path.startsWith(it) }) continue
            // Drawer label, else the last segment capitalised, or the one
            // before it when the last is a `:param`.
            val segments = segmentsOf(path)
            val last = segments.lastOrNull().orEmpty()
            val seg = if (last.startsWith(":") && segments.size >= 2) segments[segments.size - 2] else last
            val label = drawerLabels[path] ?: (seg.take(1).uppercase() + seg.drop(1))
            entries.add(Entry(node(route, ""), null, label))
        }
        return entries
    }

    /** Dart `_buildGoRoute`: a child's pattern is its full path less the parent's. */
    private fun node(route: NavRoute, parentPath: String): Node {
        val fullPath = slashed(route.path)
        val own = if (parentPath.isNotEmpty() && fullPath.startsWith("$parentPath/")) {
            fullPath.substring(parentPath.length + 1)
        } else {
            fullPath
        }
        return Node(segmentsOf(own), route, route.children.map { node(it, fullPath) })
    }

    // MARK: Matching

    /** The chain from [node] down that consumes all of [location] from [start], or null. */
    private fun match(node: Node, location: List<String>, start: Int, above: List<Match>): List<Match>? {
        val end = start + node.segments.size
        if (end > location.size) return null
        for (i in node.segments.indices) {
            val pattern = node.segments[i]
            if (!pattern.startsWith(":") && pattern != location[start + i]) return null
        }
        val chain = above + Match(node, end)
        if (end == location.size) return chain
        for (child in node.children) match(child, location, end, chain)?.let { return it }
        return null
    }

    /**
     * Dart `_findRouteByPath` with `_pathMatches`: the first route, a node
     * before its children, whose full pattern has as many segments as the
     * location and matches it. Used for the redirect rule only.
     */
    private fun findRouteByPath(routes: List<NavRoute>, location: List<String>): NavRoute? {
        for (route in routes) {
            val pattern = segmentsOf(route.path)
            if (pattern.size == location.size &&
                pattern.indices.all { pattern[it].startsWith(":") || pattern[it] == location[it] }
            ) {
                return route
            }
            findRouteByPath(route.children, location)?.let { return it }
        }
        return null
    }

    // MARK: Locations

    private fun slashed(path: String): String = if (path.startsWith("/")) path else "/$path"

    private fun segmentsOf(path: String): List<String> = path.split('/').filter { it.isNotEmpty() }

    private fun pathOf(location: String): String = location.substringBefore('#').substringBefore('?')

    private fun queryOf(location: String): Map<String, String> {
        val query = location.substringBefore('#').substringAfter('?', "")
        val out = LinkedHashMap<String, String>()
        for (pair in query.split('&')) {
            if (pair.isEmpty()) continue
            out[decode(pair.substringBefore('='), plusIsSpace = true)] =
                decode(pair.substringAfter('=', ""), plusIsSpace = true)
        }
        return out
    }

    /**
     * Percent-decoding as UTF-8. Text between escapes is copied as it is; a
     * malformed escape, or a run of escapes that is not valid UTF-8 (`%FF`),
     * keeps the whole text as it is instead of yielding U+FFFD.
     */
    private fun decode(text: String, plusIsSpace: Boolean): String {
        val source = if (plusIsSpace) text.replace('+', ' ') else text
        if ('%' !in source) return source
        val out = StringBuilder(source.length)
        val run = java.io.ByteArrayOutputStream()
        var i = 0
        while (i < source.length) {
            val next = source.indexOf('%', i).let { if (it < 0) source.length else it }
            out.append(source, i, next)
            i = next
            run.reset()
            while (i < source.length && source[i] == '%') {
                if (i + 2 >= source.length) return source
                val high = Character.digit(source[i + 1], 16)
                val low = Character.digit(source[i + 2], 16)
                if (high < 0 || low < 0 || source[i + 1].code > 0x7F || source[i + 2].code > 0x7F) return source
                run.write(high * 16 + low)
                i += 3
            }
            if (run.size() == 0) continue
            val strict = Charsets.UTF_8.newDecoder()
                .onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
                .onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT)
            try {
                out.append(strict.decode(java.nio.ByteBuffer.wrap(run.toByteArray())))
            } catch (_: java.nio.charset.CharacterCodingException) {
                return source
            }
        }
        return out.toString()
    }
}
