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
        val path = setting("ORCA_PATH", "home")
        setContent {
            MaterialTheme {
                Surface { OrcaApp(client, path = path) }
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
