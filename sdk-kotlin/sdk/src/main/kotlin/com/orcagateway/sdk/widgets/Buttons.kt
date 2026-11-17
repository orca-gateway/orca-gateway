package com.orcagateway.sdk.widgets

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ripple.RippleAlpha
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonColors
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ButtonElevation
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.FloatingActionButtonDefaults
import androidx.compose.material3.LocalAbsoluteTonalElevation
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalRippleConfiguration
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.LocalTonalElevationEnabled
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RippleConfiguration
import androidx.compose.material3.RippleDefaults
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.material3.Surface
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WithColorScheme
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
 *
 * A DefaultTextStyle above it stops here: the label lies on the button's
 * Material (button_style_button.dart:628, material.dart:470-474).
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

    CompositionLocalProvider(
        LocalRippleConfiguration provides (overlay(node, interactions) ?: LocalRippleConfiguration.current),
        LocalOrcaDefaultTextStyle provides null,
    ) {
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

/**
 * Flutter `IconButton` as its builder (`_buildIconButton`) draws it, not
 * Material's: a (`size` + 16) square, `size` 24 by default, holding the
 * child (an empty `size` square without one) centred, or with `padding`
 * aligned by `alignment` (center by default) inside it. `color`, only when
 * set, tints the child's icons (Flutter's IconTheme, here the content
 * colour, as [IconWidget] reads it; unlike Flutter's IconTheme it also
 * colours a Text child without its own colour); an Icon child keeps its
 * own size, so `size` grows only the box. Disabled it is drawn at opacity
 * 0.38. It takes touches only when enabled and given `onTap` or
 * `onLongPress`, then over its whole box, and offers those to
 * accessibility; otherwise it takes none, so the widgets around it get
 * them. A long press takes Flutter's 500 ms ([FlutterGestureTiming]).
 * `constraints` bound the box from outside. A `tooltip`, unless empty, is
 * Flutter's Tooltip around it (button_builders.dart:158-159): its
 * accessibility label, and a hold of 500 ms shows the bubble
 * ([TooltipBubble]) and fires nothing. With its own `onLongPress` the
 * button keeps the hold: its recognizer, inside the Tooltip, starts its
 * timer first and wins the arena (binding.dart:506, recognizer.dart:708).
 * No ripple or press feedback, as Flutter draws none (`splashColor` and
 * `highlightColor` are never read). No Material either, so unlike the
 * other buttons it leaves a DefaultTextStyle above it in force.
 */
@Composable
internal fun IconButtonWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val enabled = node["enabled"]?.boolValue ?: true
    val size = Props.length(node["size"]) ?: 24.dp
    val color = Props.color(node["color"])
    val padding = Props.insets(node["padding"])
    val bounds = node["constraints"]?.objectValue
    val tap = enabled && node.actions["onTap"] != null
    val longPress = enabled && node.actions["onLongPress"] != null
    val fire = rememberUpdatedState<(String) -> Unit> { trigger -> model.fire(trigger, on = node) }
    val tooltip = node["tooltip"]?.stringValue
    val tip = rememberTooltip()
    val constrained = modifier.tooltip(tip, tooltip, armed = !longPress).sizeIn(
        minWidth = Props.length(bounds?.get("minWidth")) ?: Dp.Unspecified,
        minHeight = Props.length(bounds?.get("minHeight")) ?: Dp.Unspecified,
        maxWidth = Props.length(bounds?.get("maxWidth")) ?: Dp.Unspecified,
        maxHeight = Props.length(bounds?.get("maxHeight")) ?: Dp.Unspecified,
    )
    val touched = if (tap || longPress) {
        constrained.pointerInput(tap, longPress) {
            detectTapGestures(
                onTap = if (tap) ({ fire.value("onTap") }) else null,
                onLongPress = if (longPress) ({ fire.value("onLongPress") }) else null,
            )
        }.semantics {
            if (tap) onClick { fire.value("onTap"); true }
            if (longPress) onLongClick { fire.value("onLongPress"); true }
        }
    } else {
        constrained
    }
    val child: @Composable () -> Unit = {
        if (node.childIds.isNotEmpty()) ChildView(node, model) else Box(Modifier.size(size))
    }
    FlutterGestureTiming {
        Box(
            touched.then(if (enabled) Modifier else Modifier.alpha(0.38f))
                .size(size + 16.dp)
                .then(padding?.let { Modifier.padding(it.paddingValues()) } ?: Modifier),
            contentAlignment = if (padding != null) Props.alignment(node["alignment"]) else Alignment.Center,
        ) {
            if (color != null) CompositionLocalProvider(LocalContentColor provides color, content = child) else child()
            TooltipBubble(tip, tooltip)
        }
    }
}

