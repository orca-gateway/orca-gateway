package com.orcagateway.core.client

import com.orcagateway.core.support.runSuspend
import kotlinx.serialization.json.Json
import java.net.ConnectException
import java.net.URI
import kotlin.coroutines.cancellation.CancellationException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

/** Records every request and answers [status] with [body], or throws [error] when one is set. */
private class VersionStub(
    private val status: Int = 200,
    private val body: String = "",
    private val error: Exception? = null,
) : HttpTransport {
    val requests: MutableList<HttpRequest> = ArrayList()

    override suspend fun send(request: HttpRequest): HttpResponse {
        requests.add(request)
        error?.let { throw it }
        return HttpResponse(status, mapOf("content-type" to "application/json"), body.encodeToByteArray())
    }
}

/**
 * C15.1 on the Kotlin core: the version check behind `enableOffline`'s
 * force-update screen. The [VersionResponse] and fetchVersion cases port
 * sdk/test/version_checker_test.dart's four version rows; the outcomes port
 * sdk/lib/src/client/version_checker.dart (Swift twin: VersionCheckerTests).
 */
class VersionCheckerTest {
    private val base = URI("http://localhost:8080")

    private fun client(transport: HttpTransport): OrcaClient =
        OrcaClient(base, "testapp", apiKey = "k", environment = "staging", deviceId = "dev-1", transport = transport)

    private fun decode(text: String): VersionResponse = Json.decodeFromString(VersionResponse.serializer(), text)

    private fun check(transport: HttpTransport, local: Map<String, Int> = emptyMap()): VersionCheckOutcome =
        runSuspend { VersionChecker(client(transport)).check(local) }

    // MARK: VersionResponse and fetchVersion (sdk/test/version_checker_test.dart)

    @Test
    fun c15_1_versionResponseParsesFlowVersions() {
        val response = decode("""{"flows": {"homeFlow": 3, "profileFlow": 1}}""")
        assertEquals(mapOf("homeFlow" to 3, "profileFlow" to 1), response.flows)
        assertEquals(false, response.forceUpdate)
    }

    @Test
    fun c15_1_versionResponseParsesForceUpdate() {
        val response = decode("""{"flows": {"main": 2}, "forceUpdate": true}""")
        assertEquals(true, response.forceUpdate)
        assertEquals(mapOf("main" to 2), response.flows)
    }

    @Test
    fun c15_1_fetchVersionReturnsTheResponseOn200WithAGetToVersionAndTheClientsHeaders(): Unit = runSuspend {
        // A key the model does not know is ignored, as Dart's fromJson and Swift's Decodable ignore it.
        val stub = VersionStub(body = """{"flows": {"homeFlow": 1}, "minSdkVersion": "1.0.0"}""")
        val client = client(stub)

        val result = client.fetchVersion()

        assertEquals(VersionResponse(mapOf("homeFlow" to 1), forceUpdate = false), result)
        val request = stub.requests.single()
        assertEquals("GET", request.method)
        assertEquals("http://localhost:8080/api/v1/app/testapp/version", request.url.toString())
        assertEquals(client.headers, request.headers)
        assertNull(request.body)
    }

    @Test
    fun c15_1_fetchVersionThrowsHttpOnNon200(): Unit = runSuspend {
        val stub = VersionStub(status = 404, body = "Not Found")

        val error = assertFailsWith<OrcaClientException.Http> { client(stub).fetchVersion() }

        assertEquals(OrcaClientException.Http(404, "Not Found"), error)
    }

    // MARK: VersionChecker outcomes (sdk/lib/src/client/version_checker.dart)

    @Test
    fun c15_1_forceUpdateIsCheckedBeforeStaleness() {
        val stub = VersionStub(body = """{"flows": {"home": 2}, "forceUpdate": true}""")

        assertEquals(VersionCheckOutcome(VersionCheckResult.ForceUpdate), check(stub, mapOf("home" to 1)))
    }

    @Test
    fun c15_1_freshWhenEveryRemoteFlowMatchesTheLocalVersion() {
        val stub = VersionStub(body = """{"flows": {"home": 2, "profile": 1}}""")

        val outcome = check(stub, mapOf("home" to 2, "profile" to 1, "gone" to 4))

        assertEquals(VersionCheckOutcome(VersionCheckResult.Fresh), outcome)
    }

    @Test
    fun c15_1_staleListsTheDifferingFlowsSortedByNameAndAMissingFlowCounts() {
        val stub = VersionStub(body = """{"flows": {"zeta": 2, "alpha": 1, "mid": 3}}""")

        val outcome = check(stub, mapOf("zeta" to 1, "mid" to 3))

        assertEquals(VersionCheckOutcome(VersionCheckResult.Stale, listOf("alpha", "zeta")), outcome)
    }

    @Test
    fun c15_1_offlineWhenTheTransportThrows() {
        val stub = VersionStub(error = ConnectException("Connection refused"))

        assertEquals(VersionCheckOutcome(VersionCheckResult.Offline), check(stub))
    }

    @Test
    fun c15_1_offlineOnANon200() {
        assertEquals(VersionCheckOutcome(VersionCheckResult.Offline), check(VersionStub(status = 500, body = "boom")))
    }

    @Test
    fun c15_1_offlineOnABodyThatDoesNotDecode() {
        assertEquals(VersionCheckOutcome(VersionCheckResult.Offline), check(VersionStub(body = "not json")))
        assertEquals(VersionCheckOutcome(VersionCheckResult.Offline), check(VersionStub(body = """{"forceUpdate": true}""")))
    }

    @Test
    fun c15_1_aCancelledCheckIsNotOffline() {
        val stub = VersionStub(error = CancellationException("left"))

        assertFailsWith<CancellationException> { check(stub) }
    }
}
