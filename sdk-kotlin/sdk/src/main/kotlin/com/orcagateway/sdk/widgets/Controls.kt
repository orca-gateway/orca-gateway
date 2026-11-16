package com.orcagateway.sdk.widgets

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderState
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableFloatState
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.FormControls
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WithColorScheme
import com.orcagateway.sdk.style.Props
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.math.roundToInt

/*
 * Flutter's Switch, Slider and Form (`_buildSwitch` and `_buildSlider`,
 * input_builders.dart; `_buildForm`, layout_builders.dart). As the
 * selection controls, neither control remembers a value of its own: what is
 * drawn is the store at `stateKey`, else the `value` prop, and the node
 * redraws only through its watches. A change goes through [edit]: the
 * stateKey write in page scope, then `onChange` with `{value}`.
 * TextFormField has no builder of its own: Flutter's is a copy of
 * TextField's, so [TextFieldWidget] draws it.
 */

/**
 * Flutter `Switch` without a label: Material 3's `Switch` in the app's
 * theme (Flutter's bare Switch takes no Theme wrapper), checked when the
 * value is `true` (anything else, or none, is off). Flutter's colour
 * mapping: `activeColor` is the checked thumb (`activeThumbColor`) and,
 * at alpha 0x80, the checked track (Switch's fallback when no track colour
 * is themed; without `activeColor` it stays primary); `inactiveColor` the
 * unchecked track (`inactiveTrackColor`), disabled too (Flutter's widget
 * track colour ignores the disabled state, and Material's disabled opacity
 * is 1). A tap sends the other bool. `enabled` false greys the rest as
 * Material does and takes no taps; without `onChange` it still takes them
 * and writes its `stateKey`. (The engine's Switch sends no `label`, so
 * Flutter's SwitchListTile path is not drawn.)
 */
@Composable
internal fun SwitchWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val active = Props.color(node["activeColor"])
    val inactive = Props.color(node["inactiveColor"])
    val colors = SwitchDefaults.colors().copy(
        checkedThumbColor = active ?: Color.Unspecified,
        checkedTrackColor = active?.copy(alpha = 0x80 / 255f) ?: Color.Unspecified,
        uncheckedTrackColor = inactive ?: Color.Unspecified,
        disabledUncheckedTrackColor = inactive ?: Color.Unspecified,
    )
    Switch(
        checked = pageValue(node, model)?.boolValue ?: false,
        onCheckedChange = { next -> edit(node, model, JsonValue.Bool(next)) },
        modifier = modifier,
        enabled = node["enabled"]?.boolValue ?: true,
        colors = colors,
    )
}

