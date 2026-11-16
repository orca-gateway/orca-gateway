package com.orcagateway.sdk.widgets

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ripple.RippleAlpha
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonColors
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ButtonElevation
import androidx.compose.material3.LocalAbsoluteTonalElevation
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalRippleConfiguration
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.LocalTonalElevationEnabled
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RippleConfiguration
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.material3.surfaceColorAtElevation
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
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
 *
 * Under [LocalPointerBlocked] (an ignoring IgnorePointer, an absorbing
 * AbsorbPointer) it is an [InertButton]: the same look, no touches, no
 * click or long-click action.
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
    val blocked = LocalPointerBlocked.current
    val pressable = modifier.focusRequester(focus)
    val outer = if (enabled && !blocked && node.actions["onLongPress"] != null) pressable.longPress(model, longPress) else pressable
    val label: @Composable RowScope.() -> Unit = {
        if (node.childIds.isNotEmpty()) ChildView(node, model) else Text("")
    }
    val look = when (node.type) {
        "ElevatedButton" -> {
            val radius = Props.length(node["borderRadius"])
            val elevation = Props.length(node["elevation"])
            ButtonLook(
                shape = radius?.let { RoundedCornerShape(it) } ?: host?.shape ?: ButtonDefaults.elevatedShape,
                colors = ButtonDefaults.elevatedButtonColors(
                    containerColor = Props.color(node["backgroundColor"]) ?: host?.containerColor ?: Color.Unspecified,
                    contentColor = Props.color(node["foregroundColor"]) ?: host?.contentColor ?: Color.Unspecified,
                ),
                elevation = elevation?.let { ButtonDefaults.elevatedButtonElevation(defaultElevation = it) }
                    ?: ButtonDefaults.elevatedButtonElevation(),
                // What it casts at rest (ElevatedButtonTokens: Level1, Level0 disabled).
                restElevation = if (enabled) elevation ?: 1.dp else 0.dp,
                border = host?.border,
                padding = Props.insets(node["padding"])?.paddingValues()
                    ?: host?.contentPadding ?: ButtonDefaults.ContentPadding,
            )
        }

        "OutlinedButton" -> ButtonLook(
            shape = host?.shape ?: ButtonDefaults.outlinedShape,
            colors = ButtonDefaults.outlinedButtonColors(
                containerColor = host?.containerColor ?: Color.Unspecified,
                contentColor = Props.color(node["color"]) ?: host?.contentColor ?: Color.Unspecified,
            ),
            border = Props.color(node["borderColor"])?.let { BorderStroke(1.dp, it) }
                ?: host?.border ?: ButtonDefaults.outlinedButtonBorder(enabled),
            padding = host?.contentPadding ?: ButtonDefaults.ContentPadding,
        )

        else -> ButtonLook(
            shape = host?.shape ?: ButtonDefaults.textShape,
            colors = ButtonDefaults.textButtonColors(
                containerColor = host?.containerColor ?: Color.Unspecified,
                contentColor = Props.color(node["color"]) ?: host?.contentColor ?: Color.Unspecified,
            ),
            border = host?.border,
            padding = host?.contentPadding ?: ButtonDefaults.TextButtonContentPadding,
        )
    }

    CompositionLocalProvider(LocalRippleConfiguration provides (overlay(node, interactions) ?: LocalRippleConfiguration.current)) {
        if (blocked) {
            InertButton(outer, enabled, look, label)
        } else {
            // What ElevatedButton, OutlinedButton and TextButton call with their defaults.
            Button(
                onClick = onTap,
                modifier = outer,
                enabled = enabled,
                shape = look.shape,
                colors = look.colors,
                elevation = look.elevation,
                border = look.border,
                contentPadding = look.padding,
                interactionSource = interactions,
                content = label,
            )
        }
    }
}

/** A Material 3 button's parameters, as its type's defaults and the node's props give them. */
private class ButtonLook(
    val shape: Shape,
    val colors: ButtonColors,
    val elevation: ButtonElevation? = null,
    /** The shadow [elevation] casts at rest ([ButtonElevation] keeps it private). */
    val restElevation: Dp = 0.dp,
    val border: BorderStroke?,
    val padding: PaddingValues,
)

/**
 * Material 3's `Button` as it draws at rest, without its clickable, for a
 * button under [LocalPointerBlocked]: no pointer input and no click
 * action, but the same look (never drawn as disabled unless it is) and,
 * as Flutter keeps under an IgnorePointer, the label, the button role and
 * the enabled state for accessibility.
 *
 * Mirrors androidx.compose.material3 1.4.0 (what compose-bom 2026.05.01
 * resolves to), from its sources: Button.kt `Button` (colours by enabled,
 * `ProvideContentColorTextStyle` with `typography.labelLarge`, the Row with
 * `ButtonDefaults.MinWidth`/`MinHeight` and the content padding, the
 * Button role); Surface.kt's clickable `Surface` (its modifier order:
 * `minimumInteractiveComponentSize`, then the private `Modifier.surface`:
 * shadow layer, border, background, clip) and its tonal tint
 * (ColorScheme.kt `applyTonalElevation`: only a `surface` container, when
 * `LocalTonalElevationEnabled`); the rest elevation from
 * ElevatedButtonTokens (`ButtonLook.restElevation`). Re-check it when the
 * BOM moves material3. The public non-clickable `Surface` is not used: it
 * ends in `pointerInput(Unit) {}`, so it would be hit under an
 * IgnorePointer and hide what is behind; Material's button always has the
 * clickable's pointer input, disabled or not.
 */
@Composable
private fun InertButton(modifier: Modifier, enabled: Boolean, look: ButtonLook, content: @Composable RowScope.() -> Unit) {
    val scheme = MaterialTheme.colorScheme
    val container = if (enabled) look.colors.containerColor else look.colors.disabledContainerColor
    val fill = if (container == scheme.surface && LocalTonalElevationEnabled.current) {
        scheme.surfaceColorAtElevation(LocalAbsoluteTonalElevation.current)
    } else {
        container
    }
    val shadow = look.restElevation
    CompositionLocalProvider(
        LocalContentColor provides if (enabled) look.colors.contentColor else look.colors.disabledContentColor,
        LocalTextStyle provides LocalTextStyle.current.merge(MaterialTheme.typography.labelLarge),
    ) {
        Box(
            modifier.semantics(mergeDescendants = true) {
                role = Role.Button
                if (!enabled) disabled()
            }
                .minimumInteractiveComponentSize()
                .then(if (shadow > 0.dp) Modifier.graphicsLayer { shadowElevation = shadow.toPx(); shape = look.shape } else Modifier)
                .then(look.border?.let { Modifier.border(it, look.shape) } ?: Modifier)
                .background(fill, look.shape)
                .clip(look.shape),
            propagateMinConstraints = true,
        ) {
            Row(
                Modifier.defaultMinSize(minWidth = ButtonDefaults.MinWidth, minHeight = ButtonDefaults.MinHeight)
                    .padding(look.padding),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
                content = content,
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
