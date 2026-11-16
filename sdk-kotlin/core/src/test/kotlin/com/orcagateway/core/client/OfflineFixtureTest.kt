package com.orcagateway.core.client

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.runSuspend
import java.net.ConnectException
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * Answers /version and /config from one offline fixture case and records the
 * requests in order, as the Flutter runner's `MockClient` does: `"fail"` (or
 * a /config request in a case with no `config`) is a request that never
 * reaches the server.
 */
private class OfflineStub(private val case: JsonValue) : HttpTransport {
    val requests: MutableList<String> = ArrayList()

    override suspend fun send(request: HttpRequest): HttpResponse {
        val path = request.url.path
        return when {
            path.endsWith("/version") -> {
                requests.add("version")
                answer(case["version"])
            }
            path.endsWith("/config") -> {
                requests.add("config")
                if (case["config"].isNull) throw ConnectException("no /config")
                answer(case["config"])
            }
            else -> {
                requests.add(path)
                HttpResponse(404)
            }
        }
    }

    private fun answer(answer: JsonValue): HttpResponse {
        if (answer.stringValue == "fail") throw ConnectException("offline")
        return HttpResponse(answer["status"].intValue!!.toInt(), body = text(answer["body"]).encodeToByteArray())
    }
}

/** The JSON text a fixture value is stored or served as. */
private fun text(value: JsonValue): String = value.encoded()

/**
 * schema/fixtures/offline through the real core [preload] and
 * [StaticFlowManager], as the Flutter runner
 * (sdk/test/conformance/offline_fixtures_test.dart) runs them through
 * `OrcaApp.preload`: every case seeds a [MemoryKeyValueStore] with `saved`,
 * answers /version and /config from the case, runs [preload] over a new
 * manager (a cold start), then compares the requests, the result, the store
 * after and, when the boot gave a config, what [StaticFlowManager.getCachedPage]
 * serves once [StaticFlowManager.initDynamicPaths] has the config's flows.
 * Every case of every file runs; a new file is picked up with no edit here.
 * Swift twin: OfflineFixtureTests.
 */
class OfflineFixtureTest {
    /** Every case with its label, by file name then case order. */
    private fun cases(
        files: List<Pair<String, JsonValue>> = Fixtures.files("offline"),
    ): List<Pair<String, JsonValue>> = files.flatMap { (name, fixture) ->
        fixture["cases"].arrayValue.orEmpty().map { "$name · ${it["name"].stringValue}" to it }
    }

    /** Runs the cases of [row] (Flutter's case-to-row table) and returns how many ran. */
    private fun runRow(row: String): Int {
        val picked = cases().filter { (_, case) -> row in rowsOf[case["name"].stringValue].orEmpty() }
        assertTrue(picked.isNotEmpty(), "no offline case for $row")
        picked.forEach { (label, case) -> runCase(label, case) }
        return picked.size
    }

    @Test
    fun c14_1_staticPagesSavedAtBootAreServedFromTheCacheOfflineToo() {
        runRow("C14_1")
    }

    @Test
    fun c14_2_anOfflineColdStartBootsFromTheSavedConfigOrFailsWithFluttersMessage() {
        runRow("C14_2")
    }

    @Test
    fun c14_3_freshVersionsUseTheSavedConfigAndAMovedVersionRefetchesAndResavesTheWholeConfig() {
        runRow("C14_3")
    }

    @Test
    fun c14_4_dynamicRoutesAreNeverServedAndARefetchDeletesTheVersionedFlowsThatAreGone() {
        runRow("C14_4")
    }

    @Test
    fun c14_5_preloadGivesTheConfigOrForceUpdateAndThrowsOfflineWithNothingSaved() {
        runRow("C14_5")
    }

    @Test
    fun c14_everyCaseOfEveryOfflineFixtureFilePasses() {
        val files = Fixtures.files("offline")
        assertTrue(files.isNotEmpty(), "no file in schema/fixtures/offline")
        val results = HashSet<String>()
        for ((name, fixture) in files) {
            assertEquals(setOf("name", "description", "cases"), fixture.objectValue?.keys, name)
            assertTrue(fixture["cases"].arrayValue.orEmpty().isNotEmpty(), "$name: no case")
        }
        for ((label, case) in cases(files)) {
            assertWellFormed(label, case)
            val result = case["expected"]["result"]
            results.add(result.stringValue ?: result.objectValue!!.keys.single())
            runCase(label, case)
        }
        assertEquals(setOf("config", "forceUpdate", "error"), results, "every kind of result is pinned")
    }