/**
 * Flutter `Slider`: Material 3's `Slider` (its gestures, semantics and
 * layout) drawn in Flutter's default 2023 look in `ThemeData()`'s light
 * colours, over `min` (0) to `max` (1), in `divisions` stops when above 0
 * (Compose's `steps` = divisions - 1). It draws the value (a number at
 * `stateKey`, else the `value` prop, else 0) clamped to the range, and
 * snapped to its stop when discrete, without correcting the state. A
 * press sends the value under the finger on the down (Flutter's
 * `_startInteraction`; a discrete one read through Flutter's padded track,
 * (x - left - h / 2) / (width - h)), then each drag update, and a
 * setProgress, the value
 * snapped as Flutter's `_lerp` ([FormControls.sliderValue]), a double, and
 * only when it is not the one last sent in this interaction nor the one the
 * Slider was built with, unsnapped (Flutter's `_handleChanged`); right to
 * left, the track and the finger are mirrored. A reversed range is drawn
 * as `min`..`min` (Flutter's builder throws in `clamp`); an empty one
 * (max = min) sends nothing and shows no overlay or label, as Flutter's is
 * not interactive.
 *
 * The 2023 look (`_SliderDefaultsM3Year2023` and the round shapes,
 * slider.dart and slider_parts.dart): 48 high, the track inset 24 on each
 * side; the inactive part `trackHeight` (4) high, the active part 2 higher,
 * both with round ends running half the track height past the thumb's
 * centre, which for a discrete slider is inset half the track height at
 * the end stops (left + v x (w - h) + h / 2: its thumb slot is 48 + h wide,
 * so Compose's own taps, drags and stops follow the same padded track), and
 * for a continuous one on a track higher than the thumb's radius (10) is
 * kept h / 2 inside the track's ends (`_calcThumbCenter`); tick marks
 * for a discrete slider, circles a quarter of `trackHeight` in radius at
 * i / d of the track less its height, dropped when closer than 3 tick
 * widths; a 20 dp round thumb at elevation 1, 6
 * while a finger is down, under which an overlay of radius 24 grows in
 * 100 ms. Colours: `activeColor` (else primary) the active track, the
 * ticks right of the thumb, the thumb without `thumbColor`, the overlay at
 * 0.12 (else primary at 0.1 while a finger is down, Flutter's `_dragging`
 * being set as any interaction starts) and the value indicator;
 * `inactiveColor` (else surfaceContainerHighest) the inactive track and
 * the ticks left of the thumb (else onPrimary and onSurfaceVariant at
 * 0.38); disabled, onSurface at 0.38 and 0.12, the thumb onSurface at 0.38
 * over surface. With `label`, a discrete slider with a range shows Flutter's
 * drop value indicator while a finger is down and at least 500 ms from the
 * press (`_minimumInteractionTime`), scaling in and out in 100 ms (a new
 * press rises from where it is, as `forward()`): a pill
 * 28 high spanning 22 to 50 above the thumb's centre, as wide as the label
 * (at least 20) and 8, the label in labelMedium onPrimary, a triangle down
 * to 16 above the centre. `enabled` false greys it and takes nothing;
 * without `onChange` it still writes its `stateKey`.
 *
 * What does not match Flutter: the thumb's shadow is Compose's for the
 * elevation, not Flutter's `drawShadow`; the value indicator is drawn with
 * the slider, not in Flutter's Overlay, so later siblings paint over it and
 * it is not shifted to stay 8 dp inside the screen; with a state between
 * stops (30 on 0-100 in 4, drawn at 25) and a node not watching its key, a
 * DRAG back onto the drawn stop sends nothing, where Flutter sends 25:
 * Compose filters drag values against its own snapped value (25), Flutter
 * against the unsnapped 30. A down on that stop sends 25 in both, as the
 * down here compares with the unsnapped value too.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SliderWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val enabled = node["enabled"]?.boolValue ?: true
    val min = Props.number(node["min"]) ?: 0.0
    val max = (Props.number(node["max"]) ?: 1.0).coerceAtLeast(min)
    val divisions = node["divisions"]?.intValue?.takeIf { it > 0 }?.coerceAtMost(Int.MAX_VALUE.toLong())?.toInt()
    val drawn = (pageValue(node, model)?.doubleValue ?: 0.0).coerceIn(min, max)
    val shown = if (divisions == null) {
        drawn
    } else {
        FormControls.sliderValue(FormControls.sliderFraction(drawn, min, max), min, max, divisions)
    }
    val interactive = enabled && max > min
    val label = node["label"]?.stringValue?.takeIf { divisions != null && interactive }
    val trackHeight = Props.length(node["trackHeight"]) ?: 4.dp
    val sent = remember { arrayOfNulls<Double>(1) }
    val press = remember { Press() }
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    // One change at [fraction] of the track, deduped as Flutter's _handleChanged.
    val change: (Double) -> Unit = { fraction ->
        val next = FormControls.sliderValue(fraction, min, max, divisions)
        if (enabled && next != sent[0]) {
            sent[0] = next
            if (next != drawn) edit(node, model, JsonValue.Double(next))
        }
    }
    val onDown = rememberUpdatedState<(Double) -> Unit> { fraction ->
        sent[0] = null
        change(fraction)
    }
    // A discrete thumb slot is h wider: Compose then lays out, maps and snaps along Flutter's padded track.
    val slot = if (divisions == null) THUMB_SLOT else THUMB_SLOT + trackHeight
    val activation by animateFloatAsState(
        if (interactive && press.down) 1f else 0f,
        tween(REACTION_MS, easing = FastOutSlowInEasing),
        label = "overlay",
    )
    val indicator = remember { mutableFloatStateOf(0f) }
    LaunchedEffect(press.count, label != null) {
        if (press.count == 0 || label == null) {
            indicator.floatValue = 0f
            return@LaunchedEffect
        }
        indicator.showValueIndicator(press)
    }

    WithColorScheme(flutterLight) {
        val look = sliderLook(node, enabled, press.down)
        Slider(
            value = shown.toFloat(),
            onValueChange = { raw -> change(FormControls.sliderFraction(raw.toDouble(), min, max)) },
            modifier = if (interactive) modifier.whilePressed(press, rtl, slot / 2, onDown) else modifier,
            enabled = enabled,
            onValueChangeFinished = { sent[0] = null },
            steps = divisions?.let { it - 1 } ?: 0,
            thumb = { state ->
                val scale = FastOutSlowInEasing.transform(indicator.floatValue)
                FlutterThumb(look, activation, label, scale, state, slot, trackHeight.takeIf { divisions == null })
            },
            track = { state -> FlutterTrack(state, look, trackHeight, divisions) },
            valueRange = min.toFloat()..max.toFloat(),
        )
    }
}

/**
 * The value indicator's progress (0 to 1, drawn eased), set here for the
 * press [press] began, Flutter's `valueIndicatorController` with the
 * `_minimumInteractionTime` timer: up in 100 ms from the down, rising from
 * where it is (`forward()`), held while the finger is down and at least
 * 500 ms from the down, then down in 100 ms, timed from the pointer events
 * (frames only while it moves). Returns once it is gone (0).
 */
