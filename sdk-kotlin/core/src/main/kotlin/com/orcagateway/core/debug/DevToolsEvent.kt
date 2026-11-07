package com.orcagateway.core.debug

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.SwiftText
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.state.StoreState
import java.util.Locale

/**
 * One message for Orca DevTools (schema/devtools-events.schema.json): a type
 * and its payload. [envelope] adds the device id and the time, as the
 * WebSocket client sends it. Each builder below makes the same payload as
 * its Dart counterpart in sdk/lib/src/debug/debug_events.dart and its Swift
 * one in sdk-swift/Sources/OrcaGatewayCore/Debug/DevToolsEvent.swift, field
 * for field; schema/fixtures/devtools pins all three.
 */
public data class DevToolsEvent(public val type: String, public val payload: Map<String, JsonValue>) {
    /**
     * `{type, deviceId, timestamp, payload}`; [timestamp] in milliseconds
     * since the Unix epoch.
     */
    public fun envelope(deviceId: String, timestamp: Long): JsonValue = JsonValue.Object(
        linkedMapOf(
            "type" to JsonValue.String(type),
            "deviceId" to JsonValue.String(deviceId),
            "timestamp" to JsonValue.Int(timestamp),
            "payload" to JsonValue.Object(payload),
        ),
    )

    /**
     * The client's marks of one page load, in milliseconds from the request
     * start (Dart `ClientTimingData`).
     */
    public data class ClientTiming(
        public val requestStartMs: Double = 0.0,
        public val responseReceivedMs: Double,
        public val parseCompleteMs: Double,
        public val renderStartMs: Double,
        public val renderCompleteMs: Double,
        public val firstFrameMs: Double,
    ) {
        internal val json: JsonValue
            get() = JsonValue.Object(
                linkedMapOf(
                    "requestStartMs" to JsonValue.Double(requestStartMs),
                    "responseReceivedMs" to JsonValue.Double(responseReceivedMs),
                    "parseCompleteMs" to JsonValue.Double(parseCompleteMs),
                    "renderStartMs" to JsonValue.Double(renderStartMs),
                    "renderCompleteMs" to JsonValue.Double(renderCompleteMs),
                    "firstFrameMs" to JsonValue.Double(firstFrameMs),
                ),
            )
    }

    /**
     * One measured phase of a request (`dns`, `connect`, `tls`, `request`,
     * `wait`, `download`).
     */
    public data class NetworkPhase(public val phase: String, public val durationMs: Double)

