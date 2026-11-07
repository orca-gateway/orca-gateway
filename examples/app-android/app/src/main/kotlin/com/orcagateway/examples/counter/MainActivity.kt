package com.orcagateway.examples.counter

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.client.OkHttpTransport
import java.net.URI

/**
 * The counter example on Android: the same Bun server as the Flutter and iOS
 * examples, drawn by the Kotlin SDK. Start the server with
 * `task example:dev:server`, then `task example:android:run`.
 *
 * Any example app on that server runs here too: pass ORCA_APP_ID and
 * ORCA_PATH as intent extras (for example `basic-actions` and `home`), and
 * ORCA_SERVER_URL for another server.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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

    private fun setting(key: String, fallback: String): String =
        intent.getStringExtra(key)?.takeIf { it.isNotEmpty() } ?: fallback

    private companion object {
        /** The emulator reaches the computer running it at 10.0.2.2. */
        const val DEFAULT_SERVER = "http://10.0.2.2:8080"
    }
}
