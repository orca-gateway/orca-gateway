package com.orcagateway.core.client

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavFlow
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.PageResponse
import kotlinx.serialization.SerializationException
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

/**
 * The offline cache of static flows over [store], with Flutter's three keys:
 * `orca_nav_config` (the raw /config body), `orca_flow_versions` (`{flow:
 * version}` as JSON text) and `orca_pages_<flow>` (`{path: page}` as JSON
 * text). Memory mirrors the saved pages and versions, so a page lookup
 * decodes nothing twice. Ports Dart `StaticFlowManager`
 * (sdk/lib/src/client/static_flow_manager.dart); Swift twin
 * `StaticFlowManager`.
 *
 * Different from Dart: every save is done before the call returns (Dart
 * fires and forgets them; what ends up saved is the same). Thread-safe.
 */
public class StaticFlowManager(private val store: KeyValueStore) {
    private val lock = Any()
    private val pageCache = HashMap<String, Map<String, PageResponse>>()
    private var versionsCache: Map<String, Int>? = null
    private var dynamicPaths: Set<String>? = null

    /**
     * Keeps the route paths of every `isDynamic` route of the static
     * [flows], children included, with any leading slash dropped, so
     * [getCachedPage] never serves them. Call it once the config is known.
     */
    public fun initDynamicPaths(flows: List<NavFlow>) {
        val paths = HashSet<String>()
        for (flow in flows) if (flow.isStatic) collectDynamicPaths(flow.routes, paths)
        synchronized(lock) { dynamicPaths = paths }
    }

    private fun collectDynamicPaths(routes: List<NavRoute>, out: MutableSet<String>) {
        for (route in routes) {
            if (route.isDynamic) out.add(route.path.removePrefix("/"))
            collectDynamicPaths(route.children, out)
        }
    }

    /** Saves the /config body text as it came ([NavConfig.rawBody]). */
    public fun saveConfigRaw(rawJson: String) {
        synchronized(lock) { store.putString(CONFIG_KEY, rawJson) }
    }

    /**
     * The saved config, decoded with its text kept in [NavConfig.rawBody];
     * null when none is saved. Throws a [SerializationException] when the
     * saved text is not a config.
     */
    public fun loadConfig(): NavConfig? {
        val raw = synchronized(lock) { store.getString(CONFIG_KEY) } ?: return null
        return NavConfig.fromJson(JsonValue.parse(raw), rawBody = raw)
    }

    /**
     * The saved flow versions, from memory once read; empty when none are
     * saved. Throws a [SerializationException] when the saved text is not a
     * `{flow: int}` object.
     */
    public fun getLocalVersions(): Map<String, Int> = synchronized(lock) {
        versionsCache ?: run {
            val raw = store.getString(VERSIONS_KEY) ?: return emptyMap()
            Json.decodeFromString(versionsSerializer, raw).also { versionsCache = it }
        }
    }

    /**
     * The saved page for [path] (a route path, no leading slash): null for a
     * path [initDynamicPaths] marked dynamic; else the first static flow of
     * [flows] whose saved pages hold it, from memory first, then from the
     * store. Never the pages inside a config. Throws a
     * [SerializationException] when a flow's saved pages do not decode.
     */
    public fun getCachedPage(path: String, flows: List<NavFlow>): PageResponse? = synchronized(lock) {
        if (dynamicPaths?.contains(path) == true) return null
        for (flow in flows) {
            if (!flow.isStatic) continue
            loadFlowPages(flow.name)?.get(path)?.let { return it }
        }
        null
    }

    /**
     * Saves what a fetched [config] holds for offline use: the pages of each
     * static flow that has them, and the versions of the flows that have one
     * (they replace the saved versions). The pages of a flow in the old
     * versions that is gone from [config] are deleted, from memory too; a
     * flow that never had a version is not in them, so its pages stay.
     */
    public fun cacheStaticFlows(config: NavConfig) {
        synchronized(lock) {
            val current = HashSet<String>()
            val versions = LinkedHashMap<String, Int>()
            for (flow in config.flows) {
                current.add(flow.name)
                flow.version?.let { versions[flow.name] = it }
                val pages = flow.pages
                if (flow.isStatic && pages != null) saveFlowPages(flow.name, pages)
            }
            for (old in getLocalVersions().keys) {
                if (old in current) continue
                pageCache.remove(old)
                store.putString(PAGES_PREFIX + old, null)
            }
            versionsCache = versions
            store.putString(VERSIONS_KEY, Json.encodeToString(versionsSerializer, versions))
        }
    }

    /**
     * Forgets everything: the memory, the dynamic paths, the saved config and
     * versions, and the saved pages of every flow named in memory, in the
     * saved versions or in the saved config.
     *
     * Different from Dart: [KeyValueStore] cannot list its keys, so the pages
     * of a flow named in none of those stay (Dart removes every
     * `orca_pages_` key).
     */
    public fun clearAll() {
        synchronized(lock) {
            val flows = HashSet(pageCache.keys)
            runCatching { getLocalVersions() }.getOrNull()?.let { flows.addAll(it.keys) }
            store.getString(CONFIG_KEY)?.let { raw ->
                runCatching { JsonValue.parse(raw)["flows"].arrayValue }.getOrNull().orEmpty()
                    .mapNotNullTo(flows) { it["name"].stringValue }
            }
            pageCache.clear()
            versionsCache = null
            dynamicPaths = null
            for (flow in flows) store.putString(PAGES_PREFIX + flow, null)
            store.putString(CONFIG_KEY, null)
            store.putString(VERSIONS_KEY, null)
        }
    }

    /** Called with the lock held. */
    private fun saveFlowPages(flowName: String, pages: Map<String, PageResponse>) {
        pageCache[flowName] = pages
        store.putString(PAGES_PREFIX + flowName, Json.encodeToString(pagesSerializer, pages))
    }

    /** Called with the lock held. */
    private fun loadFlowPages(flowName: String): Map<String, PageResponse>? {
        pageCache[flowName]?.let { return it }
        val raw = store.getString(PAGES_PREFIX + flowName) ?: return null
        return Json.decodeFromString(pagesSerializer, raw).also { pageCache[flowName] = it }
    }

    private companion object {
        const val CONFIG_KEY = "orca_nav_config"
        const val VERSIONS_KEY = "orca_flow_versions"
        const val PAGES_PREFIX = "orca_pages_"

        val versionsSerializer = MapSerializer(String.serializer(), Int.serializer())
        val pagesSerializer = MapSerializer(String.serializer(), PageResponse.serializer())
    }
}
