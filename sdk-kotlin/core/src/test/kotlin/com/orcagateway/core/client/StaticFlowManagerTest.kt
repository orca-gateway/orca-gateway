package com.orcagateway.core.client

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.support.runSuspend
import java.io.File
import java.net.ConnectException
import java.net.URI
import java.nio.file.Files
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Answers /version with [version] (or fails when null) and /config with [config], recording the routes asked. */
private class BootStub(private val version: String?, private val config: String? = null) : HttpTransport {
    val requests: MutableList<String> = ArrayList()

    override suspend fun send(request: HttpRequest): HttpResponse {
        val route = request.url.path.substringAfterLast('/')
        requests.add(route)
        val body = (if (route == "version") version else config) ?: throw ConnectException("offline")
        return HttpResponse(200, body = body.encodeToByteArray())
    }
}

/**
 * The core's flow cache, its file store and preload (D1-D3 of native parity
 * step 14), unit by unit; the boot decisions themselves are pinned by
 * OfflineFixtureTest. Ports sdk/lib/src/client/static_flow_manager.dart;
 * Swift twin: StaticFlowManagerTests.
 */
class StaticFlowManagerTest {
    private val temp: File = Files.createTempDirectory("orca-store").toFile()

    @AfterTest
    fun removeTemp() {
        temp.deleteRecursively()
    }

    private fun page(id: String): String =
        """{"pageId":"$id","title":"$id","state":[],"components":[]}"""

    /** A config with a static flow `main` (home, about; profile and product/:id dynamic) and [more] flows. */
    private fun config(version: Int? = 4, vararg more: String): NavConfig {
        val main = """{"name":"main","isStatic":true${version?.let { ",\"version\":$it" } ?: ""},
            "routes":[{"path":"home"},{"path":"about"},{"path":"/profile","isDynamic":true},
              {"path":"shop","children":[{"path":"shop/product/:id","isDynamic":true}]}],
            "pages":{"home":${page("home")},"about":${page("about")}}}"""
        val text = """{"initialRoute":"/home","flows":[${(listOf(main) + more).joinToString(",")}]}"""
        return NavConfig.fromJson(JsonValue.parse(text), rawBody = text)
    }

    // MARK: FileKeyValueStore (D1)

    @Test
    fun c14_2_aFileStoreKeepsItsValuesForANewStoreOnTheSameDirectory() {
        val dir = File(temp, "orca_gateway")
        FileKeyValueStore(dir).putString("orca_nav_config", """{"flows":[]}""")

        val restarted = FileKeyValueStore(dir)

        assertEquals("""{"flows":[]}""", restarted.getString("orca_nav_config"))
        assertNull(restarted.getString("orca_flow_versions"))
    }

    @Test
    fun c14_2_aFileStoreMakesItsDirectoryOnTheFirstWriteAndLeavesNoTempFile() {
        val dir = File(temp, "a/b")
        val store = FileKeyValueStore(dir)
        assertNull(store.getString("k"))
        assertFalse(dir.exists())

        store.putString("k", "1")
        store.putString("k", "2")

        assertEquals("2", store.getString("k"))
        assertEquals(listOf("k"), dir.list()!!.toList())
    }

    @Test
    fun c14_2_aNullValueRemovesTheKeysFile() {
        val store = FileKeyValueStore(temp)
        store.putString("orca_pages_main", "{}")

        store.putString("orca_pages_main", null)
        store.putString("never_saved", null)

        assertNull(store.getString("orca_pages_main"))
        assertEquals(emptyList(), temp.list()!!.toList())
    }

    @Test
    fun c14_2_oddKeysAreSafeFileNamesThatNeverMeetAnotherKey() {
        val store = FileKeyValueStore(File(temp, "store"))
        val keys = listOf("", ".", "..", "a/b", "../escape", "A", "%41", "ünï code", "orca_pages_main", "x.y-z")

        keys.forEachIndexed { i, key -> store.putString(key, "v$i") }

        val restarted = FileKeyValueStore(File(temp, "store"))
        keys.forEachIndexed { i, key -> assertEquals("v$i", restarted.getString(key), key) }
        assertEquals(setOf("store"), temp.list()!!.toSet(), "nothing is written outside the directory")
        assertEquals(keys.size, File(temp, "store").list()!!.size)
    }

