package com.orcagateway.plugins.videoplayer

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.ResolvedNode
import kotlinx.serialization.json.JsonObject
import org.junit.Test
import java.lang.reflect.Modifier
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * C17.5/K: the props, trigger names and action params the plugin reads come
 * from OrcaVideoPlayerTypes.kt, what `orca plugin generate --lang kotlin
 * --types-only` writes for plugins/orca_video_player/orca_plugin.yaml
 * (committed as generated, kept in sync by
 * cli/test/video_player_kotlin_props_test.dart). They read what the Flutter
 * plugin reads (lib/src/video_player_plugin.dart :45-69, :94-100, :291-332),
 * with the same names and types; Flutter's defaults are the plugin's to apply,
 * so an absent prop or param reads null.
 */
class VideoPlayerPropsTest {
    /** A resolved `VideoPlayer` node with [props]. */
    private fun node(vararg props: Pair<String, JsonValue>) = ResolvedNode(
        id = "video",
        type = "VideoPlayer",
        kind = ComponentNode.Kind.Primitive,
        props = mapOf(*props),
        childIds = emptyList(),
        slots = emptyMap(),
        actions = emptyMap(),
        watches = emptyList(),
    )

    /** The raw object of a `custom:<name>` action with [params], as a handler receives it. */
    private fun action(name: String, vararg params: Pair<String, Any?>): JsonObject =
        JsonValue.obj("type" to "custom:$name", *params).toJsonElement() as JsonObject

    /** The public properties a generated type declares, less the node or action it reads. */
    private fun properties(type: Class<*>): Set<String> = type.declaredMethods
        .filter { Modifier.isPublic(it.modifiers) && it.parameterCount == 0 && it.name.startsWith("get") }
        .map { it.name.removePrefix("get").replaceFirstChar { c -> c.lowercaseChar() } }
        .toSet() - setOf("node", "action")

    /** The string constants of an object, by name. */
    private fun constants(type: Class<*>): Map<String, Any?> = type.declaredFields
        .filter { Modifier.isStatic(it.modifiers) && it.type == String::class.java }
        .associate { it.name to it.get(null) }

    @Test
    fun c17_5_theWidgetPropsAreFluttersSix() {
        assertEquals(
            setOf("url", "autoPlay", "looping", "showControls", "aspectRatio", "playerId"),
            properties(VideoPlayerProps::class.java),
        )

        val props = VideoPlayerProps(
            node(
                "url" to JsonValue.String("https://example.com/clip.mp4"),
                "autoPlay" to JsonValue.Bool(true),
                "looping" to JsonValue.Bool(true),
                "showControls" to JsonValue.Bool(false),
                "aspectRatio" to JsonValue.Double(1.5),
                "playerId" to JsonValue.String("demo"),
            ),
        )
        assertEquals<String?>("https://example.com/clip.mp4", props.url)
        assertEquals<Boolean?>(true, props.autoPlay)
        assertEquals<Boolean?>(true, props.looping)
        assertEquals<Boolean?>(false, props.showControls)
        assertEquals<Double?>(1.5, props.aspectRatio)
        assertEquals<String?>("demo", props.playerId)

        // Flutter's `prop<num>('aspectRatio')?.toDouble()`: an integer or a double.
        assertEquals<Double?>(2.0, VideoPlayerProps(node("aspectRatio" to JsonValue.Int(2))).aspectRatio)
    }

    /** Flutter falls back to "", false, false, true, the video's ratio and the node's id: the plugin does, the props do not. */
    @Test
    fun c17_5_absentPropsReadNull() {
        val absent = VideoPlayerProps(node())
        assertNull(absent.url)
        assertNull(absent.autoPlay)
        assertNull(absent.looping)
        assertNull(absent.showControls)
        assertNull(absent.aspectRatio)
        assertNull(absent.playerId)

        val nulls = VideoPlayerProps(
            node(
                "url" to JsonValue.Null, "autoPlay" to JsonValue.Null, "looping" to JsonValue.Null,
                "showControls" to JsonValue.Null, "aspectRatio" to JsonValue.Null, "playerId" to JsonValue.Null,
            ),
        )
        assertNull(nulls.url)
        assertNull(nulls.autoPlay)
        assertNull(nulls.looping)
        assertNull(nulls.showControls)
        assertNull(nulls.aspectRatio)
        assertNull(nulls.playerId)
    }

