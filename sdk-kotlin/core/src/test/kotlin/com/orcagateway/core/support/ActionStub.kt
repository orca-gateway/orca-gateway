package com.orcagateway.core.support

import com.orcagateway.core.client.ActionClient
import com.orcagateway.core.client.OrcaActionException
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action

/**
 * The engine's `/action` route, replaying canned answers by action id: an
 * `actions` entry answers 200 `{actions}`, an `error` entry answers 400
 * `{error}`, and an id with no entry answers 500. That matches the Dart
 * fixture runner's `_StubClient`. A `raw` entry is sent back exactly as given.
 *
 * Swift stubs the HTTP transport under the real OrcaClient. The OkHttp client
 * is a later slice, so this stub implements [ActionClient] and reads each
 * response the way Swift's `OrcaClient.executeAction` does: the body as JSON
 * first (a non-JSON body throws), then a status other than 200 throws
 * [OrcaActionException] with the body's `error` or "Server action failed".
 */
class ActionStub(
    private val responses: Map<String, JsonValue>,
    private val raw: Map<String, Response> = emptyMap(),
) : ActionClient {
    data class Response(val status: Int, val body: String)

    /** One `executeAction` call, and the POST body OrcaClient builds from it. */
    data class Call(
        val id: String,
        val params: Map<String, JsonValue>?,
        val pageState: Map<String, JsonValue>?,
        val appState: Map<String, JsonValue>?,
    ) {
        val body: JsonValue
            get() {
                val o = linkedMapOf<String, JsonValue>("action" to JsonValue.String(id))
                params?.let { o["params"] = JsonValue.Object(it) }
                pageState?.let { o["pageState"] = JsonValue.Object(it) }
                appState?.let { o["appState"] = JsonValue.Object(it) }
                return JsonValue.Object(o)
            }
    }

    private val lock = Any()
    private val calls = ArrayList<Call>()

    val requests: List<Call> get() = synchronized(lock) { calls.toList() }

    override suspend fun executeAction(
        id: String,
        params: Map<String, JsonValue>?,
        pageState: Map<String, JsonValue>?,
        appState: Map<String, JsonValue>?,
    ): List<Action> {
        synchronized(lock) { calls.add(Call(id, params, pageState, appState)) }
        val response = raw[id] ?: respond(id)
        // OrcaClient.executeAction: JSON first, then the status.
        val json = JsonValue.parse(response.body)
        if (response.status != 200) {
            throw OrcaActionException(response.status, json["error"].stringValue ?: "Server action failed")
        }
        return (json["actions"].arrayValue ?: emptyList()).map { it.decode(Action.serializer()) }
    }

    private fun respond(id: String): Response {
        val stub = responses[id]?.objectValue
            ?: return json(500, mapOf("error" to JsonValue.String("no stubbed response for \"$id\"")))
        val error = stub["error"]?.stringValue
        if (error != null) return json(400, mapOf("error" to JsonValue.String(error)))
        return json(200, mapOf("actions" to (stub["actions"] ?: JsonValue.Array(emptyList()))))
    }

    companion object {
        fun json(status: Int, body: Map<String, JsonValue>): Response = Response(status, JsonValue.Object(body).encoded())
    }
}
