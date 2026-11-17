package com.orcagateway.sdk.widgets

import android.view.WindowManager
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerInputScope
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.findRootCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.toSize
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.window.PopupProperties
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.TooltipPlacement
import com.orcagateway.core.render.TooltipRect
import com.orcagateway.core.render.TooltipSize
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Flutter `Tooltip` (`_buildTooltip`, layout_builders.dart:583-586):
 * Material's Tooltip with its defaults around the child, the bubble drawn
 * by the SDK ([TooltipBubble]). An empty message draws the child alone
 * (tooltip.dart:503-505). Otherwise the box takes a press anywhere in it
 * (RawTooltip's opaque Listener, raw_tooltip.dart:958-962), unless under
 * [LocalPointerBlocked], and its message is the box's accessibility label
 * ([tooltip]).
 *
 * A hold on a child with a long press of its own shows the bubble and runs
 * the child's too; in Flutter the child's recognizer, deeper, starts its
 * timer first and wins the arena, so no bubble shows (binding.dart:506,
 * recognizer.dart:701-708, long_press.dart:641-643). Compose has no arena:
 * a known difference, the buttons here aside ([IconButtonWidget]).
 */
@Composable
internal fun TooltipWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val message = Props.text(node["message"])
    val tip = rememberTooltip()
    if (message.isEmpty()) {
        ChildView(node, model, modifier)
        return
    }
    Box(modifier.tooltip(tip, message, armed = !LocalPointerBlocked.current), propagateMinConstraints = true) {
        ChildView(node, model)
        TooltipBubble(tip, message)
    }
}

/** A tooltip's state, its timer and fade run on the composition's scope, placed in [LocalTooltipOverlay]. */
@Composable
internal fun rememberTooltip(): TooltipState {
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    val area = LocalTooltipOverlay.current
    return remember(scope, haptics, area) { TooltipState(scope, haptics, area) }
}

/**
 * The area the bubbles in it are placed in: Flutter's nearest Overlay, the
 * Navigator of the tooltip's route (OverlayPortal's default,
 * raw_tooltip.dart:965-969, overlay.dart:1941-1945). Under tabs that is the
 * tab's Navigator (navigation_handler.dart:92), which ends at the tab bar.
 * Given by the page's [DialogLayer], the route's area here; without one the
 * whole root.
 */
@Stable
internal class TooltipOverlay {
    /** The area in the root, in pixels; null before it is laid out. */
    var bounds by mutableStateOf<Rect?>(null)
        private set

    fun place(coordinates: LayoutCoordinates) {
        bounds = Rect(coordinates.positionInRoot(), coordinates.size.toSize())
    }
}

/** The [TooltipOverlay] of the route around, if any. */
internal val LocalTooltipOverlay = compositionLocalOf<TooltipOverlay?> { null }

/**
 * The box a tooltip of [message] wraps (null or empty: none, as Flutter adds
 * no Tooltip): the message as its accessibility label, Flutter's
 * `Semantics(tooltip:)` (raw_tooltip.dart:949-952), which its Android
 * bridge gives TalkBack as the content description of a node with no label
 * of its own and as its tooltip text, a property Compose has not
 * (BaseRoleConfigurator.java:360-378); where the box is, for the bubble;
 * and when [armed], the hold that shows the bubble ([watchLongPress]).
 */
internal fun Modifier.tooltip(tip: TooltipState, message: String?, armed: Boolean = true): Modifier {
    if (message.isNullOrEmpty()) return this
    val placed = semantics { contentDescription = message }.onGloballyPositioned(tip::place)
    return if (armed) placed.pointerInput(tip) { watchLongPress(tip) } else placed
}

/**
 * The bubble of a tooltip of [message] while it shows, anywhere inside the
 * box [tooltip] marks: Material's `_TooltipBox` (tooltip.dart:589-628) in
 * the light theme (:524-538, :450-466): grey[700] at 0.9, corners of 4,
 * bodyMedium in white at 14, padding 16 x 4, at least 32 high, laid out
 * within the overlay (`constraints.loosen()`, raw_tooltip.dart:993), its
 * opacity fastOutSlowIn of the fade (:27-31). Placed by [TooltipPlacement]
 * in the route's area ([TooltipOverlay]), less what of the keyboard is over
 * its bottom (:896-897).
 *
 * In a popup window of its own, above the page, the sheet layer and the
 * snackbar bar. Flutter's is in that Overlay in front of the page's route:
 * above its sheet and bar too, but under tabs below the shell's bar and
 * drawer. The window takes no touches and no focus, so a touch on the
 * bubble reaches what is under it (Material's IgnorePointer, tooltip.dart
 * :579-580), and it is told of every touch outside it ([BUBBLE_WINDOW]).
 */
