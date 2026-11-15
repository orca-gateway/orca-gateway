package com.orcagateway.sdk

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import com.orcagateway.core.client.DeviceIdentity
import com.orcagateway.core.client.KeyValueStore
import com.orcagateway.core.client.OfflineSessionStore
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.VersionCheckResult
import com.orcagateway.core.client.VersionChecker

/**
 * A [KeyValueStore] over the app's SharedPreferences named [name], where
 * Flutter keeps the same values (sdk/lib/src/widgets/orca_app.dart and
 * sdk/lib/src/client/offline_session_store.dart). OrcaApp keeps the device
 * id and the offline session queue in it; a host can use it with
 * [DeviceIdentity.resolve] to give its own client the same id. Swift twin
 * `UserDefaultsKeyValueStore`.
 */
public class SharedPreferencesKeyValueStore(context: Context, name: String = "orca_gateway") : KeyValueStore {
    private val preferences: SharedPreferences =
        context.applicationContext.getSharedPreferences(name, Context.MODE_PRIVATE)

    /** The saved string for [key], or null. */
    override fun getString(key: String): String? = preferences.getString(key, null)

    /** Saves [value] under [key]; null removes the key. */
    override fun putString(key: String, value: String?) {
        val editor = preferences.edit()
        if (value == null) editor.remove(key) else editor.putString(key, value)
        editor.apply()
    }
}

/**
 * This client with a device id: its own when it has one, else the one saved
 * in [store] (made on first run), as `_resolveDeviceId` in
 * sdk/lib/src/widgets/orca_app.dart gives the client an id whether or not
 * sessions are tracked. Swift twin `OrcaClient.identified(by:)`.
 */
internal fun OrcaClient.identified(store: KeyValueStore): OrcaClient =
    if (deviceId.isNullOrEmpty()) copy(deviceId = DeviceIdentity.resolve(store)) else this

/**
 * What OrcaApp does before its first page, the part of `_OrcaAppState`'s
 * boot in sdk/lib/src/widgets/orca_app.dart the natives have so far: with
 * `enableOffline`, the version check of `OrcaApp.preload`; a forceUpdate
 * answer blocks the app, any other answer boots it. Without it the app is
 * ready at once and asks nothing. [phase] is Compose state. Swift twin
 * `OrcaBootModel`.
 */
internal class OrcaBoot(private val client: OrcaClient, enableOffline: Boolean) {
    enum class Phase {
        /** The version check runs; the spinner shows. */
        Checking,

        /** Pages may load. */
        Ready,

        /** The server demands an update; no page is ever fetched. */
        ForceUpdate,
    }

    var phase: Phase by mutableStateOf(if (enableOffline) Phase.Checking else Phase.Ready)
        private set

    /**
     * Runs the version check once, with no local versions yet (the static
     * flow cache arrives with plan step 14). Does nothing unless checking.
     */
    suspend fun start() {
        if (phase != Phase.Checking) return
        val outcome = VersionChecker(client).check(emptyMap())
        phase = if (outcome.result == VersionCheckResult.ForceUpdate) Phase.ForceUpdate else Phase.Ready
    }
}

/**
 * OrcaApp's root: the page spinner while the version check runs, the
 * force-update screen when the server demands one, else [content], which is
 * built only then. With [enableSessionTracking], sessions are tracked here,
 * around all three, with [client]'s device id (the saved one when it has
 * none) and an offline queue in SharedPreferences. Swift twin `OrcaBootView`.
 */
@Composable
internal fun OrcaBootView(
    client: OrcaClient,
    enableOffline: Boolean,
    enableSessionTracking: Boolean,
    modifier: Modifier,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val boot = remember(client) { OrcaBoot(client, enableOffline) }
    LaunchedEffect(boot) { boot.start() }
    if (enableSessionTracking) {
        val store = remember(context) { SharedPreferencesKeyValueStore(context) }
        val deviceId = remember(client, store) { client.identified(store).deviceId }
        SessionTracking(client, deviceId, remember(store) { OfflineSessionStore(store) })
    }
    when (boot.phase) {
        OrcaBoot.Phase.Checking -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        OrcaBoot.Phase.ForceUpdate -> ForceUpdateScreen(modifier)
        OrcaBoot.Phase.Ready -> content()
    }
}

/** Flutter's default force-update screen (`_buildForceUpdate` in sdk/lib/src/widgets/orca_app.dart): one centred line. */
@Composable
private fun ForceUpdateScreen(modifier: Modifier) {
    Box(modifier.fillMaxSize().testTag("orca.forceUpdate"), contentAlignment = Alignment.Center) {
        Text("Update required. Please update the app.", textAlign = TextAlign.Center)
    }
}
