package com.orcagateway.sdk.widgets

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.exclude
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableIntState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.dismiss
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.orcagateway.sdk.OrcaSnackbarQueue
import com.orcagateway.sdk.OrcaToast
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * [queue]'s bar where Flutter's `_ScaffoldLayout` lays a fixed one
 * ([SnackbarBar]; scaffold.dart:1236-1237, :1340-1352), over all the space
 * it is given: the whole width, its bottom at Flutter's contentBottom, on
 * the bars when [onBars] (the bottom bar and footer row, [padding]'s
 * bottom), else on the bottom edge with the safe area inside the bar (the
 * bars take it: :3273-3283), and on the keyboard when that is higher
 * (:1173-1176), the safe area it covers left out. Drawn after a Scaffold's
 * body and bottom sheet, it paints over them; a Material 3 Scaffold draws
 * its bars and floating button over it (:3257-3361). [lift] gets how far a
 * floating button standing 16 over [padding]'s bottom (M3's) must rise to
 * stand 16 over the bar.
 */
@Composable
internal fun SnackbarLayer(queue: OrcaSnackbarQueue, padding: PaddingValues, onBars: Boolean, lift: MutableIntState? = null) {
    val sides = if (onBars) WindowInsetsSides.Horizontal else WindowInsetsSides.Horizontal + WindowInsetsSides.Bottom
    // Flutter's SafeArea reads MediaQuery's padding: the system bars and the cutout, less what the keyboard covers.
    val insets = WindowInsets.systemBars.union(WindowInsets.displayCutout).exclude(WindowInsets.ime).only(sides)
    val keyboard = WindowInsets.ime
    Layout(content = { SnackbarBar(queue, insets) }, modifier = Modifier.fillMaxSize()) { measurables, constraints ->
        val fabFloor = padding.calculateBottomPadding().roundToPx()
        val floor = maxOf(if (onBars) fabFloor else 0, keyboard.getBottom(this))
        val room = maxOf(0, constraints.maxHeight - floor)
        val bar = measurables.firstOrNull()?.measure(Constraints(maxWidth = constraints.maxWidth, maxHeight = room))
        val height = bar?.height ?: 0
        lift?.intValue = if (height > 0) floor + height - fabFloor else 0
        layout(constraints.maxWidth, constraints.maxHeight) {
            bar?.place(0, constraints.maxHeight - floor - height)
        }
    }
}

/**
 * The snackbar at the head of the app's queue as Flutter's Material 3 fixed
 * SnackBar, the one showSnackbar shows (MUI snack_bar.dart on
 * `_SnackbarDefaultsM3`): as wide as it is let be, square, on #322F35, the
 * message in the theme's bodyMedium in #F5EFF7, 24 in from each side and
 * 14 above and below its line (:29, :707-713, :793, :817-818;
 * snackbar_defaults_m3.g.dart:18, :41-42; color_scheme_defaults.g.dart
 * :57-58), [insets] inside it around that (the bottom safe area where no
 * bottom bar took it, :812).
 *
 * Revealed by height, never faded: its box is its height times
 * fastOutSlowIn of the queue's [OrcaSnackbarQueue.reveal], in and out, its
 * top part shown and the rest cut off below (:32, :596, :888-893, a
 * top-start Align in a ClipRect :901). Its Material's elevation 6 casts the
 * platform's shadow in M3's black, which that clip cuts as Flutter's does
 * (clipBehavior hardEdge, :315): none shows past the bar.
 *
 * A drag down moves the bar's content with the finger, inside its box. Let
 * go past 0.4 of its height, or flung down at 700 dp/s or more, it slides
 * off, else back, at 200 ms for the whole way (Flutter's Dismissible,
 * dismissible.dart:19-22, :114, :500-530); off, the queue drops it at once
 * and the next comes in ([OrcaSnackbarQueue.swipe]; snack_bar.dart
 * :859-871). It is a live region whose dismiss action drops it the same way
 * (:852-858). Nothing for an empty queue or a toast at its head (an Android
 * Toast, from [com.orcagateway.sdk.OrcaPageView]).
 */
