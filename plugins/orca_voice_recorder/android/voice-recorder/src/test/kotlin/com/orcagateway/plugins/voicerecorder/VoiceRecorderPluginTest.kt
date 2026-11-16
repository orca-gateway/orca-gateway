package com.orcagateway.plugins.voicerecorder

import android.Manifest
import android.content.pm.PackageManager
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.plugins.PluginMerger
import com.orcagateway.core.plugins.TriggerDefinition
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.StoreState
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.toParts
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.TestScope
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import java.io.IOException
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** A recorder that records nothing and writes down what the plugin asked of it. */
private class FakeRecorder : Recorder {
    val calls = ArrayList<String>()
    var maxAmplitude = 0
    private var path: String? = null

    override fun start(path: String) {
        calls += "start $path"
        this.path = path
    }

    /** The path started, as the record package's `stop()`; null when it was not recording. */
    override fun stop(): String? {
        calls += "stop"
        return path.also { path = null }
    }

    override fun pause() {
        calls += "pause"
    }

    override fun resume() {
        calls += "resume"
    }

    override fun maxAmplitude(): Int = maxAmplitude
}

/** A player that plays nothing: the test moves its position and ends the file. */
private class FakePlayer : Player {
    val calls = ArrayList<String>()
    var failure: Exception? = null
    override var isPlaying: Boolean = false
    override var positionMs: Long = 0
    override var durationMs: Long? = 4_200
    override var onComplete: (() -> Unit)? = null

    override fun play(path: String) {
        calls += "play $path"
        failure?.let { throw it }
        isPlaying = true
    }

    override fun stop() {
        calls += "stop"
        isPlaying = false
    }

    override fun pause() {
        calls += "pause"
        isPlaying = false
    }

    override fun resume() {
        calls += "resume"
        isPlaying = true
    }

    override fun seek(positionMs: Long) {
        calls += "seek $positionMs"
    }

    /** The file played to its end. */
    fun complete() {
        isPlaying = false
        onComplete?.invoke()
    }
}

/** The device as the plugin sees it: a recorder per recorderId, one player, the permission, the cache dir, the clock. */
private class FakeAudio : Audio {
    val recorders = ArrayList<FakeRecorder>()
    var granted = true
    var clock = 1_000L
    override val player = FakePlayer()
    override val directory = File("/cache")

    override fun recorder(): Recorder = FakeRecorder().also { recorders += it }

    override fun hasPermission(): Boolean = granted

    override fun now(): Long = clock
}

