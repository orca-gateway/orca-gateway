package com.orcagateway.plugins.videoplayer

import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.plugins.TriggerDefinition
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.sdk.OrcaPlugin
import com.orcagateway.sdk.WidgetBuilder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject

/**
 * Video playback for Orca pages: Flutter's `VideoPlayerPlugin`
 * (plugins/orca_video_player/lib/src/video_player_plugin.dart, on
 * video_player 2.11.1) one to one. The `VideoPlayer` widget plays a
 * network video (props url, autoPlay, looping, showControls, aspectRatio,
 * playerId) and fires `onPlay` and `onPause` from its overlay tap,
 * `onProgress` {position, duration, fraction} while playing, `onComplete` at
 * the end and `onError` {message} when the video cannot load. The five
 * actions address a ready player by playerId: playVideo, pauseVideo,
 * seekVideo {position ms}, setVolume {volume}, setPlaybackSpeed {speed}.
 *
 * Plays with the platform's MediaPlayer on a TextureView; the app holds
 * INTERNET (this module's manifest). Make one plugin per app; its actions
 * run on the main thread.
 */
public class VideoPlayerPlugin internal constructor(
    /** A new platform player for each url a view opens. */
    private val playbacks: () -> VideoPlayback,
    /** Where the 100 ms position ticks run. */
    private val scope: CoroutineScope,
) : OrcaPlugin {
    /** Plays with the platform's MediaPlayer. */
    public constructor() : this(::MediaPlayerPlayback, CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate))

    override val name: String = "VideoPlayerPlugin"

    override val widgets: Map<String, WidgetBuilder> = mapOf("VideoPlayer" to videoPlayerBuilder(this))

    override val actions: Map<String, OrcaActionHandler> = mapOf(
        "playVideo" to OrcaActionHandler { action, executor -> player(action, executor)?.play() },
        "pauseVideo" to OrcaActionHandler { action, executor -> player(action, executor)?.pause() },
        "seekVideo" to OrcaActionHandler { action, executor -> seekVideo(action, executor) },
        "setVolume" to OrcaActionHandler { action, executor -> setVolume(action, executor) },
        "setPlaybackSpeed" to OrcaActionHandler { action, executor -> setPlaybackSpeed(action, executor) },
    )

    override val triggers: Map<String, List<TriggerDefinition>> = mapOf(
        "VideoPlayer" to listOf(
            TriggerDefinition(VideoPlayerProps.Triggers.onPlay, description = "Fires when playback starts"),
            TriggerDefinition(VideoPlayerProps.Triggers.onPause, description = "Fires when playback pauses"),
            TriggerDefinition(VideoPlayerProps.Triggers.onComplete, description = "Fires when video reaches the end"),
            TriggerDefinition(
                VideoPlayerProps.Triggers.onProgress,
                dataType = "VideoProgress",
                description = "Fires with {position, duration, fraction} during playback",
            ),
            TriggerDefinition(
                VideoPlayerProps.Triggers.onError,
                dataType = "String",
                description = "Fires with {message} on playback error",
            ),
        ),
    )

    /**
     * The ready players by playerId (Flutter's `_controllers`): a view adds
     * its player once it is ready and removes it when it leaves or its url
     * changes.
     */
    internal val players: MutableMap<String, VideoController> = HashMap()

    /** Flutter's `VideoPlayerController.networkUrl(url)..setLooping(looping)`. */
    internal fun controller(url: String, looping: Boolean): VideoController =
        VideoController(playbacks(), url, scope).also { it.setLooping(looping) }

    // MARK: Actions (Flutter :291-332)

    /** Flutter's `_controllers[executor.resolveString(action['playerId'] ?? '')]`. */
    private fun player(action: JsonObject, executor: ActionExecutor): VideoController? =
        players[executor.resolveString(action["playerId"])]

    private fun seekVideo(action: JsonObject, executor: ActionExecutor) {
        val playerId = executor.resolveString(action["playerId"])
        val position = executor.resolveNumber(action, "position")?.dartInt
        val controller = players[playerId]
        if (controller == null || position == null) return
        controller.seekTo(position)
    }

    private fun setVolume(action: JsonObject, executor: ActionExecutor) {
        val playerId = executor.resolveString(action["playerId"])
        val volume = executor.resolveNumber(action, "volume")?.doubleValue
        val controller = players[playerId]
        if (controller == null || volume == null) return
        controller.setVolume(volume.coerceIn(0.0, 1.0))
    }

    /** A speed of 0 or less throws, so the action fails, as video_player's ArgumentError fails Flutter's. */
    private fun setPlaybackSpeed(action: JsonObject, executor: ActionExecutor) {
        val playerId = executor.resolveString(action["playerId"])
        val speed = executor.resolveNumber(action, "speed")?.doubleValue
        val controller = players[playerId]
        if (controller == null || speed == null) return
        controller.setSpeed(speed)
    }
}

/** Flutter's `executor.resolveString(raw ?? '')`: the value resolved, as Dart text; '' for null. */
private fun ActionExecutor.resolveString(raw: JsonElement?): String {
    val value = JsonValue.fromJsonElement(resolve(raw ?: JsonNull))
    return if (value.isNull) "" else DartFormat.string(value)
}

/**
 * Flutter's `executor.resolveValue(action[key]) as num?`: null when absent
 * or null, else a number; anything else fails the action, as the cast throws.
 */
private fun ActionExecutor.resolveNumber(action: JsonObject, key: String): JsonValue? {
    val value = JsonValue.fromJsonElement(resolve(action[key] ?: JsonNull))
    if (value.isNull) return null
    require(value.isNumber) { "$key is not a number: ${DartFormat.string(value)}" }
    return value
}
