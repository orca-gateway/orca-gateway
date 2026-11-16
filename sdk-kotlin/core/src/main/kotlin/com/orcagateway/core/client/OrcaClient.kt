package com.orcagateway.core.client

import com.orcagateway.core.capabilities.CapabilityVector
import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.debug.OrcaDebugOptions
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.PageResponse
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.net.URI
import java.net.URISyntaxException
import kotlin.coroutines.cancellation.CancellationException

/**
 * A failed page request: a status other than 200, or a URL that cannot be
 * built (Swift `OrcaClientError.http` and `.invalidURL`). A refused server
 * action throws [OrcaActionException] instead (Swift `.action`).
 */
public sealed class OrcaClientException(message: String) : Exception(message) {
    /** The page route answered [status] with [body] (Dart `OrcaClientException`). */
    public class Http(public val status: Int, public val body: String) :
        OrcaClientException("Failed to fetch page: $status") {
        override fun equals(other: Any?): Boolean = other is Http && status == other.status && body == other.body

        override fun hashCode(): Int = status * 31 + body.hashCode()
    }

    /** [url] does not parse as a URI. */
    public class InvalidUrl(public val url: String) : OrcaClientException("Invalid URL: $url") {
        override fun equals(other: Any?): Boolean = other is InvalidUrl && url == other.url

        override fun hashCode(): Int = url.hashCode()
    }
}

/**
 * Talks to an Orca engine as the Android SDK: device and capability headers
 * on every request, and the capability handshake on page loads. A port of
 * `sdk/lib/src/client/orca_client.dart` (page fetch and server actions), by
 * way of the Swift SDK's `OrcaClient`.
 *
 * The handshake (Epic 25b slice 2, engine/test/caps-412-protocol.test.ts):
 * every request carries `x-orca-caps-hash`. When the server does not know the
 * hash yet it answers 412 `{"error": "caps_vector_unknown"}`; the client then
 * retries exactly once as a POST with the full vector under `_orcaCapsVector`,
 * and the server caches it, so later requests take the fast path. A second
 * 412 is returned to the caller as an error, never retried again.
 *
 * Immutable but for the capability extensions, so one client can serve any
 * number of coroutines; [copy] makes a changed one (what assigning a `var`
 * of the Swift struct does). The extensions are thread-safe and shared by a
 * client and every copy made of it, before or after a registration. The
 * network goes through [transport].
 */
