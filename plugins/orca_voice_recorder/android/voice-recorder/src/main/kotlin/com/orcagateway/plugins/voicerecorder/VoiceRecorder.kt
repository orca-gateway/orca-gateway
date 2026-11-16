package com.orcagateway.plugins.voicerecorder

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Job
import java.io.File

/**
 * What the plugin asks of a recorder (Flutter's `AudioRecorder` of the record
 * package): MediaRecorder on a device, a fake in the tests.
 */
internal interface Recorder {
    /** Records AAC-LC into the .m4a file at [path], stopping what it recorded before. */
    fun start(path: String)

    /** Ends the recording: the file's path, or null when it was not recording. */
    fun stop(): String?

    fun pause()

    fun resume()

    /** The loudest sample since the last call, 0 to 32767 (MediaRecorder's `getMaxAmplitude`). */
    fun maxAmplitude(): Int
}

/**
 * What the plugin asks of the one player all recorders share (Flutter's
 * `AudioPlayer` of audioplayers): MediaPlayer on a device, a fake in the tests.
 */
internal interface Player {
    val isPlaying: Boolean

    /** Where the file is, in ms. */
    val positionMs: Long

    /** How long the file is, in ms, once known. */
    val durationMs: Long?

    /** Called when the file plays to its end. */
    var onComplete: (() -> Unit)?

    /** Plays the file at [path] from its start, in place of what played; throws when it cannot. */
    fun play(path: String)

    fun stop()

    fun pause()

    fun resume()

    fun seek(positionMs: Long)
}

/** The device as the plugin sees it. */
internal interface Audio {
    /** A new recorder, one per recorderId. */
    fun recorder(): Recorder

    val player: Player

    /** True when the app holds RECORD_AUDIO. */
    fun hasPermission(): Boolean

    /** Where recordings go: Flutter's `getTemporaryDirectory()`, the cache directory on Android. */
    val directory: File

    /** Wall-clock milliseconds. */
    fun now(): Long
}

/**
 * One recorder and what its views draw (Flutter's `_RecorderInstance`): the
 * state (idle, recording or paused) and the last amplitude in dBFS. A view
 * fires its triggers from the listeners, which run on a change only, as a
 * Flutter `ValueNotifier` notifies.
 */
internal class RecorderInstance(val recorder: Recorder) {
    private var stateValue by mutableStateOf("idle")
    private var amplitudeValue by mutableDoubleStateOf(-60.0)

    val stateListeners: MutableList<(String) -> Unit> = ArrayList()
    val amplitudeListeners: MutableList<(Double) -> Unit> = ArrayList()

    /** When the recording started, for the duration stopRecording writes. */
    var startTime: Long? = null

    /** The 200 ms amplitude ticks while recording. */
    var amplitudeTicks: Job? = null

    var state: String
        get() = stateValue
        set(value) {
            if (value == stateValue) return
            stateValue = value
            for (listener in stateListeners.toList()) listener(value)
        }

    var amplitude: Double
        get() = amplitudeValue
        set(value) {
            if (value == amplitudeValue) return
            amplitudeValue = value
            for (listener in amplitudeListeners.toList()) listener(value)
        }
}

/** The Android device: MediaRecorder, MediaPlayer, the app's permission, cache directory and clock. */
internal class DeviceAudio(private val context: Context) : Audio {
    override val player: Player = DevicePlayer()

    override fun recorder(): Recorder = DeviceRecorder(context)

    override fun hasPermission(): Boolean =
        context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    override val directory: File get() = context.cacheDir

    override fun now(): Long = System.currentTimeMillis()
}

/**
 * MediaRecorder as the record package's `RecordConfig(encoder: aacLc)`
 * records: MPEG-4 holding AAC, 44.1 kHz, 128 kbit/s, two channels (its
 * defaults). A MediaRecorder records once, so each start makes a new one.
 */
private class DeviceRecorder(private val context: Context) : Recorder {
    private var recorder: MediaRecorder? = null
    private var path: String? = null

    override fun start(path: String) {
        stop()
        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        try {
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioSamplingRate(44_100)
            recorder.setAudioEncodingBitRate(128_000)
            recorder.setAudioChannels(2)
            recorder.setOutputFile(path)
            recorder.prepare()
            recorder.start()
        } catch (e: Exception) {
            recorder.release()
            throw e
        }
        this.recorder = recorder
        this.path = path
    }

    override fun stop(): String? {
        val recorder = recorder ?: return null
        val path = path
        this.recorder = null
        this.path = null
        return try {
            recorder.stop()
            path
        } catch (e: RuntimeException) {
            // Stopped before any audio arrived: MediaRecorder leaves no usable file.
            path?.let { File(it).delete() }
            null
        } finally {
            recorder.release()
        }
    }

    override fun pause() {
        recorder?.pause()
    }

    override fun resume() {
        recorder?.resume()
    }

    override fun maxAmplitude(): Int = recorder?.maxAmplitude ?: 0
}

/** MediaPlayer for a local file, released when stopped or replaced (audioplayers' release mode). */
private class DevicePlayer : Player {
    private var player: MediaPlayer? = null

    override var onComplete: (() -> Unit)? = null

    override val isPlaying: Boolean get() = player?.isPlaying == true

    override val positionMs: Long get() = player?.currentPosition?.toLong() ?: 0

    override val durationMs: Long? get() = player?.duration?.takeIf { it >= 0 }?.toLong()

    override fun play(path: String) {
        stop()
        val player = MediaPlayer()
        try {
            player.setDataSource(path)
            player.prepare()
        } catch (e: Exception) {
            player.release()
            throw e
        }
        player.setOnCompletionListener { onComplete?.invoke() }
        player.start()
        this.player = player
    }

    override fun stop() {
        val player = player ?: return
        this.player = null
        player.release()
    }

    override fun pause() {
        player?.takeIf { it.isPlaying }?.pause()
    }

    override fun resume() {
        player?.start()
    }

    override fun seek(positionMs: Long) {
        player?.seekTo(positionMs.coerceAtMost(Int.MAX_VALUE.toLong()).toInt())
    }
}
