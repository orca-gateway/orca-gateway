package com.orcagateway.core.client

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action

/**
 * What the action executor needs from the HTTP client: the `/action` route.
 * The OkHttp `OrcaClient` (a later slice) implements it; tests stub it.
 */
public interface ActionClient {
    /**
     * `POST /api/v1/app/{appId}/action` with `{action, params?, pageState?,
     * appState?}`, returning the actions the server sent back (Dart
     * `executeAction`). Server actions skip the capability handshake.
     *
     * Like Dart, the body is read as JSON before the status is checked: a
     * body that is not JSON throws a decoding error, which a lifecycle's
     * `onError` sees; a JSON error body throws [OrcaActionException], which
     * the executor turns into a snackbar.
     */
    public suspend fun executeAction(
        id: String,
        params: Map<String, JsonValue>? = null,
        pageState: Map<String, JsonValue>? = null,
        appState: Map<String, JsonValue>? = null,
    ): List<Action>
}

/**
 * A server action answered with a status other than 200 (Swift
 * `OrcaClientError.action`). [message] is the body's `error`, or "Server
 * action failed" (Dart `OrcaClientException` from `executeAction`).
 */
public class OrcaActionException(public val status: Int, override val message: String) : Exception(message)
