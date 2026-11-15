package com.orcagateway.sdk

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.orcagateway.core.client.OfflineSessionStore
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.SessionTracker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.net.URI

/**
 * Drives [tracker] from the process lifecycle: ON_START is
 * [SessionTracker.foreground], ON_STOP [SessionTracker.background]. The
 * process lifecycle, not an activity's, so a rotation does not end the
 * session. Ports `_OrcaAppState.didChangeAppLifecycleState` and
 * `_initSession` (sdk/lib/src/widgets/orca_app.dart); the Swift twin is
 * OrcaApp's `scenePhase` handling (SessionLifecycle.swift).
 *
 * Process-wide: its scope belongs to no activity or composition, so the
 * ON_STOP that ProcessLifecycleOwner sends about 700 ms after the last
 * activity stops still reaches [SessionTracker.background], and that POST
 * is not cancelled, even when the activity finished in the meantime.
 * Attaching while the process is already started replays ON_START
 * (Lifecycle brings a new observer up to the current state), which sends
 * the first start, as Flutter's `_initSession` does. Attach on the main
 * thread.
 */
internal class SessionLifecycle(
    val tracker: SessionTracker,
    private val lifecycle: Lifecycle = ProcessLifecycleOwner.get().lifecycle,
) : DefaultLifecycleObserver {
    /** Process-lifetime scope: never cancelled, like the hook that owns it. */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onStart(owner: LifecycleOwner) {
        scope.launch { tracker.foreground() }
    }

    override fun onStop(owner: LifecycleOwner) {
        scope.launch { tracker.background() }
    }

    /** Starts listening; [ProcessSessions] calls it once per hook. */
    fun attach() {
        lifecycle.addObserver(this)
    }
}

/**
 * The process's session trackers: one per client base URL, appId and
 * device id, each with its [SessionLifecycle] attached on first use and
 * kept for the life of the process. A recreated activity (rotation, a
 * relaunch in the same process) gets the tracker it had, so it sends no
 * second start. Main thread only (Lifecycle.addObserver requires it).
 */
internal object ProcessSessions {
    private data class Key(val baseUrl: URI, val appId: String, val deviceId: String?)

    private val hooks = HashMap<Key, SessionLifecycle>()

    /**
     * The tracker for [client] and [deviceId]. The first call builds it over
     * [offline] and attaches its hook; later calls return it and ignore
     * [offline].
     */
    fun tracker(client: OrcaClient, deviceId: String?, offline: OfflineSessionStore): SessionTracker =
        hooks.getOrPut(Key(client.baseUrl, client.appId, deviceId)) {
            SessionLifecycle(SessionTracker(client, deviceId, offline)).also { it.attach() }
        }.tracker
}

/**
 * Tracks sessions for [client] (OrcaApp's `enableSessionTracking`) through
 * the process's tracker from [ProcessSessions]. Leaving the composition
 * removes nothing: the hook outlives the activity, so the session still
 * ends when the app goes to the background after the activity is gone.
 */
@Composable
internal fun SessionTracking(client: OrcaClient, deviceId: String?, offline: OfflineSessionStore) {
    DisposableEffect(client.baseUrl, client.appId, deviceId) {
        ProcessSessions.tracker(client, deviceId, offline)
        onDispose { /* process-wide: kept */ }
    }
}
