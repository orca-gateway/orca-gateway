package com.orcagateway.core.client

import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.plugins.PluginMerger
import com.orcagateway.core.plugins.PluginParts
import com.orcagateway.core.support.runSuspend
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.io.IOException
import java.io.InterruptedIOException
import java.net.ConnectException
import java.net.NoRouteToHostException
import java.net.SocketException
import java.net.SocketTimeoutException
import java.net.URI
import java.net.UnknownHostException
import javax.net.ssl.SSLHandshakeException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/** Answers [status] with [body], or throws [error] when one is set. */
private class ErrorStub(
    private val status: Int = 200,
    private val body: String = "",
    private val error: Exception? = null,
) : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse {
        error?.let { throw it }
        return HttpResponse(status, mapOf("content-type" to "application/json"), body.encodeToByteArray())
    }
}

/**
 * C18.2, the mapping half, on the Kotlin core: an error becomes the title and
 * message of Flutter's error screen, verbatim from `buildOrcaError`
 * (sdk/lib/src/widgets/orca_error.dart), and a kind standing for its icon.
 */
class OrcaErrorInfoTest {
    private val unauthorized = OrcaErrorInfo(
        OrcaErrorInfo.Kind.Unauthorized, "Unauthorized",
        "Invalid or missing API key. Please check your configuration.",
    )
    private val forbidden = OrcaErrorInfo(
        OrcaErrorInfo.Kind.Forbidden, "Forbidden", "You do not have permission to access this resource.",
    )
    private val notFound = OrcaErrorInfo(
        OrcaErrorInfo.Kind.NotFound, "Not Found", "The requested page could not be found.",
    )
    private val tooManyRequests = OrcaErrorInfo(
        OrcaErrorInfo.Kind.TooManyRequests, "Too Many Requests", "Please slow down and try again in a moment.",
    )
    private val serverError = OrcaErrorInfo(
        OrcaErrorInfo.Kind.Server, "Server Error", "Something went wrong on the server. Please try again later.",
    )
    private val configuration = OrcaErrorInfo(
        OrcaErrorInfo.Kind.Configuration, "Configuration Error",
        "Invalid value in configuration. Please check your setup.",
    )
    private val connection = OrcaErrorInfo(
        OrcaErrorInfo.Kind.Connection, "Connection Failed",
        "Unable to reach the server. Please check your network and server status.",
    )
    private val unknown = OrcaErrorInfo(
        OrcaErrorInfo.Kind.Unknown, "Something Went Wrong", "An unexpected error occurred. Please try again.",
    )

    private fun client(transport: HttpTransport, appId: String = "testapp"): OrcaClient =
        OrcaClient(URI("http://localhost:8080"), appId, apiKey = "k", transport = transport)

    /** What the client threw for [call]. */
    private fun caught(call: suspend () -> Unit): Throwable = assertFailsWith<Exception> { runSuspend { call() } }

    // MARK: a client error carrying a status

    @Test
    fun c18_2_a401IsUnauthorized() {
        assertEquals(unauthorized, OrcaErrorInfo.from(OrcaClientException.Http(401, "")))
    }

    @Test
    fun c18_2_a403IsForbidden() {
        assertEquals(forbidden, OrcaErrorInfo.from(OrcaClientException.Http(403, "")))
    }

    @Test
    fun c18_2_a404IsNotFound() {
        assertEquals(notFound, OrcaErrorInfo.from(OrcaClientException.Http(404, "Not Found")))
    }

    @Test
    fun c18_2_a429IsTooManyRequests() {
        assertEquals(tooManyRequests, OrcaErrorInfo.from(OrcaClientException.Http(429, "")))
    }

    @Test
    fun c18_2_a500IsServerError() {
        assertEquals(serverError, OrcaErrorInfo.from(OrcaClientException.Http(500, "boom")))
    }

    @Test
    fun c18_2_a503IsServerError() {
        assertEquals(serverError, OrcaErrorInfo.from(OrcaClientException.Http(503, "")))
    }

    @Test
    fun c18_2_anotherStatusKeepsTheErrorsMessage() {
        assertEquals(
            OrcaErrorInfo(OrcaErrorInfo.Kind.Status, "Error", "Failed to fetch page: 418"),
            OrcaErrorInfo.from(OrcaClientException.Http(418, "teapot")),
        )
    }

    @Test
    fun c18_2_aPageAndAConfigFailureFromTheClientMapTheSameWay() {
        val page = caught { client(ErrorStub(404, "Not Found")).fetchPage("/home") }
        assertEquals(notFound, OrcaErrorInfo.from(page))
        // A native difference: /config fails with the page message, Flutter says "Failed to fetch config: 418".
        val config = caught { client(ErrorStub(418, "teapot")).fetchConfig() }
        assertEquals(OrcaErrorInfo(OrcaErrorInfo.Kind.Status, "Error", "Failed to fetch page: 418"), OrcaErrorInfo.from(config))
    }

    // MARK: a server action error

