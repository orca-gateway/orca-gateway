package com.orcagateway.sdk.widgets

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.indication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ripple.RippleAlpha
import androidx.compose.material3.LocalRippleConfiguration
import androidx.compose.material3.RippleConfiguration
import androidx.compose.material3.RippleDefaults
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.semantics
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props

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
 * activate them; `onDoubleTap` has no accessibility action. Under
 * [LocalPointerBlocked] it keeps its box but takes no touches and offers
 * no actions.
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
    // Under an IgnorePointer or AbsorbPointer: the same box, untouchable.
    val box = if (LocalPointerBlocked.current) modifier else gestures
    Box(box, propagateMinConstraints = true) { ChildView(node, model) }
}

/**
 * Flutter `InkWell` as the SDK's `_buildInkWell` builds it: Material's
 * InkWell on a transparent Material, its onTap, onLongPress and onDoubleTap
 * always set, even for a node without those actions. So it always takes
 * the touch (a GestureDetector around it gets none) and offers a click and
 * a long click to accessibility, and it has no `enabled`. A single tap
 * fires `onTap` once the double-tap timeout (the platform's 300 ms, as
 * Flutter's kDoubleTapTimeout) has passed with no second tap; a second tap
 * fires `onDoubleTap` instead; a press held for Flutter's 500 ms
 * ([FlutterGestureTiming]) fires `onLongPress` and no tap.
 *
 * The ink lies under the child, as Flutter paints it on the Material (an
 * opaque child hides it), clipped to `borderRadius`; the child is not
 * clipped. While pressed: the highlight in `highlightColor`, fading in and
 * out over Flutter's 200 ms, and over it the press ripple in `splashColor`
 * ([inkRipple]); without them ThemeData()'s #BCBCBC66 and #C8C8C866. It is
 * Compose's ripple, not Flutter's InkSparkle, and it starts at the touch
 * down, where Flutter's ink starts at its tap down: 100 ms into a press, or
 * for a quick tap once the double-tap wait is over.
 */
@Composable
internal fun InkWellWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val shape = Props.length(node["borderRadius"])?.let { RoundedCornerShape(it) } ?: RectangleShape
    val highlight = Props.color(node["highlightColor"]) ?: FlutterHighlight
    val ink = inkRipple(Props.color(node["splashColor"]))
    val fire = rememberUpdatedState<(String) -> Unit> { trigger -> model.fire(trigger, on = node) }
    val interactions = remember { MutableInteractionSource() }
    val pressed by interactions.collectIsPressedAsState()
    val shown = animateFloatAsState(if (pressed) 1f else 0f, tween(200, easing = LinearEasing), label = "highlight")
    FlutterGestureTiming {
        val touched = modifier.combinedClickable(
            interactionSource = interactions,
            indication = null,
            onLongClick = { fire.value("onLongPress") },
            onDoubleClick = { fire.value("onDoubleTap") },
            onClick = { fire.value("onTap") },
        )
        Box(touched, propagateMinConstraints = true) {
            // The ripple's colours reach only the ink, not the child's own buttons.
            CompositionLocalProvider(LocalRippleConfiguration provides ink) {
                Box(
                    Modifier.matchParentSize()
                        .clip(shape)
                        .drawBehind { if (shown.value > 0f) drawRect(highlight, alpha = shown.value) }
                        .indication(interactions, ripple()),
                )
            }
            ChildView(node, model)
        }
    }
}

/**
 * The InkWell's press ripple: [splash] (ThemeData()'s splash colour without
 * one) at its own alpha, pressed and dragged, as Flutter draws its splash as
 * given where Compose's ripple would take 0.1 (Android caps a press ripple
 * at half). Hover and focus keep Material 3's alphas.
 */
internal fun inkRipple(splash: Color?): RippleConfiguration {
    val color = splash ?: FlutterSplash
    val m3 = RippleDefaults.RippleAlpha
    return RippleConfiguration(
        color = color,
        rippleAlpha = RippleAlpha(
            draggedAlpha = color.alpha,
            focusedAlpha = m3.focusedAlpha,
            hoveredAlpha = m3.hoveredAlpha,
            pressedAlpha = color.alpha,
        ),
    )
}

/** ThemeData()'s light `splashColor` and `highlightColor` (theme_data.dart), an InkWell's without its own. */
private val FlutterSplash = Color(0x66C8C8C8)
private val FlutterHighlight = Color(0x66BCBCBC)
