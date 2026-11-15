package com.orcagateway.sdk.widgets

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ripple.RippleAlpha
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ElevatedButton
import androidx.compose.material3.LocalRippleConfiguration
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RippleConfiguration
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.LocalOrcaTheme
import com.orcagateway.sdk.style.Props

/**
 * ElevatedButton, OutlinedButton and TextButton as their Material 3
 * namesakes. A tap fires `onTap` and a long press `onLongPress` (instead of
 * `onTap`, as in Flutter); `enabled: false` disables both. Style props as
 * the Flutter builder reads them: ElevatedButton `backgroundColor`,
 * `foregroundColor`, `borderRadius`, `elevation`, `padding`;
 * OutlinedButton `color` and `borderColor`; TextButton `color`. A button
 * with none of its type's style props (`elevation` aside) takes the host's
 * style for the type from [LocalOrcaTheme], if any.
 *
 * All three take `splashColor` and `highlightColor` as [overlay] draws them,
 * and `autofocus`: the button asks for focus once, when first composed.
 * Compose grants this focus only outside touch mode (keyboard, D-pad,
 * mouse); in touch mode the button stays unfocused. A known difference from
 * Flutter, which focuses the button and draws no highlight on touch.
 */
@Composable
internal fun ButtonWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val enabled = node["enabled"]?.boolValue ?: true
    // Null when the server styled the button: its props win.
    val host = LocalOrcaTheme.current.buttonStyle(node)
    val onTap: () -> Unit = { model.fire("onTap", on = node) }
    val longPress = rememberUpdatedState<() -> Unit> { model.fire("onLongPress", on = node) }
    val interactions = remember { MutableInteractionSource() }
    val focus = remember { FocusRequester() }
    val autofocus = node["autofocus"]?.boolValue == true
    LaunchedEffect(Unit) { if (autofocus) focus.requestFocus() }
    val pressable = modifier.focusRequester(focus)
    val outer = if (enabled && node.actions["onLongPress"] != null) pressable.longPress(model, longPress) else pressable
    val label: @Composable RowScope.() -> Unit = {
        if (node.childIds.isNotEmpty()) ChildView(node, model) else Text("")
    }

    CompositionLocalProvider(LocalRippleConfiguration provides (overlay(node, interactions) ?: LocalRippleConfiguration.current)) {
        when (node.type) {
            "ElevatedButton" -> {
                val radius = Props.length(node["borderRadius"])
                val elevation = Props.length(node["elevation"])
                ElevatedButton(
                    onClick = onTap,
                    modifier = outer,
                    enabled = enabled,
                    shape = radius?.let { RoundedCornerShape(it) } ?: host?.shape ?: ButtonDefaults.elevatedShape,
                    colors = ButtonDefaults.elevatedButtonColors(
                        containerColor = Props.color(node["backgroundColor"]) ?: host?.containerColor ?: Color.Unspecified,
                        contentColor = Props.color(node["foregroundColor"]) ?: host?.contentColor ?: Color.Unspecified,
                    ),
                    elevation = elevation?.let { ButtonDefaults.elevatedButtonElevation(defaultElevation = it) }
                        ?: ButtonDefaults.elevatedButtonElevation(),
                    border = host?.border,
                    contentPadding = Props.insets(node["padding"])?.paddingValues()
                        ?: host?.contentPadding ?: ButtonDefaults.ContentPadding,
                    interactionSource = interactions,
                    content = label,
                )
            }

            "OutlinedButton" -> OutlinedButton(
                onClick = onTap,
                modifier = outer,
                enabled = enabled,
                shape = host?.shape ?: ButtonDefaults.outlinedShape,
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = host?.containerColor ?: Color.Unspecified,
                    contentColor = Props.color(node["color"]) ?: host?.contentColor ?: Color.Unspecified,
                ),
                border = Props.color(node["borderColor"])?.let { BorderStroke(1.dp, it) }
                    ?: host?.border ?: ButtonDefaults.outlinedButtonBorder(enabled),
                contentPadding = host?.contentPadding ?: ButtonDefaults.ContentPadding,
                interactionSource = interactions,
                content = label,
            )

            else -> TextButton(
                onClick = onTap,
                modifier = outer,
                enabled = enabled,
                shape = host?.shape ?: ButtonDefaults.textShape,
                colors = ButtonDefaults.textButtonColors(
                    containerColor = host?.containerColor ?: Color.Unspecified,
                    contentColor = Props.color(node["color"]) ?: host?.contentColor ?: Color.Unspecified,
                ),
                border = host?.border,
                contentPadding = host?.contentPadding ?: ButtonDefaults.TextButtonContentPadding,
                interactionSource = interactions,
                content = label,
            )
        }
    }
}

/**
 * Flutter's `_applyOverlay`: `splashColor` is the pressed overlay and
 * `highlightColor` the hovered one (here the focused one too), each
 * standing in for the other when alone. One ripple draws both, so its
 * colour follows the press; each state's alpha is its colour's own, as
 * Flutter draws the overlay colour as given (Android caps a press ripple at
 * half). Null, the theme's ripple, when neither is set.
 */
@Composable
private fun overlay(node: ResolvedNode, interactions: InteractionSource): RippleConfiguration? {
    val splash = Props.color(node["splashColor"])
    val highlight = Props.color(node["highlightColor"])
    val pressed by interactions.collectIsPressedAsState()
    val press = splash ?: highlight ?: return null
    val hover = highlight ?: press
    return RippleConfiguration(
        color = if (pressed) press else hover,
        rippleAlpha = RippleAlpha(
            draggedAlpha = press.alpha,
            focusedAlpha = hover.alpha,
            hoveredAlpha = hover.alpha,
            pressedAlpha = press.alpha,
        ),
    )
}

/**
 * Calls [action] when the pointer stays down past the long-press timeout,
 * then eats the rest of the gesture so the button's own click does not
 * fire too. It watches the initial pass, ahead of the button's clickable,
 * and leaves a short tap to it.
 */
internal fun Modifier.longPress(key: Any, action: State<() -> Unit>): Modifier = pointerInput(key) {
    awaitEachGesture {
        awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
        val released = withTimeoutOrNull(viewConfiguration.longPressTimeoutMillis) {
            do {
                val event = awaitPointerEvent(PointerEventPass.Initial)
            } while (event.changes.any { it.pressed })
            true
        }
        if (released == null) {
            action.value()
            do {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                event.changes.forEach { it.consume() }
            } while (event.changes.any { it.pressed })
        }
    }
}