    @Test
    fun c18_2_aServerActionErrorKeepsItsMessageForAnotherStatus() {
        assertEquals(
            OrcaErrorInfo(OrcaErrorInfo.Kind.Status, "Error", "Coffee is off"),
            OrcaErrorInfo.from(OrcaActionException(418, "Coffee is off")),
        )
        val named = caught { client(ErrorStub(400, """{"error": "Bad input"}""")).executeAction("save") }
        assertEquals(OrcaErrorInfo(OrcaErrorInfo.Kind.Status, "Error", "Bad input"), OrcaErrorInfo.from(named))
        val unnamed = caught { client(ErrorStub(400, "{}")).executeAction("save") }
        assertEquals(OrcaErrorInfo(OrcaErrorInfo.Kind.Status, "Error", "Server action failed"), OrcaErrorInfo.from(unnamed))
    }

    @Test
    fun c18_2_aServerActionErrorMapsTheKnownStatusesLikeAPage() {
        assertEquals(unauthorized, OrcaErrorInfo.from(OrcaActionException(401, "nope")))
        assertEquals(forbidden, OrcaErrorInfo.from(OrcaActionException(403, "nope")))
        assertEquals(notFound, OrcaErrorInfo.from(OrcaActionException(404, "nope")))
        assertEquals(tooManyRequests, OrcaErrorInfo.from(OrcaActionException(429, "nope")))
        assertEquals(serverError, OrcaErrorInfo.from(OrcaActionException(500, "nope")))
        assertEquals(serverError, OrcaErrorInfo.from(OrcaActionException(503, "nope")))
    }

    // MARK: a decode error or a URL that cannot be built (Flutter FormatException)

    @Test
    fun c18_2_aDecodeErrorIsConfigurationError() {
        assertEquals(configuration, OrcaErrorInfo.from(SerializationException("bad")))
        val missingField = assertFailsWith<SerializationException> { Json.decodeFromString(PageResponse.serializer(), "{}") }
        assertEquals(configuration, OrcaErrorInfo.from(missingField))
        val page = caught { client(ErrorStub(200, "not json")).fetchPage("/home") }
        assertEquals(configuration, OrcaErrorInfo.from(page))
        val config = caught { client(ErrorStub(200, "[1]")).fetchConfig() }
        assertEquals(configuration, OrcaErrorInfo.from(config))
    }

    @Test
    fun c18_2_anInvalidUrlIsConfigurationError() {
        assertEquals(configuration, OrcaErrorInfo.from(OrcaClientException.InvalidUrl("http://a b")))
        val thrown = caught { client(ErrorStub(), appId = "my app").fetchConfig() }
        assertEquals(configuration, OrcaErrorInfo.from(thrown))
    }

    // MARK: a transport error that never reached the server

    @Test
    fun c18_2_aRefusedConnectionIsConnectionFailed() {
        assertEquals(connection, OrcaErrorInfo.from(ConnectException("Connection refused")))
        val thrown = caught { client(ErrorStub(error = ConnectException("Connection refused"))).fetchPage("/home") }
        assertEquals(connection, OrcaErrorInfo.from(thrown))
    }

    @Test
    fun c18_2_anUnknownHostIsConnectionFailed() {
        assertEquals(connection, OrcaErrorInfo.from(UnknownHostException("api.example.com")))
    }

    @Test
    fun c18_2_noRouteToHostIsConnectionFailed() {
        assertEquals(connection, OrcaErrorInfo.from(NoRouteToHostException("No route to host")))
    }

    @Test
    fun c18_2_aSocketErrorIsConnectionFailed() {
        assertEquals(connection, OrcaErrorInfo.from(SocketException("Network is unreachable")))
    }

    @Test
    fun c18_2_aTimeoutIsConnectionFailed() {
        assertEquals(connection, OrcaErrorInfo.from(SocketTimeoutException("connect timed out")))
        // OkHttp's call timeout.
        assertEquals(connection, OrcaErrorInfo.from(InterruptedIOException("timeout")))
    }

    // MARK: anything else

    @Test
    fun c18_2_anUnrelatedErrorIsSomethingWentWrong() {
        assertEquals(unknown, OrcaErrorInfo.from(IllegalStateException("boom")))
        assertEquals(unknown, OrcaErrorInfo.from(RuntimeException()))
    }

    @Test
    fun c18_2_aPluginConflictIsSomethingWentWrong() {
        val conflict = assertFailsWith<IllegalArgumentException> {
            PluginMerger.merge(setOf("Text"), plugins = listOf(PluginParts("text", widgetTypes = setOf("Text"))))
        }
        assertEquals(unknown, OrcaErrorInfo.from(conflict))
    }

    @Test
    fun c18_2_aDroppedConnectionOrATlsFailureIsSomethingWentWrong() {
        // The server was reached: Flutter's HttpException and HandshakeException fall to the default too.
        assertEquals(unknown, OrcaErrorInfo.from(IOException("unexpected end of stream")))
        assertEquals(unknown, OrcaErrorInfo.from(SSLHandshakeException("handshake failed")))
    }
}