    @Test
    fun c17_5_theTriggersAreExactlyFluttersFive() {
        val names = listOf("onPlay", "onPause", "onComplete", "onProgress", "onError")
        assertEquals(names.associateWith { it }, constants(VideoPlayerProps.Triggers::class.java))
        assertEquals(
            names,
            listOf(
                VideoPlayerProps.Triggers.onPlay,
                VideoPlayerProps.Triggers.onPause,
                VideoPlayerProps.Triggers.onComplete,
                VideoPlayerProps.Triggers.onProgress,
                VideoPlayerProps.Triggers.onError,
            ),
        )
    }

    @Test
    fun c17_5_eachOfTheFiveActionsHasFluttersParams() {
        assertEquals(
            mapOf(
                "playVideo" to setOf("playerId"),
                "pauseVideo" to setOf("playerId"),
                "seekVideo" to setOf("playerId", "position"),
                "setVolume" to setOf("playerId", "volume"),
                "setPlaybackSpeed" to setOf("playerId", "speed"),
            ),
            mapOf(
                "playVideo" to properties(PlayVideoParams::class.java),
                "pauseVideo" to properties(PauseVideoParams::class.java),
                "seekVideo" to properties(SeekVideoParams::class.java),
                "setVolume" to properties(SetVolumeParams::class.java),
                "setPlaybackSpeed" to properties(SetPlaybackSpeedParams::class.java),
            ),
        )
    }

    @Test
    fun c17_5_theParamsReadFluttersPlayerIdAndNumbers() {
        assertEquals<String?>("demo", PlayVideoParams(action("playVideo", "playerId" to "demo")).playerId)
        assertEquals<String?>("demo", PauseVideoParams(action("pauseVideo", "playerId" to "demo")).playerId)

        // Flutter's `resolveValue(...) as num?`: an integer or a double.
        val seek = SeekVideoParams(action("seekVideo", "playerId" to "demo", "position" to 1500))
        assertEquals<String?>("demo", seek.playerId)
        assertEquals<Double?>(1500.0, seek.position)
        assertEquals<Double?>(250.5, SeekVideoParams(action("seekVideo", "position" to 250.5)).position)

        val volume = SetVolumeParams(action("setVolume", "playerId" to "demo", "volume" to 0.5))
        assertEquals<String?>("demo", volume.playerId)
        assertEquals<Double?>(0.5, volume.volume)
        assertEquals<Double?>(1.0, SetVolumeParams(action("setVolume", "volume" to 1)).volume)

        val speed = SetPlaybackSpeedParams(action("setPlaybackSpeed", "playerId" to "demo", "speed" to 1.5))
        assertEquals<String?>("demo", speed.playerId)
        assertEquals<Double?>(1.5, speed.speed)
        assertEquals<Double?>(2.0, SetPlaybackSpeedParams(action("setPlaybackSpeed", "speed" to 2)).speed)
    }

    /** Where Flutter falls back (playerId "") or does nothing (a missing number), the param reads null. */
    @Test
    fun c17_5_absentParamsReadNull() {
        assertNull(PlayVideoParams(action("playVideo")).playerId)
        assertNull(PauseVideoParams(action("pauseVideo", "playerId" to null)).playerId)

        val seek = SeekVideoParams(action("seekVideo"))
        assertNull(seek.playerId)
        assertNull(seek.position)
        assertNull(SeekVideoParams(action("seekVideo", "position" to "later")).position)

        val volume = SetVolumeParams(action("setVolume", "volume" to null))
        assertNull(volume.playerId)
        assertNull(volume.volume)

        val speed = SetPlaybackSpeedParams(action("setPlaybackSpeed"))
        assertNull(speed.playerId)
        assertNull(speed.speed)
    }
}
