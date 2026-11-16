package com.orcagateway.plugins.videoplayer

import android.media.MediaPlayer
import android.media.PlaybackParams
import android.os.Build
import android.view.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** How often video_player reads the position while playing. */
private const val TICK_MS = 100L

/**
 * What the plugin asks of a platform player (video_player's platform
 * interface): MediaPlayer on a device, a fake in the tests. One plays one url.
 */
internal interface VideoPlayback {
    /** Where the player tells what happened: set before [open], cleared by [release]. */
    var events: Events?

    /** Where the video is, in ms. */
    val positionMs: Long

    /** Starts loading [url]; [Events.prepared] or [Events.failed] follows. */
    fun open(url: String)

    /** Where the frames go (the view's TextureView), or nowhere. */
    fun setSurface(surface: Surface?)

    fun play()

    fun pause()

    fun seekTo(positionMs: Long)

    /** 0 to 1. */
    fun setVolume(volume: Double)

    /** Above 0, while playing. */
    fun setSpeed(speed: Double)

    fun setLooping(looping: Boolean)

    /** Frees the player; nothing reaches it after. */
    fun release()

    interface Events {
        /** Ready to play: the duration in ms (0 when unknown, as for a live stream) and the video's size in pixels (0 when unknown). */
        fun prepared(durationMs: Long, width: Int, height: Int)

        /** The video's size became known or changed. */
        fun resized(width: Int, height: Int)

        /** Loading or playing failed. */
        fun failed(message: String)

        /** Played to its end; a looping player never does. */
        fun completed()
    }
}

/** video_player's `VideoPlayerValue`, the parts the plugin reads: a change notifies the controller's listeners. */
internal data class VideoValue(
    val durationMs: Long = 0,
    val positionMs: Long = 0,
    val width: Int = 0,
    val height: Int = 0,
    val isInitialized: Boolean = false,
    val isPlaying: Boolean = false,
    val isLooping: Boolean = false,
    val volume: Double = 1.0,
    val speed: Double = 1.0,
) {
    /** video_player's `aspectRatio`: width over height once initialized with a size, else 1. */
    val aspectRatio: Float
        get() {
            if (!isInitialized || width == 0 || height == 0) return 1f
            val ratio = width.toFloat() / height
            return if (ratio <= 0f) 1f else ratio
        }
}

/**
 * video_player's `VideoPlayerController` (2.11.1) for one url over a
 * [VideoPlayback]: its value and listeners, and the semantics the plugin
 * relies on. Nothing reaches the player before it is initialized; play at
 * the end seeks to 0 first; a seek clamps to [0, duration]; the volume
 * clamps to 0...1; a speed of 0 or less throws, and the speed is applied
 * while playing only; the position is read every 100 ms while playing; at
 * the end the player pauses and seeks to the duration (the last frame).
 * Compose state, so a view draws its value.
 */