@Composable
internal fun TooltipBubble(tip: TooltipState, message: String?) {
    if (message.isNullOrEmpty() || !tip.visible) return
    val density = LocalDensity.current
    val keyboard = WindowInsets.ime.getBottom(density)
    SideEffect { tip.keyboard = keyboard }
    val position = remember(tip, density) { BubblePosition(tip, density) }
    Popup(position, onDismissRequest = tip::touchedOutside, properties = BUBBLE_WINDOW) {
        val overlay = tip.overlay
        Box(
            Modifier.testTag(TOOLTIP_BUBBLE_TAG)
                .sizeIn(maxWidth = with(density) { overlay.width.toDp() }, maxHeight = with(density) { overlay.height.toDp() })
                .graphicsLayer { alpha = FastOutSlowInEasing.transform(tip.progress.value) }
                .heightIn(min = 32.dp)
                .background(BUBBLE_FILL, RoundedCornerShape(4.dp))
                .padding(horizontal = 16.dp, vertical = 4.dp),
            contentAlignment = Alignment.Center,
        ) {
            BasicText(message, style = BUBBLE_TEXT)
        }
    }
}

/**
 * Flutter's RawTooltipState on a touch screen with Material's defaults: the
 * bubble shown by a hold, kept while held, gone [TooltipPlacement.SHOW_DURATION]
 * after the release or at once at any other touch; the fade of
 * [TooltipPlacement.FADE_IN] and [TooltipPlacement.FADE_OUT] ms; where the
 * child is in the page and the [area] it is placed in.
 */
@Stable
internal class TooltipState(
    private val scope: CoroutineScope,
    private val haptics: HapticFeedback,
    private val area: TooltipOverlay?,
) {
    /** Flutter's controller value, run linearly: 0 gone, 1 shown. */
    val progress = Animatable(0f)

    /** Showing or on its way (the controller forward or completed). */
    private var forward by mutableStateOf(false)

    val visible: Boolean by derivedStateOf { forward || progress.value > 0f }

    /** The child's box in the page (the composition's root), in pixels. */
    private var child by mutableStateOf(Rect.Zero)

    private var page by mutableStateOf(IntSize.Zero)

    /** Where the page is in its window. */
    private var pageInWindow by mutableStateOf(Offset.Zero)

    /** The keyboard's height over the page's bottom, in pixels. */
    var keyboard by mutableIntStateOf(0)

    /** The overlay the bubble is placed in, in the page: the route's area (the page without one) above the keyboard. */
    val overlay: Rect
        get() {
            val whole = area?.bounds ?: Rect(Offset.Zero, page.toSize())
            return whole.copy(bottom = max(whole.top, min(whole.bottom, (page.height - keyboard).toFloat())))
        }

    /** A press on the child, the Tooltip's own long-press pointer, is down. */
    var pressing = false

    private var timer: Job? = null

    fun place(coordinates: LayoutCoordinates) {
        val inPage = coordinates.positionInRoot()
        child = Rect(inPage, coordinates.size.toSize())
        page = coordinates.findRootCoordinates().size
        pageInWindow = coordinates.positionInWindow() - inPage
    }

    /** The bubble's window in the page's window: [TooltipPlacement] in dp in the [overlay], from the child and [bubble]. */
    fun origin(bubble: IntSize, density: Density): IntOffset {
        val d = density.density.toDouble()
        val inside = overlay
        val at = TooltipPlacement.origin(
            TooltipRect((child.left - inside.left) / d, (child.top - inside.top) / d, child.width / d, child.height / d),
            TooltipSize(bubble.width / d, bubble.height / d),
            TooltipSize(inside.width / d, inside.height / d),
        )
        val x = pageInWindow.x + inside.left + at.x * d
        val y = pageInWindow.y + inside.top + at.y * d
        return IntOffset(x.roundToInt(), y.roundToInt())
    }

    /** `_handleLongPress` (raw_tooltip.dart:752-760): a long-press haptic if it was gone, then shown, no timer. */
    fun longPressed() {
        if (!forward && progress.value == 0f) haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        timer?.cancel()
        fade(true)
    }

    /** `_handlePressUp` (:762-767): gone [TooltipPlacement.SHOW_DURATION] after the release. */
    fun released() {
        timer?.cancel()
        timer = scope.launch {
            delay(TooltipPlacement.SHOW_DURATION)
            fade(false)
        }
    }

    /** `_handleTapToDismiss` (:728-734): the timer off, and gone now. */
    fun dismiss() {
        timer?.cancel()
        if (forward) fade(false)
    }

    /**
     * A touch outside the bubble's window. A press on the child is the
     * Tooltip's own (the global route lets its pointer by, :706-724): the
     * child sees it within the frame, so this waits one.
     */
    fun touchedOutside() {
        scope.launch {
            withFrameMillis { }
            if (!pressing) dismiss()
        }
    }

    /** The controller forward or in reverse from where it is, at its share of the fade's time. */
    private fun fade(show: Boolean) {
        forward = show
        scope.launch {
            val ms = if (show) (1f - progress.value) * TooltipPlacement.FADE_IN else progress.value * TooltipPlacement.FADE_OUT
            progress.animateTo(if (show) 1f else 0f, tween(ms.roundToInt(), easing = LinearEasing))
        }
    }
}

