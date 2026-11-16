package com.orcagateway.core.debug

/**
 * Receives the SDK's DevTools events. The sdk module's `DevToolsClient`
 * sends them over a WebSocket; tests record them. [report] is called from
 * any thread (Swift `DevToolsReporter`,
 * sdk-swift/Sources/OrcaGatewayCore/Debug/OrcaDebug.swift).
 */
public fun interface DevToolsReporter {
    public fun report(event: DevToolsEvent)
}

/**
 * What the core sends while a reporter is set: the four fields of Flutter's
 * `OrcaDebugConfig` (sdk/lib/src/debug/orca_debug.dart) the core reads, with
 * Flutter's names and defaults. `showOverlay` is the UI layer's.
 */
public data class OrcaDebugOptions(
    /** Off: the store sends no `state_change`. */
    public val captureStateChanges: Boolean = true,
    /** Off: the client sends no `network` event; its `error` events still go. */
    public val captureNetworkRequests: Boolean = true,
    /**
     * On: a `network` event carries `requestBody` and `responseBody`. Off by
     * default, as bodies can hold user data; there is no size cap.
     */
    public val includeBodies: Boolean = false,
    /** On: the UI layer also writes the `timing` event to the platform log. */
    public val logTimings: Boolean = false,
)

/**
 * Where DevTools events go, the Flutter `OrcaDebug.instance`: nowhere until
 * a [reporter] is set, and then the client, the store, the executor, the
 * renderer and the views send their events to it. Building an event costs
 * nothing while no reporter is set.
 */
public object OrcaDebug {
    /** Read and set from any thread; a single reference, so volatile is enough. */
    @Volatile
    public var reporter: DevToolsReporter? = null

    /**
     * What is sent, read on every event; settable from any thread. Starting
     * DevTools copies the host's config in (`options = OrcaDebugOptions(...)`),
     * stopping it puts the defaults back (`options = OrcaDebugOptions()`).
     */
    @Volatile
    public var options: OrcaDebugOptions = OrcaDebugOptions()

    public val isEnabled: Boolean get() = reporter != null

    /** Sends the event [event] builds; without a reporter [event] is never called. */
    public inline fun report(event: () -> DevToolsEvent) {
        val current = reporter ?: return
        current.report(event())
    }

    /** Milliseconds on a monotonic clock, for durations. */
    public fun now(): Double = System.nanoTime() / 1_000_000.0
}
