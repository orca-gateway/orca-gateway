package com.orcagateway.core.telemetry

import com.orcagateway.core.json.JsonValue

/**
 * The SDK's telemetry hook: a process-wide event sink the host sets once.
 * Ports Dart `OrcaTelemetry` (sdk/lib/src/telemetry/orca_telemetry.dart);
 * Swift twin `OrcaTelemetry`
 * (sdk-swift/Sources/OrcaGatewayCore/Telemetry/OrcaTelemetry.swift).
 * Each unknown widget type is reported once per process, whatever registry
 * saw it. Thread-safe.
 */
public object OrcaTelemetry {
    /**
     * Host-provided sink, `(event, data)`; null turns reporting off (the
     * dedup still runs). Known events: `unknown_widget_type` with
     * `{"type": "<type>"}`. Read and set from any thread.
     */
    @Volatile
    public var onEvent: ((String, Map<String, JsonValue>) -> Unit)? = null

    private val lock = Any()
    private val reportedUnknownTypes = HashSet<String>()

    /** Reports [type] as `unknown_widget_type` the first time this process sees it. */
    public fun reportUnknownWidgetOnce(type: String) {
        val first = synchronized(lock) { reportedUnknownTypes.add(type) }
        if (first) onEvent?.invoke("unknown_widget_type", mapOf("type" to JsonValue.String(type)))
    }

    /** Forgets every reported type. For tests only: in production it would repeat reports. */
    public fun resetForTesting() {
        synchronized(lock) { reportedUnknownTypes.clear() }
    }
}
