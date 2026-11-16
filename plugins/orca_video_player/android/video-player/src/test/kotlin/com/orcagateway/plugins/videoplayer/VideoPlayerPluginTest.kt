package com.orcagateway.plugins.videoplayer

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.os.Looper
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.assertHeightIsEqualTo
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertWidthIsEqualTo
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.plugins.PluginMerger
import com.orcagateway.core.plugins.TriggerDefinition
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.toParts
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.TestScope
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowMediaPlayer
import org.robolectric.shadows.util.DataSource
import java.io.IOException
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNotSame
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** A player that plays nothing: the test prepares, fails, moves and ends it, and reads what the plugin asked of it. */
private class FakePlayback : VideoPlayback {
    val calls = ArrayList<String>()
    override var events: VideoPlayback.Events? = null
    override var positionMs: Long = 0
    /** The surface the view handed over, if any. */
    var target: Surface? = null

    override fun open(url: String) {
        calls += "open $url"
    }

    override fun setSurface(surface: Surface?) {
        target = surface
    }

    override fun play() {
        calls += "play"
    }

    override fun pause() {
        calls += "pause"
    }

    override fun seekTo(positionMs: Long) {
        calls += "seek $positionMs"
        this.positionMs = positionMs
    }

    override fun setVolume(volume: Double) {
        calls += "volume $volume"
    }

    override fun setSpeed(speed: Double) {
        calls += "speed $speed"
    }

    override fun setLooping(looping: Boolean) {
        calls += "looping $looping"
    }

    override fun release() {
        calls += "release"
    }

    /** MediaPlayer's onPrepared: a 10 s, 1920 by 1080 video unless the test says otherwise. */
    fun prepared(durationMs: Long = 10_000, width: Int = 1920, height: Int = 1080) =
        assertNotNull(events, "the plugin listens").prepared(durationMs, width, height)

    fun failed(message: String) = assertNotNull(events, "the plugin listens").failed(message)

    /** MediaPlayer's onCompletion: the position stops at [atMs]. */
    fun completed(atMs: Long) {
        positionMs = atMs
        assertNotNull(events, "the plugin listens").completed()
    }
}

/** What MediaPlayerPlayback tells the plugin, written down. */
private class RecordedEvents : VideoPlayback.Events {
    val log = ArrayList<String>()

    override fun prepared(durationMs: Long, width: Int, height: Int) {
        log += "prepared $durationMs ${width}x$height"
    }

    override fun resized(width: Int, height: Int) {
        log += "resized ${width}x$height"
    }

    override fun failed(message: String) {
        log += "failed $message"
    }

    override fun completed() {
        log += "completed"
    }
}

private val TRIGGERS = listOf("onPlay", "onPause", "onComplete", "onProgress", "onError")
private val FIVE = setOf("playVideo", "pauseVideo", "seekVideo", "setVolume", "setPlaybackSpeed")
private const val CLIP = "https://example.com/clip.mp4"
private const val OTHER = "https://example.com/other.mp4"

