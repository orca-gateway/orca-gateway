package com.orcagateway.sdk.widgets

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.semantics
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel

/**
 * Flutter `GestureDetector` as the SDK's `_buildGestureDetector` builds it:
 * only the gestures the node has actions for are attached (`onTap`,
 * `onDoubleTap`, `onLongPress`), and then the whole box takes touches, not
 * just its child's drawn pixels (`HitTestBehavior.opaque`). With a double
 * tap attached a single tap fires once the double-tap timeout has passed
 * (Flutter's `kDoubleTapTimeout`); without one it fires at once. With no
 * actions it adds no pointer input and only draws its child, so a parent's
 * gestures still get the touches.
 *
 * Accessibility sees what Flutter's GestureDetector exposes: `onTap` as a
 * click action and `onLongPress` as a long-click action, so TalkBack can
 * activate them; `onDoubleTap` has no accessibility action.
 */
@Composable
internal fun GestureDetectorWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val tap = node.actions["onTap"] != null
    val doubleTap = node.actions["onDoubleTap"] != null
    val longPress = node.actions["onLongPress"] != null
    if (!tap && !doubleTap && !longPress) {
        ChildView(node, model, modifier)
        return
    }
    // The detector restarts only when the set of gestures changes; a
    // re-resolved node or a new model reaches it through this state.
    val fire = rememberUpdatedState<(String) -> Unit> { trigger -> model.fire(trigger, on = node) }
    val gestures = modifier.pointerInput(tap, doubleTap, longPress) {
        detectTapGestures(
            onTap = if (tap) ({ fire.value("onTap") }) else null,
            onDoubleTap = if (doubleTap) ({ fire.value("onDoubleTap") }) else null,
            onLongPress = if (longPress) ({ fire.value("onLongPress") }) else null,
        )
    }.semantics {
        if (tap) onClick { fire.value("onTap"); true }
        if (longPress) onLongClick { fire.value("onLongPress"); true }
    }
    Box(gestures, propagateMinConstraints = true) { ChildView(node, model) }
}
