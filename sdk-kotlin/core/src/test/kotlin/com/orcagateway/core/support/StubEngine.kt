package com.orcagateway.core.support

import com.orcagateway.core.capabilities.CapabilityVector
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.json.JsonValue
import kotlinx.serialization.SerializationException

/**
 * A stand-in for the engine's page route with its capability-vector cache,
 * following engine/test/caps-412-protocol.test.ts: a known hash answers 200;
 * an unknown hash answers 412 caps_vector_unknown unless the body carries a
 * vector that hashes to it, which is then cached.
 */
class StubEngine(val page: ByteArray) : HttpTransport {
    private val lock = Any()
    private val cache = HashMap<String, CapabilityVector>()
    private val sent = ArrayList<HttpRequest>()

    /** When false the stub behaves like an engine without negotiation. */
    var negotiates = true

    /** Refuse every vector (the engine's case E: hash and vector disagree). */
    var refuseVectors = false

    /** Answer every request with this instead (a non-caps 412, a 500). */
    var forced: HttpResponse? = null

    val requests: List<HttpRequest> get() = synchronized(lock) { sent.toList() }

    fun cached(hash: String): CapabilityVector? = synchronized(lock) { cache[hash] }

    override suspend fun send(request: HttpRequest): HttpResponse = synchronized(lock) {
        sent.add(request)
        answer(request)
    }

    /** Called with the lock held; never suspends. */
    private fun answer(request: HttpRequest): HttpResponse {
        forced?.let { return it }
        val hash = request.headers["x-orca-caps-hash"]
        if (!negotiates || hash == null) return HttpResponse(200, body = page)
        if (cache[hash] != null) return HttpResponse(200, body = page)
        val vector = request.body?.let(::vectorIn)
        if (vector != null && !refuseVectors && vector.hash == hash) {
            cache[hash] = vector
            return HttpResponse(200, body = page)
        }
        return HttpResponse(412, body = """{"error":"caps_vector_unknown","hash":"$hash"}""".encodeToByteArray())
    }

    /** The `_orcaCapsVector` object of a JSON body, when it decodes as a vector. */
    private fun vectorIn(body: ByteArray): CapabilityVector? = try {
        val vector = JsonValue.parse(body)["_orcaCapsVector"]
        if (vector is JsonValue.Object) vector.decode(CapabilityVector.serializer()) else null
    } catch (_: SerializationException) {
        null
    }
}