/**
 * C17.2/K: the video player on Android does what Flutter's
 * plugins/orca_video_player/lib/src/video_player_plugin.dart does on
 * video_player 2.11.1: the widget's props and defaults (:94-111), a player
 * per playerId registered once it is ready and gone when its view leaves or
 * its url changes (:150-216), the triggers fired as Flutter fires them
 * (onPlay and onPause from the overlay tap only, onProgress on each update
 * while playing, onComplete once at the end, onError when it cannot load:
 * :163-227), the five actions with their params and video_player's clamps
 * (:291-332), and the loading, error and ready views with the overlay
 * (:229-286). MediaPlayer is a fake, the 100 ms position ticks run on a test
 * scheduler, and nothing touches the network.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VideoPlayerPluginTest {
    @get:Rule
    val compose = createComposeRule()

    private val playbacks = ArrayList<FakePlayback>()
    private val ticks = TestScope()
    private val plugin = VideoPlayerPlugin({ FakePlayback().also { playbacks += it } }, ticks)

    /** The player of the view shown last. */
    private val playback: FakePlayback get() = playbacks.last()

    /** What the node's triggers ran, in order: the trigger and the event data its action read. */
    private val fired = ArrayList<Pair<String, Map<String, JsonValue>>>()

    private val model = OrcaPageModel(
        PageResponse(
            pageId = "p",
            title = "P",
            state = listOf(
                StateDefinition("pid", StateScope.Page, JsonValue.String("demo")),
                StateDefinition("to", StateScope.Page, JsonValue.Int(2_500)),
                StateDefinition("vol", StateScope.Page, JsonValue.Double(0.25)),
                StateDefinition("rate", StateScope.Page, JsonValue.Double(1.5)),
            ),
        ),
    ).also { model ->
        for ((type, handler) in plugin.actions) model.executor.registerHandler(type, handler)
        model.executor.registerHandler(
            "fired",
            OrcaActionHandler { action, executor ->
                val trigger = assertNotNull(JsonValue.fromJsonElement(assertNotNull(action["trigger"])).stringValue)
                val data = LinkedHashMap<String, JsonValue>()
                for (key in listOf("position", "duration", "fraction", "message")) {
                    val value = JsonValue.fromJsonElement(executor.resolve(event(key).toJsonElement()))
                    if (!value.isNull) data[key] = value
                }
                fired += trigger to data
            },
        )
    }

    private var shown: ResolvedNode? by mutableStateOf(null)
    private var root: View? = null

    @After
    fun forgetMediaInfo() {
        ShadowMediaPlayer.resetStaticState()
    }

    private fun event(key: String) = JsonValue.obj("type" to "event", "key" to key)

    private fun pageState(key: String) = JsonValue.obj("type" to "state", "key" to key, "scope" to "page")

    /** A resolved VideoPlayer node with [props]; each of its five triggers runs `custom:fired`. */
    private fun node(vararg props: Pair<String, JsonValue>) = ResolvedNode(
        id = "video",
        type = "VideoPlayer",
        kind = ComponentNode.Kind.Primitive,
        props = mapOf(*props),
        childIds = emptyList(),
        slots = emptyMap(),
        actions = TRIGGERS.associateWith { Action.Custom(JsonValue.obj("type" to "custom:fired", "trigger" to it)) },
        watches = emptyList(),
    )

    private fun url(url: String) = "url" to JsonValue.String(url)

    /** Draw [node] through the plugin's builder in a 320 dp wide box. */
    private fun show(node: ResolvedNode) {
        shown = node
        val builder = plugin.widgets.getValue("VideoPlayer")
        compose.setContent {
            root = LocalView.current
            Box(Modifier.width(320.dp)) { shown?.let { builder(it, model, Modifier) } }
        }
        compose.waitForIdle()
    }

    /** Draw [node] in place of the one shown (null takes the view away). */
    private fun reshow(node: ResolvedNode?) {
        shown = node
        compose.waitForIdle()
    }

    /** Run the action `custom:<name>` with [params] as a page does: through the page's executor. */
    private fun run(name: String, vararg params: Pair<String, Any?>) = runBlocking {
        model.executor.execute(Action.Custom(JsonValue.obj("type" to "custom:$name", *params)))
    }

    /** Let [ms] of the position ticks' time pass, running what is due at the end. */
    @OptIn(ExperimentalCoroutinesApi::class)
    private fun advance(ms: Long) {
        ticks.testScheduler.advanceTimeBy(ms)
        ticks.testScheduler.runCurrent()
    }

    private fun progress(position: Long, duration: Long = 10_000) = "onProgress" to mapOf(
        "position" to JsonValue.Int(position),
        "duration" to JsonValue.Int(duration),
        "fraction" to JsonValue.Double(position.toDouble() / duration),
    )

    private fun trigger(name: String) = name to emptyMap<String, JsonValue>()

    /** The overlay's play button: the tap target merges it into itself, so it is found in the unmerged tree. */
    private fun playButton() = compose.onNodeWithTag(PLAY_BUTTON_TAG, useUnmergedTree = true)

    /** A ready player under the node's id, shown with [props] and the clip. */
    private fun ready(vararg props: Pair<String, JsonValue>): FakePlayback {
        show(node(url(CLIP), *props))
        playback.prepared()
        compose.waitForIdle()
        return playback
    }

    /** What the plugin asked after the four calls of a ready player that does not play (open, looping, volume, pause). */
    private fun FakePlayback.afterReady() = calls.drop(4)

    @Test
    fun c17_2_thePluginHasFluttersNameWidgetFiveActionsAndFiveTriggers() {
        assertEquals("VideoPlayerPlugin", plugin.name)
        assertEquals(setOf("VideoPlayer"), plugin.widgets.keys)
        assertEquals(FIVE, plugin.actions.keys)
        assertEquals(
            mapOf(
                "VideoPlayer" to listOf(
                    TriggerDefinition("onPlay", null, "Fires when playback starts"),
                    TriggerDefinition("onPause", null, "Fires when playback pauses"),
                    TriggerDefinition("onComplete", null, "Fires when video reaches the end"),
                    TriggerDefinition("onProgress", "VideoProgress", "Fires with {position, duration, fraction} during playback"),
                    TriggerDefinition("onError", "String", "Fires with {message} on playback error"),
                ),
            ),
            plugin.triggers,
        )

        val merged = PluginMerger.merge(builtInWidgets = WidgetRegistry.shared.types, plugins = listOf(plugin.toParts()))
        assertEquals(setOf("VideoPlayer"), merged.pluginWidgetTypes)
        assertEquals(FIVE, merged.pluginActionTypes)

        // What a host makes: Flutter's VideoPlayerPlugin() takes nothing, nor does this one.
        val device = VideoPlayerPlugin()
        assertEquals("VideoPlayerPlugin", device.name)
        assertEquals(FIVE, device.actions.keys)
    }

    @Test
    fun c17_2_theModuleManifestDeclaresInternet() {
        val context = RuntimeEnvironment.getApplication()
        val info = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
        assertTrue(Manifest.permission.INTERNET in info.requestedPermissions.orEmpty())
    }

    /** Flutter's defaults: url "", autoPlay false, looping false, showControls true, playerId the node's id. */
    @Test
    fun c17_2_withNoPropsItOpensAnEmptyUrlAndRegistersUnderTheNodeIdOnlyOnceReady() {
        show(node())
        assertEquals(listOf("open "), playback.calls)
        compose.onNodeWithTag(LOADING_TAG).assertIsDisplayed().assertWidthIsEqualTo(32.dp).assertHeightIsEqualTo(32.dp)
        assertTrue(plugin.players.isEmpty(), "not registered before it is ready")
        run("playVideo", "playerId" to "video")
        assertEquals(listOf("open "), playback.calls, "an action finds no player before it is ready")

        playback.prepared()
        compose.waitForIdle()
        assertEquals(setOf("video"), plugin.players.keys)
        // video_player applies looping, volume and play/pause once initialized; no autoPlay.
        assertEquals(listOf("open ", "looping false", "volume 1.0", "pause"), playback.calls)
        compose.onNodeWithTag(LOADING_TAG).assertDoesNotExist()
        compose.onNodeWithTag(VIDEO_TAG).assertIsDisplayed()
        playButton().assertIsDisplayed().assertWidthIsEqualTo(56.dp).assertHeightIsEqualTo(56.dp)
        compose.onNodeWithText("▶").assertIsDisplayed()
        assertEquals(emptyList(), fired)
    }

    @Test
    fun c17_2_autoPlayLoopingShowControlsAndPlayerIdAreRead() {
        show(
            node(
                url(CLIP),
                "autoPlay" to JsonValue.Bool(true),
                "looping" to JsonValue.Bool(true),
                "showControls" to JsonValue.Bool(false),
                "playerId" to JsonValue.String("demo"),
            ),
        )
        assertTrue(plugin.players.isEmpty())
        playback.prepared()
        compose.waitForIdle()

        assertEquals(setOf("demo"), plugin.players.keys)
        assertEquals(listOf("open $CLIP", "looping true", "volume 1.0", "pause", "play", "speed 1.0"), playback.calls)
        assertEquals(listOf(progress(0)), fired, "autoPlay fires no onPlay")

        // No controls: no overlay, and a tap toggles nothing.
        run("pauseVideo", "playerId" to "demo")
        compose.waitForIdle()
        playButton().assertDoesNotExist()
        compose.onNodeWithTag(VIDEO_TAG).performClick()
        compose.waitForIdle()
        assertEquals("pause", playback.calls.last())
        assertEquals(listOf(progress(0)), fired)
    }

    @Test
    fun c17_2_theVideoTakesAspectRatioOrTheVideosOwn() {
        ready()
        compose.onNodeWithTag(VIDEO_TAG).assertWidthIsEqualTo(320.dp).assertHeightIsEqualTo(180.dp)

        // MediaPlayer's onVideoSizeChanged.
        assertNotNull(playback.events).resized(640, 480)
        compose.waitForIdle()
        compose.onNodeWithTag(VIDEO_TAG).assertWidthIsEqualTo(320.dp).assertHeightIsEqualTo(240.dp)

        reshow(node(url(CLIP), "aspectRatio" to JsonValue.Double(2.0)))
        compose.onNodeWithTag(VIDEO_TAG).assertWidthIsEqualTo(320.dp).assertHeightIsEqualTo(160.dp)
        reshow(node(url(CLIP), "aspectRatio" to JsonValue.Int(1)))
        compose.onNodeWithTag(VIDEO_TAG).assertWidthIsEqualTo(320.dp).assertHeightIsEqualTo(320.dp)
        // Compose cannot draw a ratio that is not positive (Flutter asserts): the video's own.
        reshow(node(url(CLIP), "aspectRatio" to JsonValue.Int(0)))
        compose.onNodeWithTag(VIDEO_TAG).assertWidthIsEqualTo(320.dp).assertHeightIsEqualTo(240.dp)
        assertEquals(1, playbacks.size, "the same url keeps its player")

        // video_player's aspectRatio: 1 until the size is known.
        assertEquals(1f, VideoValue(isInitialized = true).aspectRatio)
        assertEquals(1f, VideoValue(width = 1920, height = 1080).aspectRatio)
        assertEquals(16f / 9, VideoValue(width = 1920, height = 1080, isInitialized = true).aspectRatio)
    }

    @Test
    fun c17_2_playAndPauseActionsPlayAndPauseWithoutFiringOnPlayOrOnPause() {
        ready()
        run("playVideo", "playerId" to "video")
        compose.waitForIdle()
        playButton().assertDoesNotExist()

        run("pauseVideo", "playerId" to "video")
        compose.waitForIdle()
        playButton().assertIsDisplayed()

        assertEquals(listOf("play", "speed 1.0", "pause"), playback.afterReady())
        assertEquals(listOf(progress(0)), fired, "the actions fire no onPlay or onPause")
    }

    @Test
    fun c17_2_theOverlayTapTogglesPlaybackAndFiresOnPlayAndOnPause() {
        ready()
        compose.onNodeWithTag(VIDEO_TAG).performClick()
        compose.waitForIdle()
        playButton().assertDoesNotExist()
        assertEquals(listOf(progress(0), trigger("onPlay")), fired)

        playback.positionMs = 1_200
        advance(100)
        compose.onNodeWithTag(VIDEO_TAG).performClick()
        compose.waitForIdle()
        playButton().assertIsDisplayed()
        assertEquals(listOf(progress(0), trigger("onPlay"), progress(1_200), trigger("onPause")), fired)
        assertEquals(listOf("play", "speed 1.0", "pause"), playback.afterReady())
    }

    @Test
    fun c17_2_onProgressFiresEvery100msWhilePlayingWithAKnownDuration() {
        ready()
        run("playVideo", "playerId" to "video")
        playback.positionMs = 500
        advance(99)
        assertEquals(listOf(progress(0)), fired)
        advance(1)
        assertEquals(listOf(progress(0), progress(500)), fired)

        // A ValueNotifier: no change, no update.
        advance(100)
        assertEquals(listOf(progress(0), progress(500)), fired)
        playback.positionMs = 600
        advance(100)
        assertEquals(listOf(progress(0), progress(500), progress(600)), fired)

        // Every update while playing, a volume change too, as Flutter's listener runs on each.
        run("setVolume", "playerId" to "video", "volume" to 0.5)
        assertEquals(listOf(progress(0), progress(500), progress(600), progress(600)), fired)

        run("pauseVideo", "playerId" to "video")
        playback.positionMs = 900
        advance(1_000)
        assertEquals(4, fired.size, "no ticks while paused")

        // An unknown duration (MediaPlayer's -1, a live stream): no onProgress. video_player's play seeks to 0
        // first, as the position (0) is the duration (0).
        reshow(node(url(OTHER)))
        playback.prepared(durationMs = 0)
        run("playVideo", "playerId" to "video")
        playback.positionMs = 500
        advance(300)
        assertEquals(4, fired.size)
        assertEquals(listOf("seek 0", "play", "speed 1.0"), playback.afterReady())
    }

    @Test
    fun c17_2_seekClampsToZeroAndTheDurationAndTruncatesToWholeMs() {
        ready()
        run("seekVideo", "playerId" to "video", "position" to -5)
        run("seekVideo", "playerId" to "video", "position" to 1_500.9)
        assertEquals(emptyList(), fired, "paused: no onProgress")
        run("seekVideo", "playerId" to "video", "position" to 20_000)
        assertEquals(listOf(trigger("onComplete")), fired, "at the end, even paused")

        // A missing position or playerId does nothing; a position that is not a number fails, as Dart's `as num?`.
        run("seekVideo", "playerId" to "video")
        run("seekVideo", "position" to 100)
        assertFailsWith<IllegalArgumentException> { run("seekVideo", "playerId" to "video", "position" to "later") }

        assertEquals(listOf("seek 0", "seek 1500", "seek 10000"), playback.afterReady())

        // While playing, a seek is an update.
        run("seekVideo", "playerId" to "video", "position" to 4_000)
        run("playVideo", "playerId" to "video")
        run("seekVideo", "playerId" to "video", "position" to 7_000)
        assertEquals(listOf(trigger("onComplete"), progress(4_000), progress(7_000)), fired)
    }

    @Test
    fun c17_2_theEndPausesOnTheLastFrameFiresOnCompleteOnceAndPlayStartsOver() {
        ready()
        run("playVideo", "playerId" to "video")
        playback.positionMs = 9_900
        advance(100)

        // MediaPlayer's completion: video_player pauses, then seeks to the duration (the last frame).
        playback.completed(atMs = 9_960)
        compose.waitForIdle()
        assertEquals(listOf("play", "speed 1.0", "pause", "seek 10000"), playback.afterReady())
        assertEquals(listOf(progress(0), progress(9_900), trigger("onComplete")), fired)
        playButton().assertIsDisplayed()
        advance(1_000)
        assertEquals(3, fired.size, "no ticks after the end")

        // Still at the end: no second onComplete.
        run("seekVideo", "playerId" to "video", "position" to 10_000)
        assertEquals(3, fired.size)

        // Play at the end starts over from 0, and the end can complete again.
        run("playVideo", "playerId" to "video")
        assertEquals(listOf("seek 10000", "seek 0", "play", "speed 1.0"), playback.afterReady().drop(4))
        assertEquals(progress(0), fired.last())
        playback.positionMs = 10_000
        advance(100)
        assertEquals(listOf(progress(10_000), trigger("onComplete")), fired.takeLast(2))
        playback.completed(atMs = 10_000)
        assertEquals(6, fired.size, "onComplete once per end")
        assertEquals(listOf("pause", "seek 10000"), playback.calls.takeLast(2))

        // Seeking back re-arms it.
        run("seekVideo", "playerId" to "video", "position" to 2_000)
        run("seekVideo", "playerId" to "video", "position" to 10_000)
        assertEquals(listOf(trigger("onComplete"), trigger("onComplete")), fired.filter { it.first == "onComplete" }.drop(1))
    }

    @Test
    fun c17_2_loopingLoopsWithoutOnComplete() {
        ready("looping" to JsonValue.Bool(true))
        assertEquals(listOf("open $CLIP", "looping true", "volume 1.0", "pause"), playback.calls)
        run("playVideo", "playerId" to "video")
        playback.positionMs = 9_950
        advance(100)
        // MediaPlayer with isLooping goes back to the start and reports no completion.
        playback.positionMs = 50
        advance(100)

        assertEquals(listOf(progress(0), progress(9_950), progress(50)), fired)
        assertEquals(listOf("play", "speed 1.0"), playback.afterReady())
    }

    @Test
    fun c17_2_setVolumeClampsToZeroToOne() {
        ready()
        run("setVolume", "playerId" to "video", "volume" to 0.5)
        run("setVolume", "playerId" to "video", "volume" to 2)
        run("setVolume", "playerId" to "video", "volume" to -1.5)
        run("setVolume", "playerId" to "video")
        assertFailsWith<IllegalArgumentException> { run("setVolume", "playerId" to "video", "volume" to true) }
        assertEquals(listOf("volume 0.5", "volume 1.0", "volume 0.0"), playback.afterReady())
        assertEquals(emptyList(), fired)
    }

    /** video_player applies the speed while playing only, and throws for 0 or less (the action fails). */
    @Test
    fun c17_2_setPlaybackSpeedAppliesWhilePlayingAndZeroOrLessFails() {
        ready()
        run("setPlaybackSpeed", "playerId" to "video", "speed" to 1.5)
        assertEquals(emptyList(), playback.afterReady(), "paused: kept for the next play")
        run("playVideo", "playerId" to "video")
        run("setPlaybackSpeed", "playerId" to "video", "speed" to 2)

        val zero = assertFailsWith<IllegalArgumentException> { run("setPlaybackSpeed", "playerId" to "video", "speed" to 0) }
        assertEquals("Zero playback speed is generally unsupported. Consider using [pause].", zero.message)
        val negative = assertFailsWith<IllegalArgumentException> {
            run("setPlaybackSpeed", "playerId" to "video", "speed" to -1)
        }
        assertEquals("Negative playback speeds are generally unsupported.", negative.message)
        run("setPlaybackSpeed", "playerId" to "video")

        assertEquals(listOf("play", "speed 1.5", "speed 2.0"), playback.afterReady())
    }

    @Test
    fun c17_2_anUnknownOrMissingPlayerIdDoesNothing() {
        ready()
        for (name in FIVE) {
            run(name, "playerId" to "nobody", "position" to 100, "volume" to 0.5, "speed" to 0)
            run(name, "position" to 100, "volume" to 0.5, "speed" to 0)
            run(name, "playerId" to "", "position" to 100, "volume" to 0.5, "speed" to 0)
        }
        assertEquals(emptyList(), playback.afterReady())
        assertEquals(emptyList(), fired)
    }

    /** Flutter resolves playerId with `resolveString` and the numbers with `resolveValue`. */
    @Test
    fun c17_2_playerIdAndTheNumbersAreResolvedAsFlutterResolvesThem() {
        ready("playerId" to JsonValue.String("demo"))
        run("playVideo", "playerId" to pageState("pid"))
        run("seekVideo", "playerId" to pageState("pid"), "position" to pageState("to"))
        run("setVolume", "playerId" to pageState("pid"), "volume" to pageState("vol"))
        run("setPlaybackSpeed", "playerId" to pageState("pid"), "speed" to pageState("rate"))
        run("pauseVideo", "playerId" to pageState("pid"))
        assertEquals(listOf("play", "speed 1.0", "seek 2500", "volume 0.25", "speed 1.5", "pause"), playback.afterReady())

        // A number playerId is its Dart text.
        reshow(node(url(CLIP), "playerId" to JsonValue.String("7")))
        playback.prepared()
        run("playVideo", "playerId" to 7)
        assertEquals(listOf("play", "speed 1.0"), playback.afterReady())
    }

    @Test
    fun c17_2_aVideoThatCannotLoadFiresOnErrorWithItsMessageAndSaysSo() {
        show(node(url(CLIP)))
        playback.failed("Video player had error what=1 extra=-1004")
        compose.waitForIdle()
        assertEquals(listOf("onError" to mapOf<String, JsonValue>("message" to JsonValue.String("Video player had error what=1 extra=-1004"))), fired)
        compose.onNodeWithText("Video failed to load").assertIsDisplayed()
        compose.onNodeWithTag(LOADING_TAG).assertDoesNotExist()
        assertTrue(plugin.players.isEmpty())
        run("playVideo", "playerId" to "video")
        assertEquals(listOf("open $CLIP"), playback.calls)

        // After it is ready, video_player's controller turns erroneous: playing stops, onError is not fired (it is
        // the initialize future's), and the player does nothing more.
        reshow(node(url(OTHER)))
        compose.onNodeWithTag(LOADING_TAG).assertIsDisplayed()
        playback.prepared()
        run("playVideo", "playerId" to "video")
        playback.failed("Video player had error what=100 extra=0")
        compose.waitForIdle()
        playButton().assertIsDisplayed()
        compose.onNodeWithText("Video failed to load").assertDoesNotExist()
        playback.positionMs = 700
        advance(1_000)
        run("playVideo", "playerId" to "video")
        run("seekVideo", "playerId" to "video", "position" to 100)
        assertEquals(listOf("play", "speed 1.0"), playback.afterReady())
        assertEquals(2, fired.size)
        assertEquals(progress(0), fired.last())
    }

    @Test
    fun c17_2_aNewUrlBuildsANewPlayerAndLeavingUnregistersIt() {
        val first = ready()
        val registered = assertNotNull(plugin.players["video"])

        reshow(node(url(OTHER)))
        assertEquals("release", first.calls.last())
        assertNull(first.events, "the old player tells nothing more")
        assertTrue(plugin.players.isEmpty(), "unregistered with the old url")
        val second = playback
        assertNotSame(first, second)
        assertEquals(listOf("open $OTHER"), second.calls)
        compose.onNodeWithTag(LOADING_TAG).assertIsDisplayed()

        second.prepared()
        compose.waitForIdle()
        assertNotSame(registered, plugin.players["video"])
        run("playVideo", "playerId" to "video")
        assertEquals("play", second.calls[4])
        assertEquals("release", first.calls.last())

        // Other props keep the player, as Flutter's didUpdateWidget does.
        reshow(node(url(OTHER), "autoPlay" to JsonValue.Bool(true), "looping" to JsonValue.Bool(true)))
        assertEquals(2, playbacks.size)

        reshow(null)
        assertEquals("release", second.calls.last())
        assertTrue(plugin.players.isEmpty(), "unregistered when the view leaves")

        // A view that leaves before it is ready never registers.
        reshow(node(url(CLIP)))
        val third = playback
        val events = assertNotNull(third.events)
        reshow(null)
        events.prepared(10_000, 1920, 1080)
        assertTrue(plugin.players.isEmpty())
        assertEquals(listOf("open $CLIP", "release"), third.calls)
    }

    @Test
    fun c17_2_theTextureViewHandsItsSurfaceToThePlayer() {
        ready()
        val texture = assertNotNull(textureView(assertNotNull(root).rootView), "the video is a TextureView")
        val listener = assertNotNull(texture.surfaceTextureListener)

        listener.onSurfaceTextureAvailable(SurfaceTexture(0), 320, 180)
        assertNotNull(playback.target)
        listener.onSurfaceTextureDestroyed(SurfaceTexture(0))
        assertNull(playback.target)
    }

    private fun textureView(view: View): TextureView? {
        if (view is TextureView) return view
        if (view is ViewGroup) for (i in 0 until view.childCount) textureView(view.getChildAt(i))?.let { return it }
        return null
    }

    /** MediaPlayerPlayback on Robolectric's MediaPlayer: what a device does, with no network. */
    @Test
    fun c17_2_theMediaPlayerReportsItsDurationAndKeepsToItsStates() {
        val shadows = ArrayList<ShadowMediaPlayer>()
        ShadowMediaPlayer.setCreateListener { _, shadow ->
            shadow.invalidStateBehavior = ShadowMediaPlayer.InvalidStateBehavior.ASSERT
            shadows += shadow
        }
        ShadowMediaPlayer.addMediaInfo(DataSource.toDataSource(CLIP), ShadowMediaPlayer.MediaInfo(10_000, 0))

        val device = MediaPlayerPlayback()
        val events = RecordedEvents()
        device.events = events
        device.open(CLIP)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf("prepared 10000 0x0"), events.log)
        val shadow = shadows.single()

        // Prepared, not started: MediaPlayer's pause would be an error there.
        device.pause()
        device.setVolume(0.25)
        assertEquals(0.25f, shadow.leftVolume)
        assertEquals(0.25f, shadow.rightVolume)
        device.setLooping(true)
        device.seekTo(2_500)
        device.play()
        assertEquals(ShadowMediaPlayer.State.STARTED, shadow.state)
        device.pause()
        assertEquals(ShadowMediaPlayer.State.PAUSED, shadow.state)
        device.pause()

        device.release()
        assertEquals(ShadowMediaPlayer.State.END, shadow.state)
        // Released: nothing reaches the MediaPlayer (the view's surface may go after it).
        device.setSurface(null)
        device.play()
        device.seekTo(0)
        device.setVolume(1.0)
        device.release()
        assertEquals(listOf("prepared 10000 0x0"), events.log)

        // A source that cannot be opened fails with the exception's text.
        ShadowMediaPlayer.addException(DataSource.toDataSource(OTHER), IOException("unreachable"))
        val failing = MediaPlayerPlayback()
        val failures = RecordedEvents()
        failing.events = failures
        failing.open(OTHER)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf("failed java.io.IOException: unreachable"), failures.log)
        failing.release()
        assertEquals(2, shadows.size)
    }

    /**
     * video_player's ExoPlayer and AVPlayerLayer show the first frame once the
     * video is ready; MediaPlayer on a TextureView draws nothing until it
     * starts or seeks. The view's surface comes after the player is ready (the
     * TextureView is drawn then), so a surface given to a ready player that is
     * not playing asks for the frame where it is: a seek to 0 before the first
     * play, the position, the state and the events unchanged.
     */
    @Test
    fun c17_2_aSurfaceGivenToTheReadyPlayerShowsItsFrameBeforeAnyPlay() {
        val shadows = ArrayList<ShadowMediaPlayer>()
        val seeks = ArrayList<Int>()
        ShadowMediaPlayer.setCreateListener { player, shadow ->
            shadow.invalidStateBehavior = ShadowMediaPlayer.InvalidStateBehavior.ASSERT
            player.setOnSeekCompleteListener { seeks += it.currentPosition }
            shadows += shadow
        }
        ShadowMediaPlayer.addMediaInfo(DataSource.toDataSource(CLIP), ShadowMediaPlayer.MediaInfo(10_000, 0))
        val main = shadowOf(Looper.getMainLooper())

        val device = MediaPlayerPlayback()
        val events = RecordedEvents()
        device.events = events
        device.open(CLIP)
        device.setSurface(Surface(SurfaceTexture(0)))
        main.idle()
        assertEquals(emptyList(), seeks, "no seek before the player is ready")
        assertEquals(listOf("prepared 10000 0x0"), events.log)
        val shadow = shadows.single()

        // The TextureView's surface, once the ready view draws it: the frame at 0, not playing.
        device.setSurface(Surface(SurfaceTexture(0)))
        main.idle()
        assertEquals(listOf(0), seeks)
        assertEquals(ShadowMediaPlayer.State.PREPARED, shadow.state)
        assertEquals(0L, device.positionMs)
        assertEquals(listOf("prepared 10000 0x0"), events.log, "no event: nothing for the plugin to fire")

        // Playing draws its own frames; no surface draws none.
        device.play()
        device.setSurface(Surface(SurfaceTexture(0)))
        device.setSurface(null)
        main.idle()
        assertEquals(listOf(0), seeks)
        assertEquals(ShadowMediaPlayer.State.STARTED, shadow.state)

        // Paused: a new surface gets the frame where the player is.
        device.pause()
        device.seekTo(2_500)
        main.idle()
        device.setSurface(Surface(SurfaceTexture(0)))
        main.idle()
        assertEquals(listOf(0, 2_500, 2_500), seeks)
        assertEquals(ShadowMediaPlayer.State.PAUSED, shadow.state)
        device.release()
    }
}