internal class VideoController(
    private val playback: VideoPlayback,
    private val url: String,
    private val scope: CoroutineScope,
) {
    var value: VideoValue by mutableStateOf(VideoValue())
        private set

    private val listeners = ArrayList<() -> Unit>()
    private var ticks: Job? = null
    private var disposed = false

    /** What [initialize] was given, until the player is ready or fails (video_player's initializing completer). */
    private var initializing: Pair<() -> Unit, (String) -> Unit>? = null

    fun addListener(listener: () -> Unit) {
        listeners += listener
    }

    fun removeListener(listener: () -> Unit) {
        listeners -= listener
    }

    /** A ValueNotifier's set: the listeners run on a change only. */
    private fun update(next: VideoValue) {
        if (next == value) return
        value = next
        for (listener in listeners.toList()) listener()
    }

    /** Opens the url: [onReady] once it can play, or [onError] with the failure's message. */
    fun initialize(onReady: () -> Unit, onError: (String) -> Unit) {
        initializing = onReady to onError
        playback.events = events
        playback.open(url)
    }

    private val events = object : VideoPlayback.Events {
        override fun prepared(durationMs: Long, width: Int, height: Int) {
            if (disposed) return
            update(value.copy(durationMs = durationMs, width = width, height = height, isInitialized = true))
            applyLooping()
            applyVolume()
            applyPlayPause()
            val (onReady, _) = initializing ?: return
            initializing = null
            onReady()
        }

        override fun resized(width: Int, height: Int) {
            if (disposed) return
            update(value.copy(width = width, height = height))
        }

        /** The value resets, as video_player's turns erroneous; only a failure before the player is ready reaches [initialize]'s onError. */
        override fun failed(message: String) {
            if (disposed) return
            update(VideoValue())
            stopTicks()
            val (_, onError) = initializing ?: return
            initializing = null
            onError(message)
        }

        override fun completed() {
            if (disposed) return
            pause()
            seekTo(value.durationMs)
        }
    }

    fun play() {
        if (value.positionMs == value.durationMs) seekTo(0)
        update(value.copy(isPlaying = true))
        applyPlayPause()
    }

    fun pause() {
        update(value.copy(isPlaying = false))
        applyPlayPause()
    }

    fun seekTo(positionMs: Long) {
        if (!usable) return
        val position = when {
            positionMs > value.durationMs -> value.durationMs
            positionMs < 0 -> 0
            else -> positionMs
        }
        playback.seekTo(position)
        update(value.copy(positionMs = position))
    }

    fun setVolume(volume: Double) {
        update(value.copy(volume = volume.coerceIn(0.0, 1.0)))
        applyVolume()
    }

    fun setSpeed(speed: Double) {
        if (speed < 0) throw IllegalArgumentException("Negative playback speeds are generally unsupported.")
        if (speed == 0.0) throw IllegalArgumentException("Zero playback speed is generally unsupported. Consider using [pause].")
        update(value.copy(speed = speed))
        applySpeed()
    }

    fun setLooping(looping: Boolean) {
        update(value.copy(isLooping = looping))
        applyLooping()
    }

    fun setSurface(surface: Surface?) {
        if (!disposed) playback.setSurface(surface)
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        initializing = null
        stopTicks()
        playback.events = null
        playback.release()
    }

    /** video_player's `!_isDisposedOrNotInitialized`. */
    private val usable: Boolean get() = !disposed && value.isInitialized

    private fun applyLooping() {
        if (usable) playback.setLooping(value.isLooping)
    }

    private fun applyVolume() {
        if (usable) playback.setVolume(value.volume)
    }

    private fun applyPlayPause() {
        if (!usable) return
        if (value.isPlaying) {
            playback.play()
            stopTicks()
            ticks = scope.launch {
                while (true) {
                    delay(TICK_MS)
                    update(value.copy(positionMs = playback.positionMs))
                }
            }
            applySpeed()
        } else {
            stopTicks()
            playback.pause()
        }
    }

    /** Applied while playing only: MediaPlayer's setPlaybackParams with a speed starts a paused player. */
    private fun applySpeed() {
        if (usable && value.isPlaying) playback.setSpeed(value.speed)
    }

    private fun stopTicks() {
        ticks?.cancel()
        ticks = null
    }
}

/**
 * The platform player: a MediaPlayer streaming the url, drawing into the
 * view's surface. Callbacks run on the main thread (the MediaPlayer is made
 * there). Calls MediaPlayer's state machine refuses are not made: none
 * before it is prepared, pause only while playing, none after release.
 */
internal class MediaPlayerPlayback : VideoPlayback {
    override var events: VideoPlayback.Events? = null

    private var player: MediaPlayer? = null
    private var surface: Surface? = null
    private var prepared = false
    private var released = false

    /** The player once prepared, until it fails or is released. */
    private val ready: MediaPlayer? get() = player?.takeIf { prepared && !released }

    override val positionMs: Long get() = ready?.currentPosition?.toLong() ?: 0

    override fun open(url: String) {
        if (released || player != null) return
        val player = MediaPlayer()
        this.player = player
        surface?.let { player.setSurface(it) }
        player.setOnPreparedListener { mp ->
            prepared = true
            events?.prepared(mp.duration.coerceAtLeast(0).toLong(), mp.videoWidth, mp.videoHeight)
        }
        player.setOnVideoSizeChangedListener { _, width, height -> events?.resized(width, height) }
        player.setOnCompletionListener { events?.completed() }
        player.setOnErrorListener { _, what, extra ->
            prepared = false
            events?.failed("Video player had error what=$what extra=$extra")
            true
        }
        try {
            player.setDataSource(url)
            player.prepareAsync()
        } catch (e: Exception) {
            events?.failed(e.toString())
        }
    }

    override fun setSurface(surface: Surface?) {
        if (released) return
        this.surface = surface
        player?.setSurface(surface)
    }

    override fun play() {
        ready?.start()
    }

    override fun pause() {
        ready?.takeIf { it.isPlaying }?.pause()
    }

    /** To the closest frame where the platform can (API 26), as ExoPlayer's exact seek; else MediaPlayer's sync frame. */
    override fun seekTo(positionMs: Long) {
        val player = ready ?: return
        val ms = positionMs.coerceIn(0, Int.MAX_VALUE.toLong())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            player.seekTo(ms, MediaPlayer.SEEK_CLOSEST)
        } else {
            player.seekTo(ms.toInt())
        }
    }

    override fun setVolume(volume: Double) {
        if (released) return
        val v = volume.toFloat()
        player?.setVolume(v, v)
    }

    override fun setSpeed(speed: Double) {
        ready?.playbackParams = PlaybackParams().setSpeed(speed.toFloat())
    }

    override fun setLooping(looping: Boolean) {
        if (released) return
        player?.isLooping = looping
    }

    override fun release() {
        if (released) return
        released = true
        prepared = false
        events = null
        player?.release()
        player = null
        surface = null
    }
}