/**
 * The Tooltip's LongPressGestureRecognizer (raw_tooltip.dart:684-690): a
 * press held [TooltipPlacement.LONG_PRESS] ms within [TOUCH_SLOP] of where
 * it went down shows the bubble, then the rest of the gesture is the
 * Tooltip's (it won the arena: the child's tap does not fire) and the
 * release starts the timer; one let go or moved sooner hides it. Watched
 * on the initial pass, ahead of the child.
 */
private suspend fun PointerInputScope.watchLongPress(tip: TooltipState) {
    val slop = TOUCH_SLOP.dp.toPx()
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
        tip.pressing = true
        try {
            val cut = withTimeoutOrNull(TooltipPlacement.LONG_PRESS) {
                do {
                    val change = awaitPointerEvent(PointerEventPass.Initial).changes.firstOrNull { it.id == down.id }
                } while (change != null && change.pressed && (change.position - down.position).getDistance() <= slop)
            }
            if (cut != null) {
                tip.dismiss()
            } else {
                tip.longPressed()
                do {
                    val event = awaitPointerEvent(PointerEventPass.Initial)
                    event.changes.forEach { it.consume() }
                } while (event.changes.any { it.pressed })
                tip.released()
            }
        } finally {
            tip.pressing = false
        }
    }
}

/** The bubble's window placed by [TooltipState.origin], read from state: it moves when the child, the page or the keyboard does. */
private class BubblePosition(private val tip: TooltipState, private val density: Density) : PopupPositionProvider {
    override fun calculatePosition(
        anchorBounds: IntRect,
        windowSize: IntSize,
        layoutDirection: LayoutDirection,
        popupContentSize: IntSize,
    ): IntOffset = tip.origin(popupContentSize, density)
}

/** The test tag of the bubble, in its window. */
internal const val TOOLTIP_BUBBLE_TAG: String = "orca-tooltip-bubble"

/** `kTouchSlop` (gestures/constants.dart:65): RawTooltip's recognizer takes no device settings (raw_tooltip.dart:685, recognizer.dart:668). */
private const val TOUCH_SLOP = 18

/** grey[700] at 0.9 (tooltip.dart:534-536). */
private val BUBBLE_FILL = Color(0xE6616161)

/**
 * ThemeData()'s bodyMedium in white at 14 (tooltip.dart:530-533): 14 on 20,
 * weight 400, tracking 0.25, the line's spare height even above and below
 * (typography_defaults_m3.g.dart:142-151), on Material 3's bodyMedium (whose
 * tracking is 0.2).
 */
private val BUBBLE_TEXT = Typography().bodyMedium.copy(color = Color.White, letterSpacing = 0.25.sp)

/**
 * A window that takes neither touches nor focus, is told of each touch
 * outside it (which hides the bubble), goes where it is placed even by the
 * screen's edges, and leaves Back and the system gestures alone.
 */
private val BUBBLE_WINDOW = PopupProperties(
    flags = WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
    dismissOnBackPress = false,
    excludeFromSystemGesture = false,
)