/**
 * Flutter `FloatingActionButton` (`_buildFAB`): Material 3's
 * `FloatingActionButton`, or `SmallFloatingActionButton` when `mini` (40
 * in a 48 touch target, as Flutter pads it), in Flutter's `ThemeData()`
 * colours ([FlutterLightScheme]): `backgroundColor` (primaryContainer without
 * one), the content in onPrimaryContainer, at `elevation` (6 without one;
 * pressed and focused 6, hovered 8, as both Material 3s). Enabled, a tap
 * fires `onTap` and a long press `onLongPress`, through a wrapper as
 * Flutter's GestureDetector around it: it takes the tap even with no
 * `onTap` (Flutter passes onPressed whenever enabled), and a long press,
 * after Flutter's 500 ms ([FlutterGestureTiming]), is never a tap.
 * `splashColor`, `focusColor` and `hoverColor` colour its ripple
 * ([fabOverlay]). Disabled it is drawn unchanged (Flutter's disabled elevation
 * falls back to `elevation`) and is an [InertFab]. A `tooltip`, unless
 * empty, is the Tooltip Material's FAB wraps itself in, enabled or not
 * (floating_action_button.dart:622-623): its accessibility label, and a
 * hold shows the bubble ([TooltipBubble]). Inside the wrapper, its long
 * press starts first and wins, so then a hold fires no `onLongPress`
 * (TalkBack's long click still does). The Scaffold's
 * `floatingActionButton` slot places it at the bottom end, 16 in, as
 * Flutter's endFloat. A DefaultTextStyle above it stops here: its
 * RawMaterialButton's Material resets it.
 */
@Composable
internal fun FloatingActionButtonWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val enabled = node["enabled"]?.boolValue ?: true
    val mini = node["mini"]?.boolValue ?: false
    val elevation = Props.length(node["elevation"]) ?: 6.dp
    val longPress = rememberUpdatedState<() -> Unit> { model.fire("onLongPress", on = node) }
    val tooltip = node["tooltip"]?.stringValue
    val tip = rememberTooltip()
    val labelled = modifier.tooltip(tip, tooltip)
    val content: @Composable () -> Unit = {
        if (node.childIds.isNotEmpty()) ChildView(node, model)
        TooltipBubble(tip, tooltip)
    }
    val interactions = remember { MutableInteractionSource() }
    FlutterGestureTiming {
        WithColorScheme(FlutterLightScheme) {
            val fill = Props.color(node["backgroundColor"]) ?: MaterialTheme.colorScheme.primaryContainer
            val ink = MaterialTheme.colorScheme.onPrimaryContainer
            val shape = if (mini) FloatingActionButtonDefaults.smallShape else FloatingActionButtonDefaults.shape
            val held = if (tooltip.isNullOrEmpty()) labelled.longPress(model, longPress) else labelled
            val pressable = held.semantics { onLongClick { longPress.value(); true } }
            val onTap: () -> Unit = { model.fire("onTap", on = node) }
            val raised = FloatingActionButtonDefaults.elevation(defaultElevation = elevation)
            val ripple = fabOverlay(node, ink, interactions) ?: LocalRippleConfiguration.current
            CompositionLocalProvider(LocalRippleConfiguration provides ripple, LocalOrcaDefaultTextStyle provides null) {
                when {
                    !enabled -> InertFab(labelled, mini, shape, fill, ink, elevation, content)
                    mini -> SmallFloatingActionButton(onTap, pressable, shape, fill, ink, raised, interactions, content)
                    else -> FloatingActionButton(onTap, pressable, shape, fill, ink, raised, interactions, content)
                }
            }
        }
    }
}

