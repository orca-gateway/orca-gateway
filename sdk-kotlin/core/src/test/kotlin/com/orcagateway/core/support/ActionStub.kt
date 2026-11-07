package com.orcagateway.core.support

import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import java.net.URI

/**
 * The engine's `/action` route, replaying canned answers by action id: an
 * `actions` entry answers 200 `{actions}`, an `error` entry answers 400
 * `{error}`, and an id with no entry answers 500. That matches the Dart
 * fixture runner's `_StubClient`. A `raw` entry is sent back exactly as given.
 *
 * A transport, as in Swift: the executor talks to the real [OrcaClient]
 * ([client]), which sends its requests here.
 */
class ActionStub(
    private val responses: Map<String, JsonValue>,
    private val raw: Map<String, HttpResponse> = emptyMap(),
) : HttpTransport {
    private val lock = Any()
    private val sent = ArrayList<HttpRequest>()

    val requests: List<HttpRequest> get() = synchronized(lock) { sent.toList() }

    override suspend fun send(request: HttpRequest): HttpResponse {
        synchronized(lock) { sent.add(request) }
        val body = JsonValue.parse(request.body ?: ByteArray(0))
        val id = body["action"].stringValue ?: ""
        raw[id]?.let { return it }
        val stub = responses[id]?.objectValue
            ?: return json(500, mapOf("error" to JsonValue.String("no stubbed response for \"$id\"")))
        stub["error"]?.stringValue?.let { return json(400, mapOf("error" to JsonValue.String(it))) }
        return json(200, mapOf("actions" to (stub["actions"] ?: JsonValue.Array(emptyList()))))
    }

    companion object {
        fun json(status: Int, body: Map<String, JsonValue>): HttpResponse =
            HttpResponse(status, body = JsonValue.Object(body).encoded().encodeToByteArray())

        fun client(transport: HttpTransport): OrcaClient =
            OrcaClient(URI("http://stub.invalid"), "fixture-app", transport = transport)
    }
}