@Composable
internal fun SnackbarBar(queue: OrcaSnackbarQueue, insets: WindowInsets, modifier: Modifier = Modifier) {
    val head = queue.head?.takeIf { it.style == OrcaToast.Style.Snackbar } ?: return
    // A new head is a new bar: nothing of the last one's drag carries over.
    key(head) { Bar(head.message, queue, insets, modifier) }
}

@Composable
private fun Bar(message: String, queue: OrcaSnackbarQueue, insets: WindowInsets, modifier: Modifier) {
    var drag by remember { mutableFloatStateOf(0f) }
    val height = remember { mutableIntStateOf(0) }
    val fling = with(LocalDensity.current) { DISMISS_FLING_DP_PER_S.dp.toPx() }
    Box(
        modifier
            .testTag(SNACKBAR_BAR_TAG)
            .semantics {
                liveRegion = LiveRegionMode.Polite
                dismiss {
                    queue.swipe()
                    true
                }
            }
            .draggable(
                rememberDraggableState { delta -> drag = maxOf(0f, drag + delta) },
                Orientation.Vertical,
                onDragStopped = { velocity ->
                    val full = height.intValue.toFloat()
                    val off = when {
                        velocity >= fling -> true
                        velocity <= -fling -> false
                        else -> drag > DISMISS_THRESHOLD * full
                    }
                    val to = if (off) full else 0f
                    val ms = if (full > 0f) (MOVE_MS * abs(to - drag) / full).roundToInt() else 0
                    animate(drag, to, animationSpec = tween(ms, easing = LinearEasing)) { value, _ -> drag = value }
                    if (off) queue.swipe()
                },
            )
            .fillMaxWidth()
            .clipToBounds()
            .revealedBy { FastOutSlowInEasing.transform(queue.reveal.toFloat()) },
    ) {
        Box(
            Modifier
                .offset { IntOffset(0, drag.roundToInt()) }
                .onSizeChanged { height.intValue = it.height }
                .fillMaxWidth()
                .shadow(6.dp, RectangleShape)
                .background(SNACKBAR_BACKGROUND)
                .windowInsetsPadding(insets)
                .padding(horizontal = 24.dp, vertical = 14.dp),
        ) {
            Text(message, color = SNACKBAR_CONTENT, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

/**
 * Flutter's `Align(alignment: topStart, heightFactor:)`: the content at its
 * own height at the top, the box [fraction] of that height.
 */
private fun Modifier.revealedBy(fraction: () -> Float): Modifier = layout { measurable, constraints ->
    // [fraction] is read here, in the layout pass: each frame of the slide relayouts the bar and recomposes nothing.
    val content = measurable.measure(constraints.copy(minHeight = 0))
    val height = (content.height * fraction()).roundToInt().coerceIn(constraints.minHeight, constraints.maxHeight)
    layout(content.width, height) { content.place(0, 0) }
}

/** The test tag of the bar, on its revealed box. */
internal const val SNACKBAR_BAR_TAG: String = "orca-snackbar-bar"

/** Flutter's light inverseSurface: the bar. */
private val SNACKBAR_BACKGROUND = Color(0xFF322F35)

/** Flutter's light onInverseSurface: the message. */
private val SNACKBAR_CONTENT = Color(0xFFF5EFF7)

/** How far down, of its height, a let-go bar goes off rather than back (dismissible.dart:22). */
private const val DISMISS_THRESHOLD = 0.4f

/** How fast down a let-go bar goes off wherever it is (dismissible.dart:19). */
private const val DISMISS_FLING_DP_PER_S = 700

/** The time to slide the whole height, off or back (Dismissible's movementDuration, dismissible.dart:114). */
private const val MOVE_MS = 200