/**
 * Flutter's FAB overlay colours as its InkWell draws them: `splashColor`
 * while pressed (and dragged), `focusColor` while focused, `hoverColor`
 * while hovered, each at its own alpha. One left unset is Material 3's:
 * the content colour [ink] at the state's default alpha (0.1 pressed and
 * focused, 0.08 hovered, as Flutter's M3 FAB defaults). Null, the theme's
 * ripple, when none is set.
 */
@Composable
private fun fabOverlay(node: ResolvedNode, ink: Color, interactions: InteractionSource): RippleConfiguration? {
    val splash = Props.color(node["splashColor"])
    val focus = Props.color(node["focusColor"])
    val hover = Props.color(node["hoverColor"])
    val pressed by interactions.collectIsPressedAsState()
    val focused by interactions.collectIsFocusedAsState()
    if (splash == null && focus == null && hover == null) return null
    val m3 = RippleDefaults.RippleAlpha
    return RippleConfiguration(
        color = when {
            pressed -> splash ?: ink
            focused -> focus ?: ink
            else -> hover ?: ink
        },
        rippleAlpha = RippleAlpha(
            draggedAlpha = splash?.alpha ?: m3.draggedAlpha,
            focusedAlpha = focus?.alpha ?: m3.focusedAlpha,
            hoveredAlpha = hover?.alpha ?: m3.hoveredAlpha,
            pressedAlpha = splash?.alpha ?: m3.pressedAlpha,
        ),
    )
}

/**
 * Flutter's gesture timing for [content]: a long press after Flutter's
 * kLongPressTimeout, 500 ms (gestures/constants.dart:29), where Compose
 * takes the platform's (400 on Android 12 and later); the rest of the view
 * configuration is the current one. Around the builders that keep
 * Flutter's own timing (IconButton, FloatingActionButton and
 * [InkWellWidget]); [ButtonWidget] and [GestureDetectorWidget] still take
 * the platform's.
 */
@Composable
internal fun FlutterGestureTiming(content: @Composable () -> Unit) {
    val platform = LocalViewConfiguration.current
    val flutter = remember(platform) { FlutterViewConfiguration(platform) }
    CompositionLocalProvider(LocalViewConfiguration provides flutter, content = content)
}

/** [platform] with Flutter's long-press timeout. */
private class FlutterViewConfiguration(platform: ViewConfiguration) : ViewConfiguration by platform {
    override val longPressTimeoutMillis: Long get() = 500L
}

/**
 * Material 3's FloatingActionButton as it draws at rest, without its
 * clickable, for a disabled FAB: no click or long press, disabled to
 * accessibility, the same look. Mirrors androidx.compose.material3 1.4.0
 * FloatingActionButton.kt (its `Surface`: shape, colours, tonal and shadow
 * elevation; the labelLarge text style; the content centred in a Box at
 * least 56 square; the small one at least 40) and the clickable Surface's
 * `minimumInteractiveComponentSize`. The public non-clickable Surface is
 * hit and consumes nothing, as Flutter's Material takes the hit and a
 * GestureDetector around it still gets the tap. Re-check it when the BOM
 * moves material3.
 */
@Composable
private fun InertFab(
    modifier: Modifier,
    mini: Boolean,
    shape: Shape,
    fill: Color,
    ink: Color,
    elevation: Dp,
    content: @Composable () -> Unit,
) {
    Surface(
        modifier = (if (mini) modifier.sizeIn(minWidth = 40.dp, minHeight = 40.dp) else modifier)
            .semantics {
                role = Role.Button
                disabled()
            }
            .minimumInteractiveComponentSize(),
        shape = shape,
        color = fill,
        contentColor = ink,
        tonalElevation = elevation,
        shadowElevation = elevation,
    ) {
        CompositionLocalProvider(LocalTextStyle provides LocalTextStyle.current.merge(MaterialTheme.typography.labelLarge)) {
            Box(Modifier.defaultMinSize(minWidth = 56.dp, minHeight = 56.dp), contentAlignment = Alignment.Center) {
                content()
            }
        }
    }
}
