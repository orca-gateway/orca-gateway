package com.orcagateway.core.client

import com.orcagateway.core.capabilities.CapabilityVector
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.PageResponse
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.net.URI
import java.net.URISyntaxException

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
 * Immutable, so one client can serve any number of coroutines; [copy] makes
 * a changed one (what assigning a `var` of the Swift struct does). The
 * network goes through [transport].
 */
public class OrcaClient(
    public val baseUrl: URI,
    public val appId: String,
    /** Sent as `Authorization: Bearer <apiKey>`. */
    public val apiKey: String? = null,
    /** Sent as `X-Orca-Env`. */
    public val environment: String? = null,
    /** Sent as `x-orca-device-id`, unless empty. */
    public val deviceId: String? = null,
    public val device: DeviceInfo = DeviceInfo(),
    public val capabilities: CapabilityVector = CapabilityVector.current,
    public val transport: HttpTransport,
) : ActionClient {
    /** `x-orca-caps-hash`: SHA-256 of the canonical vector, computed once. */
    public val capsHash: String = capabilities.hash

    /** This client with some settings changed (Swift: a copy of the struct with a `var` assigned). */
    public fun copy(
        baseUrl: URI = this.baseUrl,
        appId: String = this.appId,
        apiKey: String? = this.apiKey,
        environment: String? = this.environment,
        deviceId: String? = this.deviceId,
        device: DeviceInfo = this.device,
        capabilities: CapabilityVector = this.capabilities,
        transport: HttpTransport = this.transport,
    ): OrcaClient = OrcaClient(baseUrl, appId, apiKey, environment, deviceId, device, capabilities, transport)

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
    public suspend fun fetchPage(path: String, appState: Map<String, JsonValue>? = null): PageResponse {
        // DevTools reporting arrives with the adapters slice (S8).
        val url = pageUrl(path)
        val response = sendWithCapsRetry(url, appState)
        // DevTools reporting arrives with the adapters slice (S8).
        if (response.status == 200) {
            return Json.decodeFromString(PageResponse.serializer(), response.body.decodeToString())
        }
        return upgradeRequiredPage(response)
            ?: throw OrcaClientException.Http(response.status, response.body.decodeToString())
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

    /** The transport; the one place every request of this client goes through. */
    internal suspend fun send(request: HttpRequest): HttpResponse {
        // DevTools reporting arrives with the adapters slice (S8).
        return transport.send(request)
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
        val response = send(first)
        if (response.status != 412 || response.errorField != "caps_vector_unknown") return response

        // The retry is always a POST: the vector has to travel in the body.
        val body = linkedMapOf("_orcaCapsVector" to JsonValue.encoding(CapabilityVector.serializer(), capabilities))
        if (state != null) body["appState"] = JsonValue.Object(state)
        return send(HttpRequest("POST", url, json, JsonValue.Object(body).encoded().encodeToByteArray()))
    }

    internal companion object {
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
