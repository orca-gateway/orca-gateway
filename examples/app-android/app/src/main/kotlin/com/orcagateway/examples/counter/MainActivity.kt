package com.orcagateway.examples.counter

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.PreloadResult
import com.orcagateway.core.client.StaticFlowManager
import com.orcagateway.core.client.preload
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.navigation.DeeplinkEvent
import com.orcagateway.plugins.videoplayer.VideoPlayerPlugin
import com.orcagateway.plugins.voicerecorder.VoiceRecorderPlugin
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPlugin
import com.orcagateway.sdk.client.OkHttpTransport
import com.orcagateway.sdk.debug.OrcaDebugConfig
import com.orcagateway.sdk.debug.start
import com.orcagateway.sdk.offlineStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URI
import java.util.Locale

/**
 * The counter example on Android: the same Bun server as the Flutter and iOS
 * examples, drawn by the Kotlin SDK. Start the server with
 * `task example:dev:server`, then `task example:android:run`.
 *
 * Any example app on that server runs here too: pass ORCA_APP_ID and
 * ORCA_PATH as intent extras (for example `basic-actions` and `home`, or
 * `server-actions` and `shop`), and ORCA_SERVER_URL for another server.
 * The boolean extras ORCA_OFFLINE and ORCA_SESSIONS turn on OrcaApp's
 * offline boot (the version check, and with a config the offline cache of
 * static flows) and session tracking; both are off by default.
 *
 * While DevTools is on, the boolean extras ORCA_OVERLAY and ORCA_BODIES turn
 * on the load chip over each page and the request and response bodies in
 * DevTools' network events; both are off by default.
 *
 * An app with a navigation config (app id `navigation`) boots from it with
 * the extra ORCA_BOOT set to `config`: the server's config says where the
 * app starts, and ORCA_PATH is not used. There the boolean extra
 * ORCA_PRELOAD (off by default) makes the host await `preload` itself under
 * its own splash, then hand OrcaApp the config (see [PreloadedApp]).
 *
 * The app opens `orcacounter://` links (see "Deep links" in the README) and
 * logs one `deeplink:` line for each under the tag `OrcaCounter`.
 *
 * Four plugins serve the `custom` app (start it with ORCA_APP_ID `custom`):
 * two of this app's (DemoPlugins.kt) draw the ColoredBadge and run the device
 * actions, the voice recorder's (plugins/orca_voice_recorder/android) draws
 * the VoiceRecorder of its Voice Page and records and plays back, and the
 * video player's (plugins/orca_video_player/android) plays the VideoPlayer
 * of its Video Page and runs the page's playback buttons.
 *
 * Five more extras try OrcaApp's shell; without them the app is as before.
 * ORCA_API_KEY is the key sent (default `demo-key`; any other gets the
 * server's 401, and OrcaApp's Unauthorized screen). ORCA_SCHEME `dark` or
 * `light` puts this activity and OrcaApp on that Material 3 scheme. ORCA_LOCALE
 * is a language tag (`ar`, `fr-FR`) for OrcaApp's locale. The boolean
 * ORCA_SPLASH shows this app's own splash ([HostSplash]) while OrcaApp boots.
 * ORCA_TIMEOUT is the request timeout in seconds (default the SDK's 30).
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startDevTools()
        val built = OrcaClient(
            baseUrl = URI(setting("ORCA_SERVER_URL", DEFAULT_SERVER)),
            appId = setting("ORCA_APP_ID", "counter"),
            apiKey = setting("ORCA_API_KEY", "demo-key"),
            transport = OkHttpTransport(),
        )
        // No ORCA_TIMEOUT: the client keeps its own default.
        val timeoutMillis = setting("ORCA_TIMEOUT")?.toDoubleOrNull()?.let { (it * 1000).toLong() }
        val client = timeoutMillis?.takeIf { it > 0 }?.let { built.copy(timeoutMillis = it) } ?: built
        // The default app, `counter`, has no navigation config: it starts at a path.
        // No path (null) is how a host asks OrcaApp to boot from the server's config.
        val path = if (setting("ORCA_BOOT", "path") == "config") null else setting("ORCA_PATH", "home")
        val offline = intent.getBooleanExtra("ORCA_OFFLINE", false)
        val sessions = intent.getBooleanExtra("ORCA_SESSIONS", false)
        // Only with a config: a path has none to preload, and the extra is then ignored.
        val preloadFirst = path == null && intent.getBooleanExtra("ORCA_PRELOAD", false)
        val plugins = listOf(
            BadgePlugin(),
            DeviceActionsPlugin(window.decorView),
            VoiceRecorderPlugin(applicationContext),
            VideoPlayerPlugin(),
        )
        // No scheme (null): the theme's own, here and in OrcaApp.
        val scheme = when (setting("ORCA_SCHEME")) {
            "dark" -> darkColorScheme()
            "light" -> lightColorScheme()
            else -> null
        }
        val locale = setting("ORCA_LOCALE")?.let(Locale::forLanguageTag)
        val splash: (@Composable () -> Unit)? =
            if (intent.getBooleanExtra("ORCA_SPLASH", false)) ({ HostSplash() }) else null
        setContent {
            MaterialTheme(colorScheme = scheme ?: MaterialTheme.colorScheme) {
                Surface {
                    if (preloadFirst) {
                        PreloadedApp(client, sessions, plugins, scheme, locale)
                    } else {
                        OrcaApp(
                            client,
                            path = path,
                            enableOffline = offline,
                            enableSessionTracking = sessions,
                            plugins = plugins,
                            onDeeplink = ::logDeeplink,
                            splash = splash,
                            colorScheme = scheme,
                            locale = locale,
                        )
                    }
                }
            }
        }
    }

    /**
     * ORCA_PRELOAD: the host's own boot, as Flutter's `OrcaApp.preload` doc
     * shows it. Under a small splash of its own the host awaits `preload`
     * with a manager over `offlineStore(context)`, the files OrcaApp's
     * `enableOffline` uses, so both boots share one cache; the extra implies
     * the offline cache, and ORCA_OFFLINE adds nothing to it. OrcaApp then
     * gets the config and the same manager: it asks no `/version` and no
     * `/config`, and its first frame is the app. A force update is the host's
     * to show (a plain "Update required"; OrcaApp never sees it), and so is a
     * failed boot (a plain line with the error's message: offline with
     * nothing saved, "No network and no cached config available").
     *
     * The preload runs again when the activity is made again (a rotation);
     * OrcaApp keeps the router it started with.
     */
    @Composable
    private fun PreloadedApp(
        client: OrcaClient,
        sessions: Boolean,
        plugins: List<OrcaPlugin>,
        scheme: ColorScheme?,
        locale: Locale?,
    ) {
        val manager = remember { StaticFlowManager(offlineStore(applicationContext)) }
        // Null while the preload runs; its file work stays off the main thread, as in OrcaApp.
        val outcome by produceState<Result<PreloadResult>?>(null) {
            value = try {
                Result.success(withContext(Dispatchers.IO) { preload(client, manager) })
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
        when (val result = outcome) {
            null -> Centered {
                CircularProgressIndicator()
                Text("Checking version...")
            }
            else -> result.fold(
                onSuccess = { ready ->
                    when (ready) {
                        PreloadResult.ForceUpdate -> Centered { Text("Update required") }
                        is PreloadResult.Success -> OrcaApp(
                            client,
                            enableSessionTracking = sessions,
                            plugins = plugins,
                            onDeeplink = ::logDeeplink,
                            preloadedConfig = ready.config,
                            staticFlowManager = manager,
                            colorScheme = scheme,
                            locale = locale,
                        )
                    }
                },
                onFailure = { error -> Centered { Text(error.message ?: error.toString()) } },
            )
        }
    }

    @Composable
    private fun Centered(content: @Composable () -> Unit) {
        Column(
            Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) { content() }
    }

    /**
     * One line per `orcacounter://` link the app opened (the intent filter is
     * in the manifest; OrcaApp reads the Intents itself): `adb logcat -s OrcaCounter`.
     */
    private fun logDeeplink(event: DeeplinkEvent) {
        Log.i(
            "OrcaCounter",
            "deeplink: incoming=${event.incoming} resolvedLocation=${event.resolvedLocation} " +
                "wasRedirected=${event.wasRedirected} isColdStart=${event.isColdStart}",
        )
    }

    /**
     * Debug builds show up in Orca DevTools (`task devtools:dev`, port 6363
     * on the Mac). The boolean extra ORCA_DEVTOOLS turns it on or off;
     * ORCA_DEVTOOLS_HOST points a device at the Mac running DevTools.
     * ORCA_OVERLAY and ORCA_BODIES set showOverlay and includeBodies.
     *
     * Once per process: while DevTools is on, a new activity (a rotation)
     * neither opens a second connection nor reads these extras again.
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
                showOverlay = intent.getBooleanExtra("ORCA_OVERLAY", false),
                includeBodies = intent.getBooleanExtra("ORCA_BODIES", false),
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

    private fun setting(key: String, fallback: String): String = setting(key) ?: fallback

    /** The string extra [key], or null when it is missing or empty. */
    private fun setting(key: String): String? = intent.getStringExtra(key)?.takeIf { it.isNotEmpty() }

    private companion object {
        /** The emulator reaches the computer running it at 10.0.2.2. */
        const val DEFAULT_SERVER = "http://10.0.2.2:8080"

        /** DevTools on that computer, as the emulator sees it. */
        const val DEFAULT_DEVTOOLS_HOST = "10.0.2.2"
    }
}

/**
 * This app's own splash (ORCA_SPLASH), drawn in OrcaApp's place while it
 * boots: the version check (ORCA_OFFLINE) and the `/config` fetch (ORCA_BOOT
 * `config`). The app's name on a blue screen, so it cannot pass for the SDK's
 * spinner. The caption ends with the locale OrcaApp gives the views under it,
 * read from [LocalConfiguration] as OrcaApp provides it, so ORCA_LOCALE shows.
 */
@Composable
private fun HostSplash() {
    val locale = LocalConfiguration.current.locales[0].toLanguageTag()
    Column(
        Modifier.fillMaxSize().background(Color(0xFF1565C0)),
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Orca Counter", color = Color.White, fontSize = 36.sp, fontWeight = FontWeight.Bold)
        Text("host splash · $locale", color = Color.White.copy(alpha = 0.8f), fontSize = 14.sp)
    }
}