    @Test
    fun c14_2_aStoreThatCannotWriteThrowsNothingAndReadsAbsent() {
        val notADirectory = File(temp, "file").also { it.writeText("x") }
        val store = FileKeyValueStore(notADirectory)

        store.putString("k", "v")
        store.putString("k", null)

        assertNull(store.getString("k"))
    }

    // MARK: StaticFlowManager (D2)

    @Test
    fun c14_3_theSavedVersionsAreEmptyWhenNothingIsSavedAndReadBackOtherwise() {
        assertEquals(emptyMap(), StaticFlowManager(MemoryKeyValueStore()).getLocalVersions())

        val store = MemoryKeyValueStore(mapOf("orca_flow_versions" to """{"main":4,"other":1}"""))

        assertEquals(mapOf("main" to 4, "other" to 1), StaticFlowManager(store).getLocalVersions())
    }

    @Test
    fun c14_3_theConfigIsSavedAsItsTextAndLoadedDecodedWithThatText() {
        val store = MemoryKeyValueStore()
        val manager = StaticFlowManager(store)
        assertNull(manager.loadConfig())
        val text = config().rawBody!!

        manager.saveConfigRaw(text)

        assertEquals(text, store.getString("orca_nav_config"))
        val loaded = StaticFlowManager(store).loadConfig()!!
        assertEquals(text, loaded.rawBody)
        assertEquals("/home", loaded.initialRoute)
        assertEquals(listOf("main"), loaded.flows.map { it.name })
    }

    @Test
    fun c14_3_cachingAConfigSavesTheVersionedFlowsAndThePagesOfTheStaticOnes() {
        val store = MemoryKeyValueStore()
        val manager = StaticFlowManager(store)
        val loose = """{"name":"loose","isStatic":true,"routes":[{"path":"l"}],"pages":{"l":${page("l")}}}"""
        val plain = """{"name":"plain","version":2,"routes":[{"path":"p"}],"pages":{"p":${page("p")}}}"""

        manager.cacheStaticFlows(config(4, loose, plain))

        assertEquals(setOf("orca_flow_versions", "orca_pages_main", "orca_pages_loose"), store.snapshot().keys)
        assertEquals(mapOf("main" to 4, "plain" to 2), manager.getLocalVersions())
        assertEquals(mapOf("main" to 4, "plain" to 2), StaticFlowManager(store).getLocalVersions())
        assertEquals(setOf("home", "about"), JsonValue.parse(store.getString("orca_pages_main")!!).objectValue!!.keys)
        assertEquals("l", StaticFlowManager(store).getCachedPage("l", config(4, loose).flows)?.pageId)
    }

    @Test
    fun c14_4_aRefetchDeletesThePagesOfAVersionedFlowThatIsGoneFromStoreAndMemory() {
        val store = MemoryKeyValueStore()
        val manager = StaticFlowManager(store)
        val old = """{"name":"old","version":2,"isStatic":true,"routes":[{"path":"legacy"}],
            "pages":{"legacy":${page("legacy")}}}"""
        val withOld = config(4, old)
        manager.cacheStaticFlows(withOld)
        assertEquals("legacy", manager.getCachedPage("legacy", withOld.flows)?.pageId)

        manager.cacheStaticFlows(config(5))

        assertNull(store.getString("orca_pages_old"))
        assertNull(manager.getCachedPage("legacy", withOld.flows), "the memory entry is gone too")
        assertEquals(mapOf("main" to 5), manager.getLocalVersions())
    }

    @Test
    fun c14_4_aDynamicPathIsNeverServedEvenWithASavedPage() {
        val pages = """{"home":${page("home")},"profile":${page("profile")},"shop/product/:id":${page("product")}}"""
        val manager = StaticFlowManager(MemoryKeyValueStore(mapOf("orca_pages_main" to pages)))
        val flows = config().flows
        assertEquals("profile", manager.getCachedPage("profile", flows)?.pageId, "served before the paths are known")

        manager.initDynamicPaths(flows)

        assertEquals("home", manager.getCachedPage("home", flows)?.pageId)
        assertNull(manager.getCachedPage("profile", flows), "a leading slash is dropped")
        assertNull(manager.getCachedPage("shop/product/:id", flows), "children are walked")
        assertNull(manager.getCachedPage("shop/product/42", flows), "no page is saved for a concrete path")
    }

