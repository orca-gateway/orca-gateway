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
 * Where DevTools events go, the Flutter `OrcaDebug.instance`: nowhere until
 * a [reporter] is set, and then the client, the store, the executor, the
 * renderer and the views send their events to it. Building an event costs
 * nothing while no reporter is set.
 */
public object OrcaDebug {
    /** Read and set from any thread; a single reference, so volatile is enough. */
    @Volatile
    public var reporter: DevToolsReporter? = null

    public val isEnabled: Boolean get() = reporter != null

    /** Sends the event [event] builds; without a reporter [event] is never called. */
    public inline fun report(event: () -> DevToolsEvent) {
        val current = reporter ?: return
        current.report(event())
    }

    /** Milliseconds on a monotonic clock, for durations. */
    public fun now(): Double = System.nanoTime() / 1_000_000.0
}