    public companion object {
        /** The handshake, sent first on every connect (Dart `deviceInfoPayload`). */
        public fun deviceInfo(
            platform: String,
            deviceModel: String,
            appVersion: String = "1.0.0",
            appName: String? = null,
        ): DevToolsEvent {
            val p = linkedMapOf<String, JsonValue>(
                "platform" to JsonValue.String(platform),
                "appVersion" to JsonValue.String(appVersion),
                "deviceModel" to JsonValue.String(deviceModel),
            )
            if (appName != null) p["appName"] = JsonValue.String(appName)
            return DevToolsEvent("device_info", p)
        }

        /**
         * One page load. [server] is the engine's `x-orca-timing` header as
         * parsed, left out when the engine sent none (or anything but an
         * object).
         */
        public fun timing(pageId: String, path: String, server: JsonValue?, client: ClientTiming): DevToolsEvent {
            val p = linkedMapOf(
                "pageId" to JsonValue.String(pageId),
                "path" to JsonValue.String(path),
                "client" to client.json,
            )
            if (server is JsonValue.Object) p["server"] = server
            return DevToolsEvent("timing", p)
        }

        /** One key of one scope changed; both values are always sent. */
        public fun stateChange(
            scope: StateScope,
            pageId: String,
            key: String,
            oldValue: JsonValue,
            newValue: JsonValue,
        ): DevToolsEvent = DevToolsEvent(
            "state_change",
            linkedMapOf(
                "scope" to JsonValue.String(scope.wire),
                "pageId" to JsonValue.String(pageId),
                "key" to JsonValue.String(key),
                "oldValue" to oldValue,
                "newValue" to newValue,
            ),
        )

        /**
         * Every key whose value differs between two states, page scope first,
         * keys in Swift's string order. Flutter reports per dispatched key; a
         * Kotlin commit, like a Swift one, replaces the whole state, so the
         * diff finds the same keys. A missing key reads as null.
         */
        public fun stateChanges(from: StoreState, to: StoreState, pageId: String): List<DevToolsEvent> {
            val events = ArrayList<DevToolsEvent>()
            for (scope in listOf(StateScope.Page, StateScope.App)) {
                val before = from[scope]
                val after = to[scope]
                for (key in (before.keys + after.keys).sortedWith(SwiftText.stringOrder)) {
                    val was = before[key] ?: JsonValue.Null
                    val now = after[key] ?: JsonValue.Null
                    if (was != now) events.add(stateChange(scope, pageId, key, was, now))
                }
            }
            return events
        }

        /** One action ran: the action as sent on the wire, and how long it took. */
        public fun action(action: Action, pageId: String, durationMs: Double): DevToolsEvent = DevToolsEvent(
            "action",
            linkedMapOf(
                "actionType" to JsonValue.String(action.kind),
                "family" to JsonValue.String(family(action.kind)),
                "pageId" to JsonValue.String(pageId),
                "data" to action.json,
                "durationMs" to JsonValue.Double(durationMs),
            ),
        )

        private val exactFamilies: Map<String, String> = mapOf(
            "setState" to "state", "navigate" to "navigation", "goBack" to "navigation",
            "switchTab" to "navigation", "showSnackbar" to "ui-feedback", "showToast" to "ui-feedback",
            "openDrawer" to "ui-feedback", "serverAction" to "data", "actionGroup" to "lifecycle",
            "conditionalAction" to "data", "openUrl" to "ui-feedback", "copyToClipboard" to "ui-feedback",
            "share" to "ui-feedback", "updateComponent" to "state", "deleteComponent" to "state",
            "addComponent" to "state", "replaceComponent" to "state",
        )

        /** The DevTools Actions panel's grouping (Dart `inferActionFamily`). */
        public fun family(actionType: String): String {
            exactFamilies[actionType]?.let { return it }
            val upper = SwiftText.uppercased(actionType)
            fun starts(prefix: String): Boolean = SwiftText.hasPrefix(upper, prefix)
            fun any(parts: List<String>): Boolean = parts.any { SwiftText.contains(upper, it) }
            return when {
                starts("NAVIGATE") || starts("GO_") || SwiftText.contains(upper, "ROUTE") -> "navigation"
                starts("SET_") || starts("UPDATE_") || starts("TOGGLE_") -> "state"
                any(listOf("TOAST", "SNACKBAR", "MODAL", "ALERT", "SCROLL")) -> "ui-feedback"
                starts("APP_") || any(listOf("LIFECYCLE", "AUTH_")) -> "lifecycle"
                any(listOf("FETCH", "LOAD", "CART", "SUBMIT", "APPLY_")) -> "data"
                else -> "custom"
            }
        }

        /**
         * One HTTP request; [statusCode] 0 when the transport failed. Pass
         * headers through [sanitize] first. Empty and missing fields are left
         * out, as Dart does.
         */
        public fun network(
            method: String,
            url: String,
            statusCode: Int,
            durationMs: Double,
            requestSizeBytes: Int? = null,
            responseSizeBytes: Int? = null,
            requestHeaders: Map<String, String> = emptyMap(),
            responseHeaders: Map<String, String> = emptyMap(),
            phases: List<NetworkPhase> = emptyList(),
        ): DevToolsEvent {
            val p = linkedMapOf<String, JsonValue>(
                "method" to JsonValue.String(method),
                "url" to JsonValue.String(url),
                "statusCode" to JsonValue.Int(statusCode.toLong()),
                "durationMs" to JsonValue.Double(durationMs),
            )
            if (requestSizeBytes != null) p["requestSizeBytes"] = JsonValue.Int(requestSizeBytes.toLong())
            if (responseSizeBytes != null) p["responseSizeBytes"] = JsonValue.Int(responseSizeBytes.toLong())
            if (requestHeaders.isNotEmpty()) p["requestHeaders"] = strings(requestHeaders)
            if (responseHeaders.isNotEmpty()) p["responseHeaders"] = strings(responseHeaders)
            if (phases.isNotEmpty()) {
                p["phases"] = JsonValue.Array(
                    phases.map {
                        JsonValue.Object(
                            linkedMapOf(
                                "phase" to JsonValue.String(it.phase),
                                "durationMs" to JsonValue.Double(it.durationMs),
                            ),
                        )
                    },
                )
            }
            return DevToolsEvent("network", p)
        }

        private fun strings(headers: Map<String, String>): JsonValue =
            JsonValue.Object(headers.mapValues { JsonValue.String(it.value) })

        /** Headers never sent to DevTools as they are (Dart `_sanitizeHeaders`). */
        public val redactedHeaders: Set<String> = setOf(
            "authorization", "cookie", "set-cookie", "x-api-key", "proxy-authorization",
        )

        /** [headers] with the value of every [redactedHeaders] name (any case) replaced by `<redacted>`. */
        public fun sanitize(headers: Map<String, String>): Map<String, String> =
            headers.mapValues { (name, value) -> if (name.lowercase(Locale.ROOT) in redactedHeaders) "<redacted>" else value }

        /**
         * A node redrew because a key it watches changed. [propTraces] maps a
         * prop to its transform steps (`{op, in?, out}`); the Kotlin resolver,
         * like the Swift one, does not trace, so the SDK sends it empty.
         */
        public fun widgetRebuild(
            widgetId: String,
            widgetType: String,
            watches: List<String>,
            propTraces: Map<String, List<JsonValue>> = emptyMap(),
        ): DevToolsEvent = DevToolsEvent(
            "widget_rebuild",
            linkedMapOf(
                "widgetId" to JsonValue.String(widgetId),
                "widgetType" to JsonValue.String(widgetType),
                "watches" to JsonValue.Array(watches.map { JsonValue.String(it) }),
                "propTraces" to JsonValue.Object(propTraces.mapValues { JsonValue.Array(it.value) }),
            ),
        )

        /**
         * An error; DevTools files it as a warning when the message or context
         * contains "warn", "notfound" or "404".
         */
        public fun error(message: String, stackTrace: String? = null, context: String? = null): DevToolsEvent {
            val p = linkedMapOf<String, JsonValue>("message" to JsonValue.String(message))
            if (stackTrace != null) p["stackTrace"] = JsonValue.String(stackTrace)
            if (context != null) p["context"] = JsonValue.String(context)
            return DevToolsEvent("error", p)
        }

        /**
         * The warning for a drawn FallbackPrompt (Dart
         * `DebugErrorEvent.fallbackPrompt`), sent once per unknown type.
         */
        public fun fallbackPrompt(widgetType: String): DevToolsEvent = error(
            message = "Unsupported widget type \"$widgetType\"; drew a FallbackPrompt",
            context = "warn: FallbackPrompt",
        )
    }
}