    @Test
    fun c14_4_onlyStaticFlowsAreServedAndTheirDynamicPathsKept() {
        val pages = """{"home":${page("home")}}"""
        val store = MemoryKeyValueStore(mapOf("orca_pages_main" to pages, "orca_pages_plain" to """{"p":${page("p")}}"""))
        val manager = StaticFlowManager(store)
        val plain = """{"name":"plain","routes":[{"path":"home","isDynamic":true},{"path":"p"}]}"""
        val flows = config(4, plain).flows

        manager.initDynamicPaths(flows)

        assertEquals("home", manager.getCachedPage("home", flows)?.pageId)
        assertNull(manager.getCachedPage("p", flows))
    }

    @Test
    fun c14_1_pagesAreReadFromMemoryFirstThenFromTheStore() {
        val store = MemoryKeyValueStore()
        val manager = StaticFlowManager(store)
        val flows = config().flows
        manager.cacheStaticFlows(config())

        store.putString("orca_pages_main", null)

        assertEquals("about", manager.getCachedPage("about", flows)?.pageId)
        assertNull(StaticFlowManager(store).getCachedPage("about", flows))
    }

    @Test
    fun c14_4_clearAllEmptiesTheStoreAndTheMemory() {
        val store = MemoryKeyValueStore(mapOf("orca_device_id" to "d"))
        val manager = StaticFlowManager(store)
        val text = config().rawBody!!
        manager.saveConfigRaw(text)
        manager.cacheStaticFlows(config())
        manager.initDynamicPaths(config().flows)

        manager.clearAll()

        assertEquals(mapOf("orca_device_id" to "d"), store.snapshot())
        assertNull(manager.loadConfig())
        assertEquals(emptyMap(), manager.getLocalVersions())
        assertNull(manager.getCachedPage("home", config().flows))
    }

    // MARK: preload (D3)

    @Test
    fun c14_3_savedVersionsThatDoNotReadBootOfflineAsFluttersCheckDoes(): Unit = runSuspend {
        val text = config().rawBody!!
        val store = MemoryKeyValueStore(mapOf("orca_flow_versions" to "not json", "orca_nav_config" to text))
        val stub = BootStub(version = """{"flows":{"main":4}}""", config = text)

        val result = preload(OrcaClient(URI("http://stub.invalid"), "app", transport = stub), StaticFlowManager(store))

        assertEquals(listOf("version"), stub.requests)
        assertEquals(text, assertIs<PreloadResult.Success>(result).config.rawBody)
    }

    @Test
    fun c14_5_theOfflineErrorWithNothingSavedCarriesFluttersText(): Unit = runSuspend {
        val client = OrcaClient(URI("http://stub.invalid"), "app", transport = BootStub(version = null))

        val error = runCatching { preload(client, StaticFlowManager(MemoryKeyValueStore())) }.exceptionOrNull()

        assertIs<OfflineBootException>(error)
        assertEquals("No network and no cached config available", error.message)
    }

    @Test
    fun c14_2_anOnlineBootOnAFileStoreLetsAnOfflineColdStartServeTheStaticPages(): Unit = runSuspend {
        val text = config().rawBody!!
        val online = BootStub(version = """{"flows":{"main":4}}""", config = text)
        preload(OrcaClient(URI("http://stub.invalid"), "app", transport = online), StaticFlowManager(FileKeyValueStore(temp)))

        val offline = BootStub(version = null)
        val manager = StaticFlowManager(FileKeyValueStore(temp))
        val result = preload(OrcaClient(URI("http://stub.invalid"), "app", transport = offline), manager)

        assertEquals(listOf("version", "config"), online.requests)
        assertEquals(listOf("version"), offline.requests)
        val flows = assertIs<PreloadResult.Success>(result).config.flows
        manager.initDynamicPaths(flows)
        assertEquals(listOf("home", "about", null), listOf("home", "about", "profile").map { manager.getCachedPage(it, flows)?.pageId })
        assertTrue(temp.list()!!.none { it.startsWith("~") })
    }
}
