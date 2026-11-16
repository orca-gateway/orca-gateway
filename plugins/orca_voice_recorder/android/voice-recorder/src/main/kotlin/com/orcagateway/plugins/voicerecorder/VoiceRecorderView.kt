package com.orcagateway.plugins.voicerecorder

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilder

/** The test tag of the amplitude bar, drawn while recording when showAmplitude is on. */
internal const val AMPLITUDE_BAR_TAG: String = "voiceRecorder.amplitude"

/** Flutter's `_buildVoiceRecorder`: recorderId defaults to the node's id, showAmplitude to true. */
internal fun voiceRecorderBuilder(plugin: VoiceRecorderPlugin): WidgetBuilder = { node, model, modifier ->
    val props = VoiceRecorderProps(node)
    val recorderId = props.recorderId ?: node.id
    // Flutter's ValueKey('voice_recorder_$recorderId'): another id is another view.
    key(recorderId) {
        VoiceRecorderView(plugin, recorderId, props.showAmplitude ?: true, node, model, modifier)
    }
}

/** The dot's colour: red recording, orange paused, grey otherwise. */
internal fun dotColor(state: String): Color = when (state) {
    "recording" -> Color(0xFFFF0000)
    "paused" -> Color(0xFFFF9800)
    else -> Color(0xFF9E9E9E)
}

/** How much of the bar is filled: (amplitude + 60) clamped to 0...60, over 60. */
internal fun amplitudeFraction(amplitude: Double): Float = ((amplitude + 60).coerceIn(0.0, 60.0) / 60).toFloat()

/**
 * Flutter's `_VoiceRecorderWidget`: draws the recorder's state and fires the
 * node's `onStateChange` {state} and `onAmplitudeChange` {amplitude} on every
 * change of either. It also registers the launcher through which the plugin
 * asks for the microphone.
 */
@Composable
private fun VoiceRecorderView(
    plugin: VoiceRecorderPlugin,
    recorderId: String,
    showAmplitude: Boolean,
    node: ResolvedNode,
    model: OrcaPageModel,
    modifier: Modifier,
) {
    val instance = remember(plugin, recorderId) { plugin.recorder(recorderId) }
    val current by rememberUpdatedState(node)
    DisposableEffect(instance, model) {
        val onState: (String) -> Unit = { state ->
            model.fire(VoiceRecorderProps.Triggers.onStateChange, on = current, eventData = mapOf("state" to JsonValue.String(state)))
        }
        val onAmplitude: (Double) -> Unit = { amplitude ->
            model.fire(
                VoiceRecorderProps.Triggers.onAmplitudeChange,
                on = current,
                eventData = mapOf("amplitude" to JsonValue.Double(amplitude)),
            )
        }
        instance.stateListeners += onState
        instance.amplitudeListeners += onAmplitude
        onDispose {
            instance.stateListeners -= onState
            instance.amplitudeListeners -= onAmplitude
        }
    }

    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        plugin.permissionAnswered(granted)
    }
    DisposableEffect(plugin, launcher) {
        val request: (String) -> Unit = { permission -> launcher.launch(permission) }
        plugin.requestPermission = request
        onDispose { if (plugin.requestPermission === request) plugin.requestPermission = null }
    }

    val state = instance.state
    val isRecording = state == "recording"
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(16.dp).background(dotColor(state), CircleShape))
        if (showAmplitude && isRecording) {
            Spacer(Modifier.height(8.dp))
            Box(Modifier.size(width = 100.dp, height = 4.dp).testTag(AMPLITUDE_BAR_TAG)) {
                Box(
                    Modifier
                        .fillMaxHeight()
                        .fillMaxWidth(amplitudeFraction(instance.amplitude))
                        .background(Color(0xFF4CAF50), RoundedCornerShape(2.dp)),
                )
            }
        }
        Spacer(Modifier.height(4.dp))
        Text(
            when (state) {
                "recording" -> "Recording"
                "paused" -> "Paused"
                else -> "Ready"
            },
            fontSize = 12.sp,
        )
    }
}