    private fun assertWellFormed(label: String, case: JsonValue) {
        val keys = case.objectValue?.keys.orEmpty()
        assertTrue(keys.containsAll(listOf("name", "description", "saved", "version", "expected")), label)
        assertTrue((keys - caseKeys).isEmpty(), "$label: unknown keys ${keys - caseKeys}")
        for (key in case["saved"].objectValue!!.keys) {
            assertTrue(key == CONFIG || key == VERSIONS || key.startsWith(PAGES), "$label: saved key $key")
        }
        val version = case["version"]
        assertTrue(version.stringValue == "fail" || version is JsonValue.Object, "$label: version")
        val expected = case["expected"]
        assertEquals(setOf("requests", "result", "saved", "serves"), expected.objectValue?.keys, label)
        assertTrue(expected["requests"].arrayValue!!.all { it.stringValue in setOf("version", "config") }, label)
        val result = expected["result"]
        val kind = result.stringValue ?: result.objectValue?.keys?.singleOrNull()
        assertTrue(kind in setOf("forceUpdate", "config", "error"), "$label: result")
        if (kind != "config") assertTrue(expected["serves"].objectValue!!.isEmpty(), "$label: serves needs a config")
    }

    private fun runCase(label: String, case: JsonValue) {
        val saved = case["saved"].objectValue!!
        val expected = case["expected"]
        val store = MemoryKeyValueStore(saved.mapValues { text(it.value) })
        val stub = OfflineStub(case)
        val client = OrcaClient(URI("http://stub.invalid"), "static-flows", transport = stub)
        val manager = StaticFlowManager(store)

        val outcome = runSuspend { runCatching { preload(client, manager) } }

        assertEquals(expected["requests"].arrayValue!!.map { it.stringValue }, stub.requests, "$label: requests")

        val want = expected["result"]
        val result = outcome.getOrNull()
        when {
            want.stringValue == "forceUpdate" -> {
                assertNull(outcome.exceptionOrNull(), "$label: boot error")
                assertEquals(PreloadResult.ForceUpdate, result, label)
            }
            !want["error"].isNull -> {
                assertNull(result, "$label: result")
                val error = outcome.exceptionOrNull()
                val message = want["error"].stringValue
                if (message != null) {
                    assertIs<OfflineBootException>(error, label)
                    assertEquals(message, error.message, label)
                } else {
                    assertIs<OrcaClientException.Http>(error, label)
                    assertEquals(want["error"]["status"].intValue!!.toInt(), error.status, label)
                }
            }
            else -> {
                assertNull(outcome.exceptionOrNull(), "$label: boot error")
                val success = assertIs<PreloadResult.Success>(result, label)
                assertEquals(
                    want["config"].objectValue!!.mapValues { it.value.intValue?.toInt() },
                    success.config.flows.associate { it.name to it.version },
                    "$label: config flows",
                )
            }
        }

        val after = store.snapshot()
        val wantSaved = expected["saved"].objectValue!!
        assertEquals(wantSaved.keys, after.keys, "$label: keys")
        for ((key, value) in wantSaved) {
            val stored = after.getValue(key)
            when {
                key == CONFIG -> when (value.stringValue) {
                    "config" -> assertEquals(text(case["config"]["body"]), stored, "$label: $key config")
                    "saved" -> assertEquals(text(saved.getValue(key)), stored, "$label: $key saved")
                    else -> fail("$label: $key is $value")
                }
                key == VERSIONS -> assertEquals(value, JsonValue.parse(stored), "$label: $key")
                else -> assertEquals(
                    value.arrayValue!!.map { it.stringValue }.toSet(),
                    JsonValue.parse(stored).objectValue!!.keys,
                    "$label: $key",
                )
            }
        }

        val serves = expected["serves"].objectValue!!
        if (result is PreloadResult.Success) {
            val flows = result.config.flows
            manager.initDynamicPaths(flows)
            val got = serves.keys.associateWith { manager.getCachedPage(it, flows)?.pageId }
            assertEquals(serves.mapValues { it.value.stringValue }, got, "$label: serves")
        }
    }

    private companion object {
        const val CONFIG = "orca_nav_config"
        const val VERSIONS = "orca_flow_versions"
        const val PAGES = "orca_pages_"

        val caseKeys = setOf("name", "description", "saved", "version", "config", "expected")

        /** Case ids (phase-c-tests.md rows) per case name: Flutter's runner's table. */
        val rowsOf: Map<String?, List<String>> = mapOf(
            "first online boot" to listOf("C14_1", "C14_2"),
            "fresh: saved versions equal the remote ones" to listOf("C14_3"),
            "fresh with no saved config" to listOf("C14_3"),
            "stale: a flow version moved" to listOf("C14_3"),
            "offline with a saved config" to listOf("C14_1", "C14_2"),
            "offline is any /version failure, an error status too" to listOf("C14_2"),
            "offline with nothing saved" to listOf("C14_2", "C14_5"),
            "force update wins over a stale version" to listOf("C14_5"),
            "cleanup: a versioned flow gone from the refetched config" to listOf("C14_4"),
            "an unversioned flow gone from the config keeps its pages" to listOf("C14_4"),
            "a dynamic route is never served, even with a saved page" to listOf("C14_4"),
            "the cache reads the saved pages, not the pages inside the config" to listOf("C14_1"),
            "quirk: an unversioned flow keeps the boot stale" to listOf("C14_3"),
            "a stale boot whose /config fails does not fall back" to listOf("C14_3", "C14_5"),
        )
    }
}
