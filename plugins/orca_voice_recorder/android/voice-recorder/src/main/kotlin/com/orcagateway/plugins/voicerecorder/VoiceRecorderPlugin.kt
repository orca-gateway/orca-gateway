package com.orcagateway.plugins.voicerecorder

import android.Manifest
import android.content.Context
import android.util.Log
import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.plugins.TriggerDefinition
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.sdk.OrcaPlugin
import com.orcagateway.sdk.WidgetBuilder
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import java.io.File
import kotlin.math.log10

private const val TAG = "OrcaVoiceRecorder"

/** How often the amplitude is read while recording, and the position while playing. */
private const val TICK_MS = 200L

/** The dBFS of a silent sample (MediaRecorder's 0): the record package's floor. */
private const val SILENCE_DBFS = -160.0

/**
 * Voice recording and playback for Orca pages: Flutter's
 * `VoiceRecorderPlugin` (plugins/orca_voice_recorder/lib/src/voice_recorder_plugin.dart)
 * one to one. The `VoiceRecorder` widget draws a recorder's state and fires
 * `onStateChange` {state} and `onAmplitudeChange` {amplitude}; the nine
 * actions record, play back and write their results to page or app state.
 * `onRecordingComplete` is declared and never fired, as in Flutter: a page
 * gets the recording's path and duration from stopRecording's `pathKey` and
 * `durationKey`.
 *
 * Recordings are AAC-LC .m4a files in the app's cache directory. The app
 * holds RECORD_AUDIO (this module's manifest), and a drawn VoiceRecorder asks
 * the user for it before the first recording; a refusal stops the start
 * silently. Make one plugin per app; its actions run on the main thread.
 */