/**
 * C17.3/K: the voice recorder on Android does what Flutter's
 * plugins/orca_voice_recorder/lib/src/voice_recorder_plugin.dart does: one
 * recorder per recorderId, the nine actions with Flutter's params, defaults,
 * clamps and state writes (:224-464), the view and its two fired triggers
 * (:122-219), onRecordingComplete declared and never fired. MediaRecorder,
 * MediaPlayer, the permission, the cache directory and the clock are fakes;
 * the tickers run on a test scheduler.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VoiceRecorderPluginTest {
    @get:Rule
    val compose = createComposeRule()

    private val audio = FakeAudio()
    private val ticks = TestScope()
    private val plugin = VoiceRecorderPlugin(audio, ticks)

    private val nine = setOf(
        "startRecording", "stopRecording", "pauseRecording", "resumeRecording",
        "playRecording", "stopPlayback", "pausePlayback", "resumePlayback", "seekPlayback",
    )

    /** Let [ms] of the tickers' time pass, running what is due at the end. */
    @OptIn(ExperimentalCoroutinesApi::class)
    private fun advance(ms: Long) {
        ticks.testScheduler.advanceTimeBy(ms)
        ticks.testScheduler.runCurrent()
    }

    private fun executor(vararg page: Pair<String, JsonValue>) = ActionExecutor(ElmStore(page = mapOf(*page)))

    /** Run the action `custom:<name>` with [params] as a page does: through the executor the plugin's handlers are registered on. */
    private fun run(executor: ActionExecutor, name: String, vararg params: Pair<String, Any?>) = runBlocking {
        for ((type, handler) in plugin.actions) executor.registerHandler(type, handler)
        executor.execute(Action.Custom(JsonValue.obj("type" to "custom:$name", *params)))
    }

    private fun pageState(key: String) = JsonValue.obj("type" to "state", "key" to key, "scope" to "page")

    private fun event(key: String) = JsonValue.obj("type" to "event", "key" to key)

    private fun state(id: String) = assertNotNull(plugin.recorders[id], "recorder $id").state

    @Test
    fun c17_3_thePluginHasFluttersNameWidgetNineActionsAndThreeTriggers() {
        assertEquals("VoiceRecorderPlugin", plugin.name)
        assertEquals(setOf("VoiceRecorder"), plugin.widgets.keys)
        assertEquals(nine, plugin.actions.keys)
        assertEquals(
            mapOf(
                "VoiceRecorder" to listOf(
                    TriggerDefinition("onAmplitudeChange", "Amplitude", "Fires periodically with {amplitude, dBFS} during recording"),
                    TriggerDefinition("onStateChange", "String", "Fires with {state} when recording state changes"),
                    TriggerDefinition("onRecordingComplete", "RecordingResult", "Fires with {path, duration} when recording stops"),
                ),
            ),
            plugin.triggers,
        )

        val merged = PluginMerger.merge(builtInWidgets = WidgetRegistry.shared.types, plugins = listOf(plugin.toParts()))
        assertEquals(setOf("VoiceRecorder"), merged.pluginWidgetTypes)
        assertEquals(nine, merged.pluginActionTypes)
    }

    @Test
    fun c17_3_theModuleManifestDeclaresRecordAudio() {
        val context = RuntimeEnvironment.getApplication()
        val info = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
        assertTrue(Manifest.permission.RECORD_AUDIO in info.requestedPermissions.orEmpty())
    }

    /** The plugin a host makes from its Context: Robolectric grants no permission, and no view is there to ask. */
    @Test
    fun c17_3_withoutTheMicrophonePermissionTheDevicePluginReturnsSilently() {
        val device = VoiceRecorderPlugin(RuntimeEnvironment.getApplication())
        val executor = executor()
        for ((type, handler) in device.actions) executor.registerHandler(type, handler)
        runBlocking {
            executor.execute(Action.Custom(JsonValue.obj("type" to "custom:startRecording", "recorderId" to "memo")))
            executor.execute(
                Action.Custom(
                    JsonValue.obj("type" to "custom:stopRecording", "recorderId" to "memo", "pathKey" to "p", "durationKey" to "d"),
                ),
            )
        }
        // Flutter's order: the recorder exists before the permission check, so the stop finds it, gets no path, and
        // writes a duration of 0 (no start time).
        assertEquals(StoreState(page = mapOf("d" to JsonValue.Int(0))), executor.store.state)
    }

    @Test
    fun c17_3_startRecordingRecordsAnM4aInTheCacheDirectory() {
        audio.clock = 1_700_000_000_123
        run(executor(), "startRecording", "recorderId" to "memo", "format" to "wav")

        // `format` is ignored, as in Flutter: always AAC-LC .m4a.
        assertEquals(listOf("start /cache/orca_recording_memo_1700000000123.m4a"), audio.recorders.single().calls)
        assertEquals("recording", state("memo"))
    }

    @Test
    fun c17_3_aDeniedMicrophoneReturnsSilently() {
        audio.granted = false
        val executor = executor()

        // No VoiceRecorder on screen: no launcher to ask with.
        run(executor, "startRecording", "recorderId" to "memo")
        val recorder = audio.recorders.single()
        assertEquals(emptyList(), recorder.calls)
        assertEquals("idle", state("memo"))

        // A drawn view asks through its launcher; the user says no.
        val asked = ArrayList<String>()
        plugin.requestPermission = { permission ->
            asked += permission
            plugin.permissionAnswered(false)
        }
        run(executor, "startRecording", "recorderId" to "memo")
        assertEquals(listOf(Manifest.permission.RECORD_AUDIO), asked)
        assertEquals(emptyList(), recorder.calls)
        assertEquals("idle", state("memo"))
        assertEquals(StoreState(), executor.store.state)

        // The user says yes: it records.
        plugin.requestPermission = { permission ->
            asked += permission
            plugin.permissionAnswered(true)
        }
        run(executor, "startRecording", "recorderId" to "memo")
        assertEquals(2, asked.size)
        assertEquals(listOf("start /cache/orca_recording_memo_1000.m4a"), recorder.calls)
        assertEquals("recording", state("memo"))
    }

    @Test
    fun c17_3_stopRecordingWritesThePathAndTheWallClockDurationAsSetStateDoes() {
        val executor = executor()
        audio.clock = 1_000
        run(executor, "startRecording", "recorderId" to "memo")
        audio.clock = 3_500
        run(executor, "stopRecording", "recorderId" to "memo", "pathKey" to "voicePath", "durationKey" to "voiceDuration")

        assertEquals(listOf("start /cache/orca_recording_memo_1000.m4a", "stop"), audio.recorders.single().calls)
        assertEquals("idle", state("memo"))
        assertEquals(
            StoreState(
                page = mapOf(
                    "voicePath" to JsonValue.String("/cache/orca_recording_memo_1000.m4a"),
                    "voiceDuration" to JsonValue.Int(2_500),
                ),
            ),
            executor.store.state,
        )
        assertIs<JsonValue.Int>(executor.store.state.page["voiceDuration"], "Flutter's inMilliseconds is an int")

        // scope app writes app state.
        audio.clock = 10_000
        run(executor, "startRecording", "recorderId" to "memo")
        audio.clock = 10_250
        run(executor, "stopRecording", "recorderId" to "memo", "pathKey" to "p", "durationKey" to "d", "scope" to "app")
        assertEquals(
            mapOf("p" to JsonValue.String("/cache/orca_recording_memo_10000.m4a"), "d" to JsonValue.Int(250)),
            executor.store.state.app,
        )

        // No keys, nothing written; it still stops.
        val before = executor.store.state
        run(executor, "startRecording", "recorderId" to "memo")
        run(executor, "stopRecording", "recorderId" to "memo")
        assertEquals(before, executor.store.state)
        assertEquals("stop", audio.recorders.single().calls.last())
        assertEquals("idle", state("memo"))
    }

    @Test
    fun c17_3_pauseAndResumeRecordingMoveTheState() {
        val executor = executor()
        run(executor, "startRecording", "recorderId" to "memo")
        run(executor, "pauseRecording", "recorderId" to "memo")
        assertEquals("paused", state("memo"))
        run(executor, "resumeRecording", "recorderId" to "memo")
        assertEquals("recording", state("memo"))
        assertEquals(listOf("pause", "resume"), audio.recorders.single().calls.drop(1))
        assertEquals(StoreState(), executor.store.state)
    }

    @Test
    fun c17_3_anUnknownOrEmptyRecorderIdDoesNothing() {
        val executor = executor()
        for (name in listOf("stopRecording", "pauseRecording", "resumeRecording")) {
            run(executor, name, "recorderId" to "nobody", "pathKey" to "p", "durationKey" to "d")
        }
        run(executor, "startRecording", "recorderId" to "")
        run(executor, "startRecording")
        run(executor, "stopRecording", "durationKey" to "d")

        assertTrue(plugin.recorders.isEmpty())
        assertTrue(audio.recorders.isEmpty())
        assertEquals(StoreState(), executor.store.state)
    }

    /** Flutter resolves recorderId and path with `resolveString`, position with `resolveValue`; the demo sends `V.pageState`. */
    @Test
    fun c17_3_recorderIdPathAndPositionAreResolvedAsFlutterResolvesThem() {
        val executor = executor(
            "rid" to JsonValue.String("memo"),
            "voicePath" to JsonValue.String("/cache/orca_recording_memo_1000.m4a"),
            "seekTo" to JsonValue.Int(900),
        )
        run(executor, "startRecording", "recorderId" to pageState("rid"))
        run(executor, "pauseRecording", "recorderId" to pageState("rid"))
        run(executor, "resumeRecording", "recorderId" to pageState("rid"))
        run(executor, "stopRecording", "recorderId" to pageState("rid"), "durationKey" to "ms")
        assertEquals(setOf("memo"), plugin.recorders.keys)
        assertEquals(
            listOf("start /cache/orca_recording_memo_1000.m4a", "pause", "resume", "stop"),
            audio.recorders.single().calls,
        )
        assertEquals(JsonValue.Int(0), executor.store.state.page["ms"])

        run(executor, "playRecording", "path" to pageState("voicePath"))
        run(executor, "seekPlayback", "position" to pageState("seekTo"))
        assertEquals(listOf("play /cache/orca_recording_memo_1000.m4a", "seek 900"), audio.player.calls)

        // A number recorderId is its Dart text.
        run(executor, "startRecording", "recorderId" to 7)
        assertEquals(setOf("memo", "7"), plugin.recorders.keys)
    }

    @Test
    fun c17_3_theAmplitudeIsDbfsEvery200msWhileRecording() {
        run(executor(), "startRecording", "recorderId" to "memo")
        val recorder = audio.recorders.single()
        val instance = assertNotNull(plugin.recorders["memo"])

        recorder.maxAmplitude = 32_767
        advance(199)
        assertEquals(-60.0, instance.amplitude, "Flutter's starting value until the first tick")
        advance(1)
        assertEquals(0.0, instance.amplitude)

        recorder.maxAmplitude = 16_384
        advance(200)
        assertEquals(-6.0203, instance.amplitude, 1e-4)

        recorder.maxAmplitude = 0
        advance(200)
        assertEquals(-160.0, instance.amplitude, "silence is the record package's floor, not -infinity")

        run(executor(), "stopRecording", "recorderId" to "memo")
        recorder.maxAmplitude = 32_767
        advance(1_000)
        assertEquals(-160.0, instance.amplitude, "no tick after stop")
    }

    @Test
    fun c17_3_playRecordingWritesDurationAndPlayingThenThePositionEvery200msAndResetsOnComplete() {
        val executor = executor()
        run(
            executor, "playRecording",
            "path" to "/cache/a.m4a", "positionKey" to "pos", "durationKey" to "len", "stateKey" to "playback",
        )
        assertEquals(listOf("play /cache/a.m4a"), audio.player.calls)
        assertEquals(mapOf("len" to JsonValue.Int(4_200), "playback" to JsonValue.String("playing")), executor.store.state.page)
        assertIs<JsonValue.Int>(executor.store.state.page["len"])

        audio.player.positionMs = 600
        advance(199)
        assertNull(executor.store.state.page["pos"])
        advance(1)
        assertEquals(JsonValue.Int(600), executor.store.state.page["pos"])
        audio.player.positionMs = 800
        advance(200)
        assertEquals(JsonValue.Int(800), executor.store.state.page["pos"])

        audio.player.complete()
        advance(0)
        assertEquals(JsonValue.Int(0), executor.store.state.page["pos"])
        assertEquals(JsonValue.String("stopped"), executor.store.state.page["playback"])
        audio.player.positionMs = 900
        advance(1_000)
        assertEquals(JsonValue.Int(0), executor.store.state.page["pos"], "no position after the end")

        // scope app; without keys nothing is written.
        run(executor, "playRecording", "path" to "/cache/b.m4a", "stateKey" to "s", "scope" to "app")
        assertEquals(mapOf("s" to JsonValue.String("playing")), executor.store.state.app)
        val before = executor.store.state
        run(executor, "playRecording", "path" to "/cache/c.m4a")
        audio.player.complete()
        advance(1_000)
        assertEquals(before, executor.store.state)
        assertEquals(listOf("play /cache/a.m4a", "play /cache/b.m4a", "play /cache/c.m4a"), audio.player.calls)
    }

    @Test
    fun c17_3_aPlaybackThatFailsWritesErrorAndAnEmptyPathPlaysNothing() {
        val executor = executor()
        audio.player.failure = IOException("no such file")
        run(executor, "playRecording", "path" to "/cache/gone.m4a", "positionKey" to "pos", "stateKey" to "playback")
        assertEquals(mapOf("playback" to JsonValue.String("error")), executor.store.state.page)
        audio.player.positionMs = 300
        advance(1_000)
        assertNull(executor.store.state.page["pos"], "the position ticks stop with the failure")

        run(executor, "playRecording", "path" to "", "stateKey" to "playback")
        run(executor, "playRecording", "stateKey" to "playback")
        assertEquals(listOf("play /cache/gone.m4a"), audio.player.calls)
        assertEquals(mapOf("playback" to JsonValue.String("error")), executor.store.state.page)
    }

    @Test
    fun c17_3_stopPauseAndResumePlaybackWriteTheirStates() {
        val executor = executor()
        run(executor, "playRecording", "path" to "/cache/a.m4a", "positionKey" to "pos", "stateKey" to "playback")
        audio.player.positionMs = 700
        advance(200)

        run(executor, "pausePlayback", "stateKey" to "playback")
        assertEquals(JsonValue.String("paused"), executor.store.state.page["playback"])
        run(executor, "resumePlayback", "stateKey" to "playback")
        assertEquals(JsonValue.String("playing"), executor.store.state.page["playback"])
        run(executor, "stopPlayback", "positionKey" to "pos", "stateKey" to "playback")
        assertEquals(
            mapOf("pos" to JsonValue.Int(0), "playback" to JsonValue.String("stopped")),
            executor.store.state.page,
        )
        audio.player.positionMs = 900
        audio.player.isPlaying = true
        advance(1_000)
        assertEquals(JsonValue.Int(0), executor.store.state.page["pos"], "stop ends the position ticks")
        assertEquals(listOf("play /cache/a.m4a", "pause", "resume", "stop"), audio.player.calls)

        // scope app; absent and empty keys write nothing.
        run(executor, "pausePlayback", "stateKey" to "s", "scope" to "app")
        assertEquals(mapOf("s" to JsonValue.String("paused")), executor.store.state.app)
        val before = executor.store.state
        run(executor, "stopPlayback", "positionKey" to "", "stateKey" to "")
        run(executor, "pausePlayback")
        run(executor, "resumePlayback", "stateKey" to "")
        assertEquals(before, executor.store.state)
        assertEquals(listOf("stop", "pause", "resume"), audio.player.calls.takeLast(3))
    }

    @Test
    fun c17_3_seekPlaybackTruncatesAndClampsToZero() {
        val executor = executor()
        run(executor, "seekPlayback", "position" to 1_500.9)
        run(executor, "seekPlayback", "position" to -250)
        run(executor, "seekPlayback")
        run(executor, "seekPlayback", "position" to "later")
        assertEquals(listOf("seek 1500", "seek 0", "seek 0", "seek 0"), audio.player.calls)
        assertEquals(StoreState(), executor.store.state)
    }

    @Test
    fun c17_3_theDotAndTheBarUseFluttersColoursAndClamp() {
        assertEquals(Color(0xFFFF0000), dotColor("recording"))
        assertEquals(Color(0xFFFF9800), dotColor("paused"))
        assertEquals(Color(0xFF9E9E9E), dotColor("idle"))

        assertEquals(0f, amplitudeFraction(-160.0))
        assertEquals(0f, amplitudeFraction(-60.0))
        assertEquals(0.5f, amplitudeFraction(-30.0))
        assertEquals(1f, amplitudeFraction(0.0))
        assertEquals(1f, amplitudeFraction(12.0))
    }

    /** A page whose one node is a VoiceRecorder with [props], its two triggers writing their event data to page state. */
    private fun voiceModel(vararg props: Pair<String, JsonValue>): OrcaPageModel {
        val node = ComponentNode(
            "voice", "VoiceRecorder", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
            props = mapOf(*props),
            actions = mapOf(
                "onStateChange" to Action.SetState(key = "recState", value = event("state")),
                "onAmplitudeChange" to Action.SetState(key = "recAmp", value = event("amplitude")),
                "onRecordingComplete" to Action.SetState(key = "completed", value = JsonValue.Bool(true)),
            ),
        )
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "VoiceRecorder")
        return OrcaPageModel(PageResponse(pageId = "p", title = "P", components = listOf(node)), registry = registry)
    }

    private fun show(model: OrcaPageModel) {
        val node = assertNotNull(model.resolve("voice"))
        assertEquals("VoiceRecorder", node.type, "the plugin node is not degraded")
        val builder = plugin.widgets.getValue("VoiceRecorder")
        compose.setContent { builder(node, model, Modifier) }
        compose.waitForIdle()
    }

    @Test
    fun c17_3_theViewRegistersItsRecorderUnderTheNodeIdAndShowsFluttersLabelsAndBar() {
        val model = voiceModel()
        show(model)
        assertEquals(setOf("voice"), plugin.recorders.keys, "recorderId defaults to the node's id")
        assertNotNull(plugin.requestPermission, "the view registers its permission launcher")
        compose.onNodeWithText("Ready").assertIsDisplayed()
        compose.onNodeWithTag(AMPLITUDE_BAR_TAG).assertDoesNotExist()

        run(model.executor, "startRecording", "recorderId" to "voice")
        compose.waitForIdle()
        compose.onNodeWithText("Recording").assertIsDisplayed()
        compose.onNodeWithTag(AMPLITUDE_BAR_TAG).assertIsDisplayed()

        run(model.executor, "pauseRecording", "recorderId" to "voice")
        compose.waitForIdle()
        compose.onNodeWithText("Paused").assertIsDisplayed()
        compose.onNodeWithTag(AMPLITUDE_BAR_TAG).assertDoesNotExist()
    }

    @Test
    fun c17_3_showAmplitudeFalseHidesTheBarAndRecorderIdNamesTheRecorder() {
        val model = voiceModel("recorderId" to JsonValue.String("memo"), "showAmplitude" to JsonValue.Bool(false))
        show(model)
        assertEquals(setOf("memo"), plugin.recorders.keys)

        run(model.executor, "startRecording", "recorderId" to "memo")
        compose.waitForIdle()
        compose.onNodeWithText("Recording").assertIsDisplayed()
        compose.onNodeWithTag(AMPLITUDE_BAR_TAG).assertDoesNotExist()
    }

    @Test
    fun c17_3_theViewFiresOnStateChangeAndOnAmplitudeChangeWithFluttersPayloads() {
        val model = voiceModel()
        show(model)

        run(model.executor, "startRecording", "recorderId" to "voice")
        assertEquals(JsonValue.String("recording"), model.store.value("recState"))

        audio.recorders.single().maxAmplitude = 32_767
        advance(200)
        assertEquals(JsonValue.Double(0.0), model.store.value("recAmp"))

        run(model.executor, "pauseRecording", "recorderId" to "voice")
        assertEquals(JsonValue.String("paused"), model.store.value("recState"))
        run(model.executor, "stopRecording", "recorderId" to "voice", "pathKey" to "voicePath")
        assertEquals(JsonValue.String("idle"), model.store.value("recState"))
        assertEquals(JsonValue.String("/cache/orca_recording_voice_1000.m4a"), model.store.value("voicePath"))

        // Declared, never fired, as in Flutter.
        assertEquals(JsonValue.Null, model.store.value("completed"))
    }
}
