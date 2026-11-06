package com.orcagateway.core.client

import com.orcagateway.core.json.JsonValue
import kotlinx.serialization.SerializationException
import java.net.URI

/**
 * One HTTP request as [OrcaClient] builds it. Equality compares the body's
 * bytes, as Swift's `Data` does.
 */
public data class HttpRequest(
    public val method: String,
    public val url: URI,
    public val headers: Map<String, String> = emptyMap(),
    public val body: ByteArray? = null,
) {
    override fun equals(other: Any?): Boolean =
        other is HttpRequest && method == other.method && url == other.url && headers == other.headers &&
            body contentEquals other.body

    override fun hashCode(): Int = ((method.hashCode() * 31 + url.hashCode()) * 31 + headers.hashCode()) * 31 +
        body.contentHashCode()

    override fun toString(): String =
        "HttpRequest(method=$method, url=$url, headers=$headers, body=${body?.let { "${it.size} bytes" }})"
}

/** One HTTP response; header names are lowercased. */
public data class HttpResponse(
    public val status: Int,
    public val headers: Map<String, String> = emptyMap(),
    public val body: ByteArray = ByteArray(0),
) {
    /** `error` of a `{"error": "..."}` body, or null (Dart `_parseErrorField`). */
    public val errorField: String?
        get() = try {
            JsonValue.parse(body)["error"].stringValue
        } catch (_: SerializationException) {
            null
        }

    override fun equals(other: Any?): Boolean =
        other is HttpResponse && status == other.status && headers == other.headers && body contentEquals other.body

    override fun hashCode(): Int = (status * 31 + headers.hashCode()) * 31 + body.contentHashCode()

    override fun toString(): String = "HttpResponse(status=$status, headers=$headers, body=${body.size} bytes)"
}

/**
 * The seam between [OrcaClient] and the network, so the handshake and
 * headers are tested against a stub on any platform. The production
 * transport (OkHttp, which decodes gzip itself, as the engine sends it when
 * asked) lives in the Android module; the core has none.
 *
 * Implementations may be called from any thread and concurrently (Swift
 * `Sendable`), must not block the calling thread, lowercase the response's
 * header names, and throw when no response arrives at all. Any status,
 * 4xx and 5xx included, is a response, not an exception.
 */
public interface HttpTransport {
    public suspend fun send(request: HttpRequest): HttpResponse
}