public class VoiceRecorderPlugin internal constructor(
    private val audio: Audio,
    /** Where the amplitude and position ticks run. */
    private val scope: CoroutineScope,
) : OrcaPlugin {
    /** Records with [context]'s microphone into its cache directory and plays back with MediaPlayer. */
    public constructor(context: Context) :
        this(DeviceAudio(context.applicationContext), CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate))

    override val name: String = "VoiceRecorderPlugin"

    override val widgets: Map<String, WidgetBuilder> = mapOf("VoiceRecorder" to voiceRecorderBuilder(this))

    override val actions: Map<String, OrcaActionHandler> = mapOf(
        "startRecording" to OrcaActionHandler { action, executor -> startRecording(action, executor) },
        "stopRecording" to OrcaActionHandler { action, executor -> stopRecording(action, executor) },
        "pauseRecording" to OrcaActionHandler { action, executor -> pauseRecording(action, executor) },
        "resumeRecording" to OrcaActionHandler { action, executor -> resumeRecording(action, executor) },
        "playRecording" to OrcaActionHandler { action, executor -> playRecording(action, executor) },
        "stopPlayback" to OrcaActionHandler { action, executor -> stopPlayback(action, executor) },
        "pausePlayback" to OrcaActionHandler { action, executor -> pausePlayback(action, executor) },
        "resumePlayback" to OrcaActionHandler { action, executor -> resumePlayback(action, executor) },
        "seekPlayback" to OrcaActionHandler { action, executor -> seekPlayback(action, executor) },
    )

    override val triggers: Map<String, List<TriggerDefinition>> = mapOf(
        "VoiceRecorder" to listOf(
            TriggerDefinition(
                VoiceRecorderProps.Triggers.onAmplitudeChange,
                dataType = "Amplitude",
                description = "Fires periodically with {amplitude, dBFS} during recording",
            ),
            TriggerDefinition(
                VoiceRecorderProps.Triggers.onStateChange,
                dataType = "String",
                description = "Fires with {state} when recording state changes",
            ),
            // Flutter's description; Flutter never fires it, nor does this plugin.
            TriggerDefinition(
                VoiceRecorderProps.Triggers.onRecordingComplete,
                dataType = "RecordingResult",
                description = "Fires with {path, duration} when recording stops",
            ),
        ),
    )

    /** The recorders by recorderId (Flutter's `_recorders`): a view or startRecording makes one, the others find it. */
    internal val recorders: MutableMap<String, RecorderInstance> = LinkedHashMap()

    /** Flutter's `_getOrCreate`. */
    internal fun recorder(id: String): RecorderInstance = recorders.getOrPut(id) { RecorderInstance(audio.recorder()) }

    // MARK: The microphone permission

    /** Set by a drawn VoiceRecorder: asks the user for a permission through its ActivityResult launcher. */
    internal var requestPermission: ((String) -> Unit)? = null

    private var permissionAnswer: CompletableDeferred<Boolean>? = null

    /** The user's answer to the request [requestPermission] made. */
    internal fun permissionAnswered(granted: Boolean) {
        val answer = permissionAnswer ?: return
        permissionAnswer = null
        answer.complete(granted)
    }

    /** The record package's `hasPermission()`: held, or asked for and granted. No view on screen, nobody to ask. */
    private suspend fun microphoneAllowed(): Boolean {
        if (audio.hasPermission()) return true
        permissionAnswer?.let { return it.await() }
        val request = requestPermission ?: return false
        val answer = CompletableDeferred<Boolean>()
        permissionAnswer = answer
        request(Manifest.permission.RECORD_AUDIO)
        return answer.await()
    }

    // MARK: Recording (Flutter :224-311)

    private suspend fun startRecording(action: JsonObject, executor: ActionExecutor) {
        val recorderId = executor.resolveString(action["recorderId"])
        if (recorderId.isEmpty()) return
        val instance = recorder(recorderId)
        if (!microphoneAllowed()) return

        val path = File(audio.directory, "orca_recording_${recorderId}_${audio.now()}.m4a").path
        instance.recorder.start(path)
        instance.startTime = audio.now()
        instance.state = "recording"
        startAmplitudeTicks(instance)
    }

    /** The record package's `_startAmplitudeTimer`: one loop per recorder, a running one replaced. */
    private fun startAmplitudeTicks(instance: RecorderInstance) {
        instance.amplitudeTicks?.cancel()
        instance.amplitudeTicks = scope.launch {
            while (true) {
                delay(TICK_MS)
                instance.amplitude = dbfs(instance.recorder.maxAmplitude())
            }
        }
    }

    private suspend fun stopRecording(action: JsonObject, executor: ActionExecutor) {
        val params = StopRecordingParams(action)
        val recorderId = executor.resolveString(action["recorderId"])
        if (recorderId.isEmpty()) return
        val instance = recorders[recorderId] ?: return

        val path = instance.recorder.stop()
        instance.amplitudeTicks?.cancel()
        instance.amplitudeTicks = null
        instance.state = "idle"

        val duration = instance.startTime?.let { audio.now() - it } ?: 0L
        val stateScope = params.scope ?: "page"
        val pathKey = params.pathKey
        if (pathKey != null && path != null) executor.setState(pathKey, JsonValue.String(path), stateScope)
        params.durationKey?.let { executor.setState(it, JsonValue.Int(duration), stateScope) }
    }

    private suspend fun pauseRecording(action: JsonObject, executor: ActionExecutor) {
        val recorderId = executor.resolveString(action["recorderId"])
        if (recorderId.isEmpty()) return
        val instance = recorders[recorderId] ?: return
        // The record package's pause() cancels its amplitude timer: no readings while paused.
        instance.amplitudeTicks?.cancel()
        instance.amplitudeTicks = null
        instance.recorder.pause()
        instance.state = "paused"
    }

    private suspend fun resumeRecording(action: JsonObject, executor: ActionExecutor) {
        val recorderId = executor.resolveString(action["recorderId"])
        if (recorderId.isEmpty()) return
        val instance = recorders[recorderId] ?: return
        instance.recorder.resume()
        // The record package's resume() starts the timer again; only a paused recorder has ticks to bring back.
        if (instance.state == "paused") startAmplitudeTicks(instance)
        instance.state = "recording"
    }

    // MARK: Playback (Flutter :313-464)

    /** The position ticks of the file playing now (Flutter's `_playbackSubs.position`). */
    private var positionTicks: Job? = null

    /** Flutter's `_playbackSubs.cancelAll()`: the position ticks and the completion of the last play. */
    private fun cancelPlayback() {
        positionTicks?.cancel()
        positionTicks = null
        audio.player.onComplete = null
    }

    private suspend fun playRecording(action: JsonObject, executor: ActionExecutor) {
        val path = executor.resolveString(action["path"])
        if (path.isEmpty()) {
            Log.d(TAG, "playRecording: empty path, skipping")
            return
        }
        val params = PlayRecordingParams(action)
        val positionKey = params.positionKey
        val durationKey = params.durationKey
        val stateKey = params.stateKey
        val stateScope = params.scope ?: "page"
        val player = audio.player

        cancelPlayback()
        if (positionKey != null) {
            positionTicks = scope.launch {
                while (true) {
                    delay(TICK_MS)
                    if (player.isPlaying) executor.writeState(positionKey, JsonValue.Int(player.positionMs), stateScope)
                }
            }
        }
        // The end resets the position and the state, so the page's view goes back to idle by itself.
        player.onComplete = {
            scope.launch {
                cancelPlayback()
                executor.writeState(positionKey, JsonValue.Int(0), stateScope)
                executor.writeState(stateKey, JsonValue.String("stopped"), stateScope)
            }
        }

        try {
            player.play(path)
            if (durationKey != null) player.durationMs?.let { executor.writeState(durationKey, JsonValue.Int(it), stateScope) }
            executor.writeState(stateKey, JsonValue.String("playing"), stateScope)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "play failed: $path", e)
            cancelPlayback()
            executor.writeState(stateKey, JsonValue.String("error"), stateScope)
        }
    }

    private suspend fun stopPlayback(action: JsonObject, executor: ActionExecutor) {
        audio.player.stop()
        cancelPlayback()
        val params = StopPlaybackParams(action)
        val stateScope = params.scope ?: "page"
        executor.writeState(params.positionKey, JsonValue.Int(0), stateScope)
        executor.writeState(params.stateKey, JsonValue.String("stopped"), stateScope)
    }

    private suspend fun pausePlayback(action: JsonObject, executor: ActionExecutor) {
        audio.player.pause()
        val params = PausePlaybackParams(action)
        executor.writeState(params.stateKey, JsonValue.String("paused"), params.scope ?: "page")
    }

    private suspend fun resumePlayback(action: JsonObject, executor: ActionExecutor) {
        audio.player.resume()
        val params = ResumePlaybackParams(action)
        executor.writeState(params.stateKey, JsonValue.String("playing"), params.scope ?: "page")
    }

    /** Flutter's `positionRaw is num ? positionRaw.toInt() : 0`, clamped at 0. */
    private fun seekPlayback(action: JsonObject, executor: ActionExecutor) {
        val position = JsonValue.fromJsonElement(executor.resolve(action["position"] ?: JsonNull))
        val ms = if (position.isNumber) position.dartInt ?: 0L else 0L
        audio.player.seek(if (ms < 0) 0L else ms)
    }
}

/** 20·log10(amplitude / 32767): MediaRecorder's loudest sample as dBFS, the record package's `Amplitude.current`. */
internal fun dbfs(maxAmplitude: Int): Double = if (maxAmplitude > 0) 20 * log10(maxAmplitude / 32_767.0) else SILENCE_DBFS

/** Flutter's `executor.resolveString(raw ?? '')`: the value resolved, as Dart text; '' for null. */
private fun ActionExecutor.resolveString(raw: JsonElement?): String {
    val value = JsonValue.fromJsonElement(resolve(raw ?: JsonNull))
    return if (value.isNull) "" else DartFormat.string(value)
}

/** Flutter's `executor.execute({'type': 'setState', ...})`: scope `app` writes app state, anything else page state. */
private suspend fun ActionExecutor.setState(key: String, value: JsonValue, scope: String) {
    execute(Action.SetState(key = key, scope = if (scope == "app") StateScope.App else StateScope.Page, value = value))
}

/** Flutter's `_writeState`: a setState, skipped without a key. */
private suspend fun ActionExecutor.writeState(key: String?, value: JsonValue, scope: String) {
    if (key.isNullOrEmpty()) return
    setState(key, value, scope)
}
