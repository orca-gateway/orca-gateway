package com.orcagateway.plugins.voicerecorder

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
 * from OrcaVoiceRecorderTypes.kt, what `orca plugin generate --lang kotlin
 * --types-only` writes for plugins/orca_voice_recorder/orca_plugin.yaml
 * (committed as generated, kept in sync by
 * cli/test/voice_recorder_kotlin_props_test.dart). They read what the Flutter
 * plugin reads (lib/src/voice_recorder_plugin.dart :224-464), with the same
 * names and types; Flutter's defaults are the plugin's to apply, so an absent
 * prop or param reads null.
 */
class VoiceRecorderPropsTest {
    /** A resolved `VoiceRecorder` node with [props]. */
    private fun node(vararg props: Pair<String, JsonValue>) = ResolvedNode(
        id = "voice",
        type = "VoiceRecorder",
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
    fun c17_5_theWidgetPropsAreRecorderIdAndShowAmplitude() {
        assertEquals(setOf("recorderId", "showAmplitude"), properties(VoiceRecorderProps::class.java))

        val props = VoiceRecorderProps(
            node("recorderId" to JsonValue.String("memo"), "showAmplitude" to JsonValue.Bool(false)),
        )
        assertEquals<String?>("memo", props.recorderId)
        assertEquals<Boolean?>(false, props.showAmplitude)
    }

    /** Flutter falls back to the node's id and to true: the plugin does, the props do not. */
    @Test
    fun c17_5_absentPropsReadNull() {
        val absent = VoiceRecorderProps(node())
        assertNull(absent.recorderId)
        assertNull(absent.showAmplitude)

        val nulls = VoiceRecorderProps(node("recorderId" to JsonValue.Null, "showAmplitude" to JsonValue.Null))
        assertNull(nulls.recorderId)
        assertNull(nulls.showAmplitude)
    }

    @Test
    fun c17_5_theTriggersAreExactlyFluttersThree() {
        val names = listOf("onStateChange", "onAmplitudeChange", "onRecordingComplete")
        assertEquals(names.associateWith { it }, constants(VoiceRecorderProps.Triggers::class.java))
        assertEquals(
            names,
            listOf(
                VoiceRecorderProps.Triggers.onStateChange,
                VoiceRecorderProps.Triggers.onAmplitudeChange,
                VoiceRecorderProps.Triggers.onRecordingComplete,
            ),
        )
    }

    @Test
    fun c17_5_eachOfTheNineActionsHasFluttersParams() {
        val keys = setOf("positionKey", "durationKey", "stateKey", "scope")
        assertEquals(
            mapOf(
                "startRecording" to setOf("recorderId"),
                "stopRecording" to setOf("recorderId", "pathKey", "durationKey", "scope"),
                "pauseRecording" to setOf("recorderId"),
                "resumeRecording" to setOf("recorderId"),
                "playRecording" to setOf("path") + keys,
                "stopPlayback" to setOf("positionKey", "stateKey", "scope"),
                "pausePlayback" to setOf("stateKey", "scope"),
                "resumePlayback" to setOf("stateKey", "scope"),
                "seekPlayback" to setOf("position"),
            ),
            mapOf(
                "startRecording" to properties(StartRecordingParams::class.java),
                "stopRecording" to properties(StopRecordingParams::class.java),
                "pauseRecording" to properties(PauseRecordingParams::class.java),
                "resumeRecording" to properties(ResumeRecordingParams::class.java),
                "playRecording" to properties(PlayRecordingParams::class.java),
                "stopPlayback" to properties(StopPlaybackParams::class.java),
                "pausePlayback" to properties(PausePlaybackParams::class.java),
                "resumePlayback" to properties(ResumePlaybackParams::class.java),
                "seekPlayback" to properties(SeekPlaybackParams::class.java),
            ),
        )
    }

    @Test
    fun c17_5_theRecordingParamsReadFluttersStrings() {
        assertEquals<String?>("memo", StartRecordingParams(action("startRecording", "recorderId" to "memo")).recorderId)
        assertEquals<String?>("memo", PauseRecordingParams(action("pauseRecording", "recorderId" to "memo")).recorderId)
        assertEquals<String?>("memo", ResumeRecordingParams(action("resumeRecording", "recorderId" to "memo")).recorderId)

        val stop = StopRecordingParams(
            action(
                "stopRecording",
                "recorderId" to "memo", "pathKey" to "savedPath", "durationKey" to "savedMs", "scope" to "app",
            ),
        )
        assertEquals<String?>("memo", stop.recorderId)
        assertEquals<String?>("savedPath", stop.pathKey)
        assertEquals<String?>("savedMs", stop.durationKey)
        assertEquals<String?>("app", stop.scope)
    }

    @Test
    fun c17_5_thePlaybackParamsReadFluttersStringsAndANumberPosition() {
        val play = PlayRecordingParams(
            action(
                "playRecording",
                "path" to "/tmp/orca_recording_memo_1.m4a", "positionKey" to "pos", "durationKey" to "len",
                "stateKey" to "playback", "scope" to "app",
            ),
        )
        assertEquals<String?>("/tmp/orca_recording_memo_1.m4a", play.path)
        assertEquals<String?>("pos", play.positionKey)
        assertEquals<String?>("len", play.durationKey)
        assertEquals<String?>("playback", play.stateKey)
        assertEquals<String?>("app", play.scope)

        val stop = StopPlaybackParams(action("stopPlayback", "positionKey" to "pos", "stateKey" to "playback", "scope" to "app"))
        assertEquals<String?>("pos", stop.positionKey)
        assertEquals<String?>("playback", stop.stateKey)
        assertEquals<String?>("app", stop.scope)

        val pause = PausePlaybackParams(action("pausePlayback", "stateKey" to "playback", "scope" to "app"))
        assertEquals<String?>("playback", pause.stateKey)
        assertEquals<String?>("app", pause.scope)

        val resume = ResumePlaybackParams(action("resumePlayback", "stateKey" to "playback", "scope" to "app"))
        assertEquals<String?>("playback", resume.stateKey)
        assertEquals<String?>("app", resume.scope)

        // Flutter's `positionRaw is num`: an integer or a double.
        assertEquals<Double?>(1500.0, SeekPlaybackParams(action("seekPlayback", "position" to 1500)).position)
        assertEquals<Double?>(250.5, SeekPlaybackParams(action("seekPlayback", "position" to 250.5)).position)
    }

    /** Where Flutter applies a default (`scope` page, a seek to 0), the param reads null. */
    @Test
    fun c17_5_absentParamsReadNull() {
        val stop = StopRecordingParams(action("stopRecording"))
        assertNull(stop.recorderId)
        assertNull(stop.pathKey)
        assertNull(stop.durationKey)
        assertNull(stop.scope)

        val play = PlayRecordingParams(action("playRecording", "path" to null))
        assertNull(play.path)
        assertNull(play.positionKey)
        assertNull(play.durationKey)
        assertNull(play.stateKey)
        assertNull(play.scope)

        assertNull(StopPlaybackParams(action("stopPlayback")).stateKey)
        assertNull(PausePlaybackParams(action("pausePlayback")).scope)
        assertNull(ResumePlaybackParams(action("resumePlayback")).scope)
        assertNull(SeekPlaybackParams(action("seekPlayback")).position)
        assertNull(SeekPlaybackParams(action("seekPlayback", "position" to "later")).position)
    }
}
