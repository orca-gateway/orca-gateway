package com.orcagateway.examples.counter

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.client.OkHttpTransport
import com.orcagateway.sdk.debug.OrcaDebugConfig
import com.orcagateway.sdk.debug.start
import java.net.URI

/**
 * The counter example on Android: the same Bun server as the Flutter and iOS
 * examples, drawn by the Kotlin SDK. Start the server with
 * `task example:dev:server`, then `task example:android:run`.
 *
 * Any example app on that server runs here too: pass ORCA_APP_ID and
 * ORCA_PATH as intent extras (for example `basic-actions` and `home`, or
 * `server-actions` and `shop`), and ORCA_SERVER_URL for another server.
 * The boolean extras ORCA_OFFLINE and ORCA_SESSIONS turn on OrcaApp's
 * version check and session tracking; both are off by default.
 *
 * An app with a navigation config (app id `navigation`) boots from it with
 * the extra ORCA_BOOT set to `config`: the server's config says where the
 * app starts, and ORCA_PATH is not used.
 *
 * Two plugins (DemoPlugins.kt) draw the ColoredBadge and run the device
 * actions of the `custom` app: start it with ORCA_APP_ID `custom`.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startDevTools()
        val client = OrcaClient(
            baseUrl = URI(setting("ORCA_SERVER_URL", DEFAULT_SERVER)),
            appId = setting("ORCA_APP_ID", "counter"),
            apiKey = "demo-key",
            transport = OkHttpTransport(),
        )
        // The default app, `counter`, has no navigation config: it starts at a path.
        // No path (null) is how a host asks OrcaApp to boot from the server's config.
        val path = if (setting("ORCA_BOOT", "path") == "config") null else setting("ORCA_PATH", "home")
        val offline = intent.getBooleanExtra("ORCA_OFFLINE", false)
        val sessions = intent.getBooleanExtra("ORCA_SESSIONS", false)
        val plugins = listOf(BadgePlugin(), DeviceActionsPlugin(window.decorView))
        setContent {
            MaterialTheme {
                Surface {
                    OrcaApp(
                        client,
                        path = path,
                        enableOffline = offline,
                        enableSessionTracking = sessions,
                        plugins = plugins,
                    )
                }
            }
        }
    }

    /**
     * Debug builds show up in Orca DevTools (`task devtools:dev`, port 6363
     * on the Mac). The boolean extra ORCA_DEVTOOLS turns it on or off;
     * ORCA_DEVTOOLS_HOST points a device at the Mac running DevTools.
     *
     * Once per process: a rotation makes a new activity, not a second
     * connection.
     */
    private fun startDevTools() {
        if (OrcaDebug.isEnabled) return
        val debuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        OrcaDebug.start(
            OrcaDebugConfig(
                enabled = intent.getBooleanExtra("ORCA_DEVTOOLS", debuggable),
                host = setting("ORCA_DEVTOOLS_HOST", DEFAULT_DEVTOOLS_HOST),
                appName = applicationInfo.loadLabel(packageManager).toString(),
                appVersion = versionName(),
            ),
        )
    }

    private fun versionName(): String {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
        }
        return info.versionName ?: "unknown"
    }

    private fun setting(key: String, fallback: String): String =
        intent.getStringExtra(key)?.takeIf { it.isNotEmpty() } ?: fallback

    private companion object {
        /** The emulator reaches the computer running it at 10.0.2.2. */
        const val DEFAULT_SERVER = "http://10.0.2.2:8080"

        /** DevTools on that computer, as the emulator sees it. */
        const val DEFAULT_DEVTOOLS_HOST = "10.0.2.2"
    }
}