private suspend fun MutableFloatState.showValueIndicator(press: Press) {
    val downAt = press.downAt
    val from = floatValue
    var now = withFrameMillis { it }
    while (from + (now - downAt) / REACTION_MS.toFloat() < 1f) {
        floatValue = (from + (now - downAt) / REACTION_MS.toFloat()).coerceIn(0f, 1f)
        now = withFrameMillis { it }
    }
    floatValue = 1f
    snapshotFlow { press.down }.first { !it }
    val hideAt = maxOf(downAt + MINIMUM_INTERACTION_MS, press.upAt)
    now = withFrameMillis { it }
    if (now < hideAt) {
        delay(hideAt - now)
        now = withFrameMillis { it }
    }
    // Gone at its end time, not at the first frame after it.
    withTimeoutOrNull(hideAt + REACTION_MS - now) {
        while (true) {
            floatValue = 1f - ((now - hideAt) / REACTION_MS.toFloat()).coerceIn(0f, 1f)
            now = withFrameMillis { it }
        }
    }
    floatValue = 0f
}

/** The colours a Slider is drawn in, Flutter's `SliderThemeData` after the widget's own. */
private class SliderLook(
    val activeTrack: Color,
    val inactiveTrack: Color,
    val activeTick: Color,
    val inactiveTick: Color,
    val thumb: Color,
    val overlay: Color,
    val indicator: Color,
    val indicatorText: Color,
)

/** Flutter's `_buildMaterialSlider` colours over `_SliderDefaultsM3Year2023`, in the current scheme. */
@Composable
private fun sliderLook(node: ResolvedNode, enabled: Boolean, pressed: Boolean): SliderLook {
    val scheme = MaterialTheme.colorScheme
    val active = Props.color(node["activeColor"])
    val inactive = Props.color(node["inactiveColor"])
    val indicator = active ?: scheme.primary
    if (!enabled) {
        val strong = scheme.onSurface.copy(alpha = 0.38f)
        return SliderLook(
            activeTrack = strong,
            inactiveTrack = scheme.onSurface.copy(alpha = 0.12f),
            activeTick = strong,
            inactiveTick = strong,
            thumb = strong.compositeOver(scheme.surface),
            overlay = Color.Transparent,
            indicator = indicator,
            indicatorText = scheme.onPrimary,
        )
    }
    return SliderLook(
        activeTrack = active ?: scheme.primary,
        inactiveTrack = inactive ?: scheme.surfaceContainerHighest,
        activeTick = inactive ?: scheme.onPrimary.copy(alpha = 0.38f),
        inactiveTick = active ?: scheme.onSurfaceVariant.copy(alpha = 0.38f),
        thumb = Props.color(node["thumbColor"]) ?: active ?: scheme.primary,
        overlay = active?.copy(alpha = 0.12f) ?: if (pressed) scheme.primary.copy(alpha = 0.1f) else Color.Transparent,
        indicator = indicator,
        indicatorText = scheme.onPrimary,
    )
}