public class OrcaClient private constructor(
    public val baseUrl: URI,
    public val appId: String,
    /** Sent as `Authorization: Bearer <apiKey>`. */
    public val apiKey: String?,
    /** Sent as `X-Orca-Env`. */
    public val environment: String?,
    /** Sent as `x-orca-device-id`, unless empty. */
    public val deviceId: String?,
    public val device: DeviceInfo,
    /** The vector the client was made with, before any extension. */
    private val baseCapabilities: CapabilityVector,
    public val transport: HttpTransport,
    /**
     * How long one request may take, send to answer, in milliseconds: Dart
     * `timeout` (sdk/lib/src/client/orca_client.dart), 30 s by default,
     * applied to every request as Flutter's is: every request the
     * client sends carries it ([HttpRequest.timeoutMillis]) and the
     * transport enforces it. Past it the request throws the transport's
     * timeout error (OkHttp's `InterruptedIOException`), which
     * [OrcaErrorInfo] shows as Connection Failed.
     */
    public val timeoutMillis: Long,
    private val extensions: Extensions,
) : ActionClient {
    public constructor(
        baseUrl: URI,
        appId: String,
        apiKey: String? = null,
        environment: String? = null,
        deviceId: String? = null,
        device: DeviceInfo = DeviceInfo(),
        capabilities: CapabilityVector = CapabilityVector.current,
        transport: HttpTransport,
        timeoutMillis: Long = 30_000,
    ) : this(
        baseUrl, appId, apiKey, environment, deviceId, device, capabilities, transport, timeoutMillis, Extensions(),
    )

    /**
     * The advertised vector: the one the client was made with plus the
     * registered extensions ([CapabilityVector.adding]); the base itself
     * while nothing is registered.
     */
    public val capabilities: CapabilityVector get() = advertised().vector

    /**
     * `x-orca-caps-hash`: SHA-256 of the canonical [capabilities],
     * recomputed only when the extensions grew.
     */
    public val capsHash: String get() = advertised().hash

    /**
     * This client with some settings changed (Swift: a copy of the struct
     * with a `var` assigned). [capabilities] is the new base; the copy shares
     * this client's extensions.
     */
    public fun copy(
        baseUrl: URI = this.baseUrl,
        appId: String = this.appId,
        apiKey: String? = this.apiKey,
        environment: String? = this.environment,
        deviceId: String? = this.deviceId,
        device: DeviceInfo = this.device,
        capabilities: CapabilityVector = this.baseCapabilities,
        transport: HttpTransport = this.transport,
        timeoutMillis: Long = this.timeoutMillis,
    ): OrcaClient = OrcaClient(
        baseUrl, appId, apiKey, environment, deviceId, device, capabilities, transport, timeoutMillis, extensions,
    )

    /**
     * Dart `registerCapabilityExtensions`
     * (sdk/lib/src/client/orca_client.dart): advertise plugin [widgets]
     * verbatim and each plugin action bare and as `custom:<name>`, from the
     * next request on, on this client and every copy of it. Idempotent: what
     * is already registered changes nothing, not even the hash.
     */
    public fun registerCapabilityExtensions(
        widgets: Iterable<String> = emptyList(),
        actions: Iterable<String> = emptyList(),
    ) {
        extensions.add(widgets, actions)
    }

    /** The registered names; they only grow, so their count tells whether a cached vector is current. */
    private class Extensions {
        private val widgets = LinkedHashSet<String>()
        private val actions = LinkedHashSet<String>()

        val count: Int get() = synchronized(this) { widgets.size + actions.size }

        fun add(widgets: Iterable<String>, actions: Iterable<String>) {
            synchronized(this) {
                this.widgets.addAll(widgets)
                this.actions.addAll(actions)
            }
        }

        /** The vector [base] advertises with these extensions, and the count it reflects. */
        fun applied(base: CapabilityVector): Pair<Int, CapabilityVector> = synchronized(this) {
            val count = widgets.size + actions.size
            count to if (count == 0) base else base.adding(widgets.toList(), actions.toList())
        }
    }

    /** The advertised vector and its hash, for [count] registered extension names. */
    private class Advertised(val count: Int, val vector: CapabilityVector, val hash: String)

    private val cacheLock = Any()
    private var cached: Advertised? = null

    private fun advertised(): Advertised = synchronized(cacheLock) {
        cached?.takeIf { it.count == extensions.count }
            ?: extensions.applied(baseCapabilities).let { (count, vector) -> Advertised(count, vector, vector.hash) }
                .also { cached = it }
    }

    /** Every header the client sends, as the Dart `_deviceHeaders` builds them. */
    public val headers: Map<String, String>
        get() {
            val h = LinkedHashMap(device.headers)
            deviceId?.takeIf { it.isNotEmpty() }?.let { h["x-orca-device-id"] = it }
            apiKey?.let { h["Authorization"] = "Bearer $it" }
            environment?.let { h["X-Orca-Env"] = it }
            h["x-orca-sdk-version"] = capabilities.sdkSemver
            h["x-orca-caps-hash"] = capsHash
            return h
        }

    /**
     * `GET /api/v1/app/{appId}/page/{path}`, or a POST with `{appState}` when
     * app state is given, with the capability handshake.
     *
     * A 200 decodes as the page; a 426 that carries an upgrade page returns
     * that page; anything else throws [OrcaClientException.Http] with the
     * status and the body as text.
     */
    public suspend fun fetchPage(path: String, appState: Map<String, JsonValue>? = null): PageResponse =
        fetchPageTimed(path, appState).first

    /** [fetchPage], plus what it measured for the DevTools `timing` event. */
    public suspend fun fetchPageTimed(
        path: String,
        appState: Map<String, JsonValue>? = null,
    ): Pair<PageResponse, PageLoadTiming> {
        val start = OrcaDebug.now()
        val url = pageUrl(path)
        val response = sendWithCapsRetry(url, appState)
        val received = OrcaDebug.now() - start
        val page = if (response.status == 200) {
            Json.decodeFromString(PageResponse.serializer(), response.body.decodeToString())
        } else {
            upgradeRequiredPage(response)
                ?: throw OrcaClientException.Http(response.status, response.body.decodeToString())
        }
        val server = response.headers["x-orca-timing"]?.let {
            try {
                JsonValue.parse(it)
            } catch (_: SerializationException) {
                null
            }
        }
        return page to PageLoadTiming(start, server, received, OrcaDebug.now() - start)
    }

    /**
     * `GET /api/v1/app/{appId}/config` with the device headers (Dart
     * `fetchConfig`): the navigation config, with the body text kept in
     * `rawBody`. No capability handshake, as in Flutter: the engine never
     * checks capabilities on this route.
     *
     * Any status but 200 throws [OrcaClientException.Http]; a body that is
     * not a config throws a [SerializationException].
     */
    public suspend fun fetchConfig(): NavConfig {
        val response = send(HttpRequest("GET", endpointUrl("config"), headers))
        val body = response.body.decodeToString()
        if (response.status != 200) throw OrcaClientException.Http(response.status, body)
        return NavConfig.fromJson(JsonValue.parse(body), rawBody = body)
    }

    /**
     * `POST /api/v1/app/{appId}/action` with `{action, params?, pageState?,
     * appState?}`, returning the actions the server sent back (Dart
     * `executeAction`). Server actions skip the capability handshake: the
     * engine never checks capabilities on this route and Flutter never
     * retries one, so neither does Kotlin.
     *
     * Like Dart, the body is read as JSON before the status is checked: a
     * body that is not JSON throws a [SerializationException], which a
     * lifecycle's `onError` sees; a JSON error body throws
     * [OrcaActionException], which the executor turns into a snackbar.
     */
    override suspend fun executeAction(
        id: String,
        params: Map<String, JsonValue>?,
        pageState: Map<String, JsonValue>?,
        appState: Map<String, JsonValue>?,
    ): List<Action> {
        val url = endpointUrl("action")
        val body = linkedMapOf<String, JsonValue>("action" to JsonValue.String(id))
        params?.let { body["params"] = JsonValue.Object(it) }
        pageState?.let { body["pageState"] = JsonValue.Object(it) }
        appState?.let { body["appState"] = JsonValue.Object(it) }
        val headers = LinkedHashMap(this.headers)
        headers["Content-Type"] = "application/json"
        val response = send(HttpRequest("POST", url, headers, JsonValue.Object(body).encoded().encodeToByteArray()))
        val json = JsonValue.parse(response.body)
        if (response.status != 200) {
            throw OrcaActionException(response.status, json["error"].stringValue ?: "Server action failed")
        }
        return (json["actions"].arrayValue ?: emptyList()).map { it.decode(Action.serializer()) }
    }

    /**
     * The transport, the one place every request of this client goes
     * through, plus a DevTools `network` event per request and an `error`
     * event for one that failed or was refused (Dart `_reportFailedRequest`
     * and `_reportHttpErrorResponse`). With [handshake] a 412
     * caps_vector_unknown is the expected first step of the handshake, so no
     * error; the refused retry is one, as in Dart (Swift skips it). A
     * cancelled request is not a failure: it goes up with no event at all.
     *
     * [OrcaDebugOptions.captureNetworkRequests] off drops the `network`
     * event, never the `error` one. [OrcaDebugOptions.includeBodies] on adds
     * [requestBody] (by default the request's JSON body; a page fetch passes
     * its app state, as Dart does) and the response as [bodyJson] (none when
     * the transport failed). Each request goes out with [timeoutMillis]
     * unless it has its own.
     */
    internal suspend fun send(
        built: HttpRequest,
        handshake: Boolean = false,
        requestBody: () -> JsonValue? = { built.body?.let(::bodyJson) },
    ): HttpResponse {
        val request = if (built.timeoutMillis == null) built.copy(timeoutMillis = timeoutMillis) else built
        if (!OrcaDebug.isEnabled) return transport.send(request)
        val options = OrcaDebug.options
        val start = OrcaDebug.now()
        val url = request.url.toString()
        val context = "${request.method} $url"
        val requestHeaders = DevToolsEvent.sanitize(request.headers)
        val response = try {
            transport.send(request)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            val ms = OrcaDebug.now() - start
            if (options.captureNetworkRequests) {
                OrcaDebug.report {
                    DevToolsEvent.network(
                        request.method, url, statusCode = 0, durationMs = ms, requestSizeBytes = request.body?.size,
                        requestHeaders = requestHeaders, phases = listOf(DevToolsEvent.NetworkPhase("wait", ms)),
                        requestBody = if (options.includeBodies) requestBody() else null,
                    )
                }
            }
            OrcaDebug.report { DevToolsEvent.error(message = "Network request failed: $e", context = context) }
            throw e
        }
        val ms = OrcaDebug.now() - start
        if (options.captureNetworkRequests) {
            OrcaDebug.report {
                DevToolsEvent.network(
                    request.method, url, response.status, ms, requestSizeBytes = request.body?.size,
                    responseSizeBytes = response.body.size, requestHeaders = requestHeaders,
                    responseHeaders = DevToolsEvent.sanitize(response.headers),
                    phases = listOf(DevToolsEvent.NetworkPhase("wait", ms)),
                    requestBody = if (options.includeBodies) requestBody() else null,
                    responseBody = if (options.includeBodies) bodyJson(response.body) else null,
                )
            }
        }
        val expected = handshake && response.status == 412 && response.errorField == "caps_vector_unknown"
        if (response.status >= 400 && !expected) {
            OrcaDebug.report {
                DevToolsEvent.error(
                    message = "HTTP ${response.status} ${request.url.path}",
                    stackTrace = response.body.decodeToString(),
                    context = context,
                )
            }
        }
        return response
    }

    internal fun pageUrl(path: String): URI = endpointUrl("page/${path.removePrefix("/")}")

    /**
     * `{baseUrl}/api/v1/app/{appId}/{rest}`, with any trailing slash of the
     * base URL dropped.
     */
    internal fun endpointUrl(rest: String): URI {
        val text = "${baseUrl.toString().trimEnd('/')}/api/v1/app/$appId/$rest"
        return try {
            URI(text)
        } catch (_: URISyntaxException) {
            throw OrcaClientException.InvalidUrl(text)
        }
    }

    /**
     * Dart `_sendPageRequestWithCapsRetry`: at most one retry, only for
     * `caps_vector_unknown`; any other 412 goes back to the caller as is.
     */
    internal suspend fun sendWithCapsRetry(url: URI, appState: Map<String, JsonValue>?): HttpResponse {
        val base = headers
        val state = appState?.takeIf { it.isNotEmpty() }
        val json = LinkedHashMap(base)
        json["Content-Type"] = "application/json"

        val first = if (state != null) {
            HttpRequest(
                "POST", url, json,
                JsonValue.Object(mapOf("appState" to JsonValue.Object(state))).encoded().encodeToByteArray(),
            )
        } else {
            HttpRequest("GET", url, base)
        }
        // DevTools shows a page fetch's app state, not its wire body, and none
        // for an empty one: Flutter's page passes null then (Dart).
        val sentState: () -> JsonValue? = { state?.let { JsonValue.Object(it) } }
        val response = send(first, handshake = true, requestBody = sentState)
        if (response.status != 412 || response.errorField != "caps_vector_unknown") return response

        // The retry is always a POST: the vector has to travel in the body.
        val body = linkedMapOf("_orcaCapsVector" to JsonValue.encoding(CapabilityVector.serializer(), capabilities))
        if (state != null) body["appState"] = JsonValue.Object(state)
        return send(
            HttpRequest("POST", url, json, JsonValue.Object(body).encoded().encodeToByteArray()),
            requestBody = sentState,
        )
    }

    internal companion object {
        /** A body as DevTools shows it: its JSON, else its text (Dart `_tryDecodeJson`). */
        fun bodyJson(bytes: ByteArray): JsonValue = try {
            JsonValue.parse(bytes)
        } catch (_: SerializationException) {
            JsonValue.String(bytes.decodeToString())
        }

        /**
         * The upgrade screen of a 426 (Epic 25b.6): below the app's minimum
         * SDK version the engine answers `{error, minSdkVersion,
         * clientSdkVersion, page}`, where `page` is one blocking
         * FallbackPrompt. The page is rendered like any other, as Flutter
         * does; a 426 without a page, or any other status, stays an error.
         */
        fun upgradeRequiredPage(response: HttpResponse): PageResponse? {
            if (response.status != 426) return null
            val page = try {
                JsonValue.parse(response.body)["page"]
            } catch (_: SerializationException) {
                return null
            }
            if (page !is JsonValue.Object) return null
            return try {
                page.decode(PageResponse.serializer())
            } catch (_: SerializationException) {
                null
            }
        }
    }
}

/**
 * What a page fetch measured, for the DevTools `timing` event: the engine's
 * `x-orca-timing` header and the client's marks, in milliseconds from the
 * request start. The page view adds the render marks.
 */
public data class PageLoadTiming(
    /** When the request started, on [OrcaDebug.now]'s clock. */
    public val startMs: Double,
    /** The `x-orca-timing` header as parsed, or null when absent or not JSON. */
    public val server: JsonValue?,
    public val responseReceivedMs: Double,
    public val parseCompleteMs: Double,
) {
    /** Milliseconds since the request started. */
    public fun elapsed(): Double = OrcaDebug.now() - startMs

    public fun event(
        pageId: String,
        path: String,
        renderStartMs: Double,
        renderCompleteMs: Double,
        firstFrameMs: Double,
    ): DevToolsEvent = DevToolsEvent.timing(
        pageId, path, server,
        DevToolsEvent.ClientTiming(
            responseReceivedMs = responseReceivedMs, parseCompleteMs = parseCompleteMs,
            renderStartMs = renderStartMs, renderCompleteMs = renderCompleteMs, firstFrameMs = firstFrameMs,
        ),
    )
}
