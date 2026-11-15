package com.orcagateway.sdk

import android.content.Context
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.net.ConnectException
import java.net.URI
import java.util.Collections
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * C15.1 on Android: with `enableOffline`, OrcaApp asks `/version` before its
 * first page, and a forceUpdate answer shows Flutter's force-update screen
 * (`_buildForceUpdate`, sdk/lib/src/widgets/orca_app.dart) with no page ever
 * fetched; any other answer boots as before, and without the option no
 * `/version` request is made. Also the device id OrcaApp gives a client that
 * has none, from SharedPreferences (Flutter's `_resolveDeviceId`). Swift
 * twin: OrcaBootTests.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class OrcaBootTest {
    @get:Rule
    val compose = createComposeRule()

    private val context: Context = ApplicationProvider.getApplicationContext()

    /**
     * Answers `/version` with [status] and [version], or throws when [version]
     * is null (the engine unreachable), and pages like the engine: 412 to the
     * GET, the page to the POST retry.
     */
    private class BootEngine(private val version: String?, private val status: Int = 200) : HttpTransport {
        val requests: MutableList<HttpRequest> = Collections.synchronizedList(ArrayList())
        private val page = requireNotNull(javaClass.getResource("/pages/counter-home.json")).readBytes()

        override suspend fun send(request: HttpRequest): HttpResponse {
            requests += request
            return when {
                request.url.path.endsWith("/version") ->
                    HttpResponse(status, body = (version ?: throw ConnectException("unreachable")).toByteArray())
                request.method == "GET" -> HttpResponse(412, body = """{"error":"caps_vector_unknown"}""".toByteArray())
                else -> HttpResponse(200, mapOf("content-type" to "application/json"), page)
            }
        }

        val paths: List<String> get() = requests.toList().map { it.url.path }
    }

    private fun client(engine: BootEngine, deviceId: String? = null) =
        OrcaClient(URI("http://engine.invalid"), appId = "counter", deviceId = deviceId, transport = engine)

    private fun waitForText(text: String) {
        compose.waitUntil(5_000) { compose.onAllNodes(hasText(text)).fetchSemanticsNodes().isNotEmpty() }
    }

    private fun savedDeviceId(): String? =
        context.getSharedPreferences("orca_gateway", Context.MODE_PRIVATE).getString("orca_device_id", null)

    @Test
    fun c15_1_aForceUpdateAnswerShowsTheForceUpdateScreenAndFetchesNoPage() {
        val engine = BootEngine("""{"flows":{"home":1},"forceUpdate":true}""")
        compose.setContent { OrcaApp(client(engine), path = "home", enableOffline = true) }

        waitForText("Update required. Please update the app.")
        compose.onNodeWithTag("orca.forceUpdate").assertIsDisplayed()
        compose.waitForIdle()

        assertEquals(listOf("/api/v1/app/counter/version"), engine.paths)
        assertEquals("GET", engine.requests.single().method)
    }

    @Test
    fun c15_1_aFreshAnswerBootsAndThePageLoads() {
        val engine = BootEngine("""{"flows":{}}""")
        compose.setContent { OrcaApp(client(engine), path = "home", enableOffline = true) }

        waitForText("Counter Example")
        compose.onNodeWithText("Counter Example").assertIsDisplayed()

        assertEquals(
            listOf("/api/v1/app/counter/version", "/api/v1/app/counter/page/home", "/api/v1/app/counter/page/home"),
            engine.paths,
        )
    }

    @Test
    fun c15_1_withEnableOfflineFreshStaleAndOfflineAnswersBoot(): Unit = runBlocking {
        val answers = listOf(
            "fresh" to BootEngine("""{"flows":{}}"""),
            "stale" to BootEngine("""{"flows":{"home":2}}"""),
            "offline: unreachable" to BootEngine(null),
            "offline: 500" to BootEngine("boom", status = 500),
            "offline: not json" to BootEngine("<html>"),
        )
        for ((name, engine) in answers) {
            val boot = OrcaBoot(client(engine), enableOffline = true)
            assertEquals(OrcaBoot.Phase.Checking, boot.phase, name)
            boot.start()
            assertEquals(OrcaBoot.Phase.Ready, boot.phase, name)
            assertEquals(listOf("/api/v1/app/counter/version"), engine.paths, name)
        }
    }

    @Test
    fun c15_1_withoutEnableOfflineNoVersionRequestIsMade() {
        val engine = BootEngine("""{"flows":{},"forceUpdate":true}""")
        compose.setContent { OrcaApp(client(engine), path = "home") }

        waitForText("Counter Example")

        assertFalse(engine.paths.any { it.endsWith("/version") })
        assertEquals(listOf("/api/v1/app/counter/page/home", "/api/v1/app/counter/page/home"), engine.paths)
    }

    @Test
    fun c15_1_aClientWithoutADeviceIdGetsTheOneSavedInSharedPreferences() {
        val engine = BootEngine("""{"flows":{}}""")
        compose.setContent { OrcaApp(client(engine), path = "home") }

        waitForText("Counter Example")

        val saved = assertNotNull(savedDeviceId())
        assertTrue(saved.isNotEmpty())
        assertEquals(listOf(saved, saved), engine.requests.toList().map { it.headers["x-orca-device-id"] })
    }

    @Test
    fun c15_1_aClientWithADeviceIdKeepsIt() {
        val engine = BootEngine("""{"flows":{}}""")
        compose.setContent { OrcaApp(client(engine, deviceId = "host-id"), path = "home") }

        waitForText("Counter Example")

        assertEquals(listOf("host-id", "host-id"), engine.requests.toList().map { it.headers["x-orca-device-id"] })
        assertNull(savedDeviceId())
    }

    @Test
    fun c15_1_theSharedPreferencesStoreSavesReadsAndRemoves() {
        val store = SharedPreferencesKeyValueStore(context)

        assertNull(store.getString("k"))
        store.putString("k", "v")
        assertEquals("v", store.getString("k"))
        assertEquals("v", context.getSharedPreferences("orca_gateway", Context.MODE_PRIVATE).getString("k", null))
        store.putString("k", null)
        assertNull(store.getString("k"))
    }
}