/**
 * The thumb slot, [slot] x 48 so the track is inset half of it as
 * Flutter's: the overlay (radius 24 at [activation] 1), the 20 dp round
 * thumb at elevation 1 to 6, and the value indicator at [indicator] scale.
 * For a continuous Slider [continuousTrack] is its track height, and the
 * slot is moved along the track where Flutter clamps the thumb
 * ([thumbCentre]); the track's length is the Slider's width (the width the
 * slot may take) less the slot.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FlutterThumb(
    look: SliderLook,
    activation: Float,
    label: String?,
    indicator: Float,
    state: SliderState,
    slot: Dp,
    continuousTrack: Dp?,
) {
    Box(
        Modifier.layout { measurable, constraints ->
            val placeable = measurable.measure(Constraints.fixed(slot.roundToPx(), THUMB_SLOT.roundToPx()))
            val shift = if (continuousTrack == null || !constraints.hasBoundedWidth) {
                0
            } else {
                val w = constraints.maxWidth - slot.toPx()
                val v = state.coercedValueAsFraction
                (thumbCentre(v, w, continuousTrack.toPx(), THUMB_DIAMETER.toPx() / 2) - v * w).roundToInt()
            }
            layout(placeable.width, placeable.height) { placeable.placeRelative(shift, 0) }
        },
        contentAlignment = Alignment.Center,
    ) {
        if (activation > 0f) Box(Modifier.size(THUMB_SLOT * activation).background(look.overlay, CircleShape))
        Spacer(
            Modifier
                .size(THUMB_DIAMETER)
                .shadow((1f + 5f * activation).dp, CircleShape)
                .background(look.thumb, CircleShape),
        )
        if (label != null && indicator > 0f) ValueIndicator(label, look, indicator)
    }
}

/**
 * Flutter's `RoundedRectSliderTrackShape` (the active part 2 higher) and
 * `RoundSliderTickMarkShape`, around the thumb's centre as Flutter puts it
 * (v x (w - h) + h / 2 when discrete, else v x w clamped by [thumbCentre]),
 * mirrored right to left. A discrete track's box is h shorter than
 * Flutter's track (its thumb slot is h wider), so it draws h / 2 past each
 * of its ends.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FlutterTrack(state: SliderState, look: SliderLook, height: Dp, divisions: Int?) {
    Canvas(Modifier.fillMaxWidth().height(height + ACTIVE_EXTRA)) {
        val h = height.toPx()
        if (h <= 0f) return@Canvas
        val half = h / 2
        val pad = if (divisions == null) 0f else half
        val w = size.width + 2 * pad
        val cy = size.height / 2
        val extra = ACTIVE_EXTRA.toPx() / 2
        val v = state.coercedValueAsFraction
        val thumb = if (divisions == null) thumbCentre(v, w, h, THUMB_DIAMETER.toPx() / 2) else v * (w - h) + half
        scale(if (layoutDirection == LayoutDirection.Rtl) -1f else 1f, 1f) {
            translate(left = -pad) {
            if (thumb < w - half) {
                drawRoundRect(look.inactiveTrack, Offset(thumb - half, cy - half), Size(w - thumb + half, h), CornerRadius(half))
            }
            if (thumb > half) {
                drawRoundRect(look.activeTrack, Offset(0f, cy - half - extra), Size(thumb + half, h + 2 * extra), CornerRadius(half + extra))
            }
            if (divisions == null) return@translate
            val radius = h / 4
            val span = w - h
            if (span / divisions < 3 * 2 * radius) return@translate
            for (i in 0..divisions) {
                val x = i.toFloat() / divisions * span + half
                drawCircle(if (x > thumb) look.inactiveTick else look.activeTick, radius, Offset(x, cy))
            }
            }
        }
    }
}

/**
 * Flutter's `_calcThumbCenter` for a continuous Slider: v x [w] along the
 * track, kept [h] / 2 inside its ends when the track is higher than the
 * thumb's [radius].
 */
private fun thumbCentre(v: Float, w: Float, h: Float, radius: Float): Float {
    val centre = v * w
    if (h <= radius || w <= h) return centre
    return centre.coerceIn(h / 2, w - h / 2)
}

/**
 * Flutter's `DropSliderValueIndicatorShape` over the thumb's centre, laid
 * out as 0 x 0 there so it takes no room: a pill [PILL_HEIGHT] high from
 * [INDICATOR_TOP] above the centre, as wide as the label (at least 20) and
 * 8, and a triangle down to [INDICATOR_TIP] above it, scaled about the tip.
 */
@Composable
private fun ValueIndicator(label: String, look: SliderLook, scale: Float) {
    Layout(
        content = { Text(label, color = look.indicatorText, style = MaterialTheme.typography.labelMedium) },
        modifier = Modifier
            .layout { measurable, _ ->
                val placeable = measurable.measure(Constraints())
                layout(0, 0) { placeable.place(-placeable.width / 2, -INDICATOR_TOP.roundToPx()) }
            }
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin(0.5f, 1f)
            }
            .drawBehind {
                val pill = PILL_HEIGHT.toPx()
                drawRoundRect(look.indicator, size = Size(size.width, pill), cornerRadius = CornerRadius(pill / 2))
                val side = INDICATOR_TRIANGLE.toPx()
                val tip = Offset(size.width / 2, size.height)
                val triangle = Path().apply {
                    moveTo(tip.x, tip.y)
                    lineTo(tip.x - side, tip.y - side)
                    lineTo(tip.x + side, tip.y - side)
                    close()
                }
                drawPath(triangle, look.indicator)
            },
    ) { measurables, _ ->
        val text = measurables.first().measure(Constraints())
        val width = maxOf(INDICATOR_MIN_LABEL.roundToPx(), text.width) + INDICATOR_PADDING.roundToPx()
        val height = (INDICATOR_TOP - INDICATOR_TIP).roundToPx()
        layout(width, height) { text.place((width - text.width) / 2, (PILL_HEIGHT.roundToPx() - text.height) / 2) }
    }
}

/**
 * A finger down on a Slider (Flutter's `_active`), how many presses began,
 * and when the last one went down and up (pointer event times), for the
 * label's minimum time.
 */
private class Press {
    var down by mutableStateOf(false)
    var count by mutableIntStateOf(0)
    var downAt = 0L
    var upAt = 0L
}

/**
 * [press] down while a finger is on this node, watched before the slider's
 * own gestures take it; on the down, [onDown] gets where along the track
 * the finger is (from [inset], half the thumb slot, on each side, as
 * Compose's drag and Flutter's padded track), 0 to 1 from the start (a
 * half on a track with no length), mirrored right to left.
 */
private fun Modifier.whilePressed(press: Press, rtl: Boolean, inset: Dp, onDown: State<(Double) -> Unit>): Modifier = pointerInput(press, rtl, inset) {
    awaitEachGesture {
        val first = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
        var last = first.uptimeMillis
        press.downAt = last
        press.down = true
        press.count += 1
        val start = inset.toPx()
        val span = size.width - 2 * start
        val along = if (span > 0f) ((first.position.x - start) / span).coerceIn(0f, 1f) else 0.5f
        onDown.value((if (rtl) 1f - along else along).toDouble())
        try {
            do {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                last = event.changes.maxOf { it.uptimeMillis }
            } while (event.changes.any { it.pressed })
        } finally {
            press.upAt = last
            press.down = false
        }
    }
}

/** Flutter `_buildForm`: its one child, nothing of its own (no validation, no save). */
@Composable
internal fun FormWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    ChildView(node, model, modifier)
}

/** Flutter's `ThemeData()` colours, which its Slider is drawn in. */
private val flutterLight = lightColorScheme()

/** The thumb slot: the overlay's diameter, Flutter's track inset on each side being half of it. */
private val THUMB_SLOT = 48.dp

/** `RoundSliderThumbShape`'s enabled (and disabled) radius 10. */
private val THUMB_DIAMETER = 20.dp

/** `RoundedRectSliderTrackShape`'s `additionalActiveTrackHeight`. */
private val ACTIVE_EXTRA = 2.dp

/** The drop indicator (`_DropSliderValueIndicatorPathPainter`): the pill's top above the thumb's centre. */
private val INDICATOR_TOP = 50.dp

/** The drop's tip above the thumb's centre (`_bottomTipYOffset`). */
private val INDICATOR_TIP = 16.dp

/** The pill's height (`_minRectHeight`), fully round. */
private val PILL_HEIGHT = 28.dp

/** The triangle's height and half base (`_triangleHeight`). */
private val INDICATOR_TRIANGLE = 10.dp

/** The narrowest label the pill is sized for (`_minLabelWidth`). */
private val INDICATOR_MIN_LABEL = 20.dp

/** The pill's width beyond the label (`_labelPadding`). */
private val INDICATOR_PADDING = 8.dp

/** `kRadialReactionDuration` and `valueIndicatorAnimationDuration`. */
private const val REACTION_MS = 100

/** Flutter's `_minimumInteractionTime`: the label stays at least this long from a press. */
private const val MINIMUM_INTERACTION_MS = 500L
