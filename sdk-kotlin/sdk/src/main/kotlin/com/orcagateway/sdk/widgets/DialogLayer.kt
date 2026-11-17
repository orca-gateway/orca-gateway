package com.orcagateway.sdk.widgets

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitVerticalTouchSlopOrCancellation
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.verticalDrag
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.focusTarget
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.findRootCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.dismiss
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.state.DialogSheet
import com.orcagateway.core.state.DialogStack
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import kotlinx.coroutines.CompletableDeferred
import kotlin.math.roundToInt

/**
 * One sheet openDialog opened, and where its panel is: Flutter's
 * ModalBottomSheetRoute (MUI bottom_sheet.dart) as OrcaPage pushes it.
 * Main thread only.
 */
internal class OrcaSheet(val sheet: DialogSheet) {
    /** Completed when the sheet is closed: the openDialog that opened it returns. */
    val closed: CompletableDeferred<Unit> = CompletableDeferred()

    /** Closed, sliding out: it takes no touch and is out of reach of accessibility. Compose state. */
    var leaving: Boolean by mutableStateOf(false)

    /** The route's controller: 0 out, 1 in, linear in time. Compose state. */
    var value: Float by mutableFloatStateOf(0f)

    /**
     * Below it the panel moves with [value], above it on legacyDecelerate:
     * 0 until a drag (the curve whole), 1 during one (the finger), where the
     * drag let go after (Flutter's `Split`, bottom_sheet.dart:737-770).
     * Compose state.
     */
    var split: Float by mutableFloatStateOf(0f)

    /** A finger drags the panel: no run of the controller. Compose state. */
    var dragging: Boolean by mutableStateOf(false)

    /** The panel's height in pixels, as last laid out. */
    var heightPx: Int = 0

    /** Where the panel's top was last placed in the sheet, in pixels: a drag on the panel is measured in the sheet. */
    var topPx: Int = 0

    /** The panel's focus target. */
    val focus: FocusRequester = FocusRequester()

    /** How much of the panel shows, 0..1: [value] through [split] and the curve. */
    val shown: Float
        get() = if (value <= split) value else split + (1f - split) * LegacyDecelerate.transform((value - split) / (1f - split))
}

/**
 * The sheets openDialog opened on one page, bottom first, as Compose
 * state: the core's [DialogStack] and, for each sheet, its waiter and its
 * panel's motion. A closed sheet stays in [sheets] while it slides out.
 * Main thread only.
 */
internal class OrcaDialogs {
    private val stack = DialogStack()

    /** Every sheet drawn, bottom first: the open ones and those sliding out. Compose state. */
    var sheets: List<OrcaSheet> by mutableStateOf(emptyList())
        private set

    /** The open sheet on top: the one closeDialog, a barrier tap, a drag or Back closes. */
    val top: OrcaSheet? get() = sheets.lastOrNull { !it.leaving }

    /** openDialog: the sheet of the Dialog [dialogId] of [nodes] on top, or null when it opens nothing ([DialogStack.open]). */
    fun open(dialogId: String, heightFactor: Double?, nodes: Map<String, ComponentNode>): OrcaSheet? {
        val opened = stack.open(dialogId, heightFactor, nodes) ?: return null
        return OrcaSheet(opened).also { sheets = sheets + it }
    }

    /** closeDialog: the top sheet starts out and its openDialog returns; none open, nothing. */
    fun close(): Unit = leave(stack.close())

    /** A barrier tap, a drag down or Back: as [close], whatever the Dialog's `dismissible` says. */
    fun dismiss(): Unit = leave(stack.dismiss())

    private fun leave(closed: DialogSheet?) {
        val sheet = sheets.firstOrNull { it.sheet === closed } ?: return
        sheet.leaving = true
        sheet.closed.complete(Unit)
    }

    /** [sheet] slid out: it is drawn no more. */
    fun gone(sheet: OrcaSheet) {
        sheets = sheets - sheet
    }

    /** The page is torn down: every sheet goes at once and every openDialog waiting on one returns. */
    fun closeAll() {
        while (stack.close() != null) continue
        val all = sheets
        sheets = emptyList()
        for (sheet in all) sheet.closed.complete(Unit)
    }
}

/**
 * [content] (a page, or a titled route's frame and its page) under the
 * sheets openDialog opened on [model], as Flutter's ModalBottomSheetRoute
 * draws them over the route below on the page's Navigator (OrcaPage's
 * `showModalBottomSheet`, sdk/lib/src/widgets/orca_page.dart:323-374): over
 * everything [content] draws, its Scaffold's AppBar and snackbar bar
 * included; with tabs inside the shell's body, so its tab bar, top bar and
 * snackbar bar stay over it. Null [model]: [content] alone.
 *
 * With [model] the layer's box is also the area the route's tooltips, in
 * the page and in its sheets, place their bubbles in ([LocalTooltipOverlay]),
 * Flutter's nearest Overlay: the route's Navigator, under tabs the tab's.
 *
 * Each sheet is a black54 barrier over the whole layer and, from its bottom
 * edge (no safe area: useSafeArea false), a white panel with top corners
 * of 24 (clipped), [DialogSheet.heightFactor] of the layer's height and as
 * wide as its content, at most 640, centred (only the sheet's Align gets
 * the whole width; its ConstrainedBox, the FractionallySizedBox and the
 * Container leave the width loose: bottom_sheet.dart:417-421, :618-621),
 * drawing the Dialog's subtree with the page's stores and executor
 * (orca_page.dart:346-369; bottom_sheet.dart:1123, :1332-1338,
 * bottom_sheet_defaults_m3.g.dart:18). It comes up in 250 ms and
 * goes down in 200 on legacyDecelerate, the barrier fading on `ease`
 * (bottom_sheet.dart:29-31, :695-699; routes.dart:1869). A barrier tap, a
 * drag down and Back close the top sheet ([OrcaDialogs.dismiss]), as Back
 * pops Flutter's popup route first; a sheet on a page not on top (a tab
 * left, a page pushed over it) takes no Back.
 *
 * Accessibility (D5, the user's call): while a sheet is open the page is
 * out of reach (ModalBarrier's BlockSemantics, modal_barrier.dart:260), the
 * top panel is a pane named "Dialog", Flutter's name for the route on
 * Android (bottom_sheet.dart:726-732, :777, :801-805), and the barrier one
 * node "Scrim" over the page above the panel (the clip of :734-736,
 * :806-811) whose click "Close Bottom Sheet" and dismiss close it
 * (modal_barrier.dart:233-258; bottom_sheet.dart:1356-1357).
 * The sheet takes the focus from the page, as the route's FocusScope does
 * (routes.dart:1095-1160, :1201), and gives it back to what had it once
 * the last sheet closes. A sheet sliding out is out of reach and takes no
 * touch (routes.dart:1154-1157, :2278-2280). The panel stands on the
 * keyboard when it is up (beyond Flutter, whose sheet the keyboard covers:
 * a known difference).
 */
@Composable
internal fun DialogLayer(model: OrcaPageModel?, content: @Composable () -> Unit) {
    // The route's area for the bubbles of its tooltips, the page's and the sheets' alike. Always provided, so
    // the content stays put as the model comes and goes; a frame's inner layer (no model) keeps the frame's.
    val tooltips = remember { TooltipOverlay() }
    CompositionLocalProvider(LocalTooltipOverlay provides (if (model != null) tooltips else LocalTooltipOverlay.current)) {
        Layer(model, tooltips, content)
    }
}

/** [DialogLayer]'s page and sheets, [tooltips] the layer's area. */
@Composable
private fun Layer(model: OrcaPageModel?, tooltips: TooltipOverlay, content: @Composable () -> Unit) {
    val dialogs = model?.dialogs
    val top = dialogs?.top
    val page = remember { FocusRequester() }
    Box(
        Modifier
            .fillMaxSize()
            .onGloballyPositioned(tooltips::place)
            .then(if (top != null) Modifier.clearAndSetSemantics {} else Modifier)
            .focusRequester(page)
            .focusGroup(),
        contentAlignment = Alignment.TopCenter,
    ) {
        content()
    }
    if (model == null || dialogs == null) return
    for (sheet in dialogs.sheets) key(sheet) { Sheet(sheet, model, dialogs, isTop = sheet === top) }

    val focused = remember { FocusMemo() }
    LaunchedEffect(top) {
        val before = focused.top
        focused.top = top
        when {
            top != null -> {
                if (before == null) page.saveFocusedChild()
                top.focus.requestFocus()
            }
            before != null -> page.restoreFocusedChild()
        }
    }

    // The route this page is drawn for is the one on top, or the page has no router.
    val host = LocalOrcaPageDrawerHost.current
    val onTop = host == null || host.router.top.id == host.routeId
    // Composed when a sheet opens, after the router's own handlers: asked before them.
    if (top != null) BackHandler(enabled = onTop) { dialogs.dismiss() }
}

/** The sheet on top when the layer last looked. */
private class FocusMemo {
    var top: OrcaSheet? = null
}

/** One sheet: its barrier, its scrim node and its panel, laid out over the whole layer. */
@Composable
private fun Sheet(sheet: OrcaSheet, model: OrcaPageModel, dialogs: OrcaDialogs, isTop: Boolean) {
    // The route's controller on this composition's frames: in 250 ms, out 200, each for the part of the way left.
    LaunchedEffect(sheet, sheet.leaving, sheet.dragging) {
        if (sheet.dragging && !sheet.leaving) return@LaunchedEffect
        val target = if (sheet.leaving) 0f else 1f
        val ms = if (sheet.leaving) EXIT_MS * sheet.value else ENTER_MS * (1f - sheet.value)
        animate(sheet.value, target, animationSpec = tween(ms.roundToInt(), easing = LinearEasing)) { now, _ -> sheet.value = now }
        if (sheet.leaving) dialogs.gone(sheet)
    }
    val open = isTop && !sheet.leaving
    val keyboard = WindowInsets.ime
    // From the layer's bottom edge down to the window's: what of the keyboard is below the layer.
    val below = remember { mutableIntStateOf(0) }
    val fling = with(LocalDensity.current) { MIN_FLING_DP_PER_S.dp.toPx() }

    Layout(
        content = {
            Box(
                Modifier
                    .drawBehind { drawRect(Color.Black, alpha = BARRIER_ALPHA * Ease.transform(sheet.value)) }
                    .then(if (sheet.leaving) Modifier else Modifier.pointerInput(sheet) { detectTapGestures { dialogs.dismiss() } }),
            )
            Box(
                if (!open) {
                    Modifier
                } else {
                    Modifier.semantics(mergeDescendants = true) {
                        contentDescription = SCRIM_LABEL
                        onClick(label = SCRIM_HINT) {
                            dialogs.dismiss()
                            true
                        }
                        dismiss {
                            dialogs.dismiss()
                            true
                        }
                    }
                },
            )
            Box(
                Modifier
                    .testTag(DIALOG_PANEL_TAG)
                    .then(
                        if (open) {
                            Modifier.semantics {
                                paneTitle = PANE_TITLE
                                isTraversalGroup = true
                            }
                        } else {
                            Modifier.clearAndSetSemantics {}
                        },
                    )
                    .focusRequester(sheet.focus)
                    .focusTarget()
                    .then(if (sheet.leaving) Modifier else Modifier.dragToClose(sheet, fling) { dialogs.dismiss() })
                    .clip(PANEL_SHAPE)
                    .background(Color.White),
            ) {
                // The BottomSheet's Material sets bodyMedium (material.dart:470-474); a sheet sliding out takes no touch.
                ProvideTextStyle(MaterialTheme.typography.bodyMedium) {
                    CompositionLocalProvider(LocalPointerBlocked provides sheet.leaving) {
                        // The height is tight (FractionallySizedBox), the width loose up to the panel's.
                        NodeView(sheet.sheet.rootId, model, Modifier.fillMaxHeight())
                    }
                }
            }
        },
        modifier = Modifier
            .fillMaxSize()
            .onPlaced { layer ->
                val window = layer.findRootCoordinates()
                below.intValue = maxOf(0, (window.size.height - layer.positionInRoot().y - layer.size.height).roundToInt())
            },
    ) { measurables, constraints ->
        val width = if (constraints.hasBoundedWidth) constraints.maxWidth else constraints.minWidth
        val height = if (constraints.hasBoundedHeight) constraints.maxHeight else constraints.minHeight
        val panelWidth = minOf(width, MAX_WIDTH_DP.dp.roundToPx())
        val panelHeight = (height * sheet.sheet.heightFactor).roundToInt()
        sheet.heightPx = panelHeight
        val lift = maxOf(0, keyboard.getBottom(this) - below.intValue)
        val barrier = measurables[0].measure(Constraints.fixed(width, height))
        val scrim = measurables[1].measure(Constraints.fixed(width, maxOf(0, height - lift - panelHeight)))
        val panel = measurables[2].measure(Constraints(0, panelWidth, panelHeight, panelHeight))
        layout(width, height) {
            barrier.place(0, 0)
            scrim.place(0, 0)
            // Read here, so each frame of the slide places the panel again and recomposes nothing.
            sheet.topPx = height - lift - (panelHeight * sheet.shown).roundToInt()
            panel.place((width - panel.width) / 2, sheet.topPx)
        }
    }
}

/**
 * Flutter's drag on the sheet (bottom_sheet.dart:280-324): past the touch
 * slop the panel follows the finger 1:1 (the route's value less the drag
 * over the panel's height, the curve set aside); let go faster down than
 * [fling] or below half its height it closes ([close]), else it goes back
 * up. The finger is followed in the sheet's space, not the panel's, which
 * moves under it. A sheet closing takes no drag.
 */
private fun Modifier.dragToClose(sheet: OrcaSheet, fling: Float, close: () -> Unit): Modifier = pointerInput(sheet) {
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        if (sheet.leaving) return@awaitEachGesture
        var over = 0f
        val start = awaitVerticalTouchSlopOrCancellation(down.id) { change, slop ->
            change.consume()
            over = slop
        } ?: return@awaitEachGesture
        sheet.split = 1f
        sheet.dragging = true
        try {
            val tracker = VelocityTracker()
            var last = start.position.y + sheet.topPx
            tracker.addPosition(start.uptimeMillis, Offset(0f, last))
            sheet.dragBy(over)
            val lifted = verticalDrag(start.id) { change ->
                val y = change.position.y + sheet.topPx
                sheet.dragBy(y - last)
                last = y
                tracker.addPosition(change.uptimeMillis, Offset(0f, y))
                change.consume()
            }
            val velocity = if (lifted) tracker.calculateVelocity().y else 0f
            if (!sheet.leaving) {
                sheet.split = sheet.value
                if (velocity > fling || sheet.value < CLOSE_THRESHOLD) close()
            }
        } finally {
            // Also when the sheet closed meanwhile and took the drag away: it slides out from where it is.
            sheet.dragging = false
        }
    }
}

/** The finger moved [dy] pixels down the panel: the route's value goes down by that over the panel's height. */
private fun OrcaSheet.dragBy(dy: Float) {
    if (leaving || heightPx <= 0) return
    value = (value - dy / heightPx).coerceIn(0f, 1f)
}

/** The test tag of each sheet's panel. */
internal const val DIALOG_PANEL_TAG: String = "orca-dialog-panel"

/** Flutter's `_kBottomSheetEnterDuration` and `_kBottomSheetExitDuration` (bottom_sheet.dart:29-30). */
private const val ENTER_MS = 250f
private const val EXIT_MS = 200f

/** Flutter's `_kModalBottomSheetCurve`, Easing.legacyDecelerate (bottom_sheet.dart:31; motion_defaults_m3.g.dart:210). */
private val LegacyDecelerate = CubicBezierEasing(0f, 0f, 0.2f, 1f)

/** ModalRoute's barrierCurve, Curves.ease (routes.dart:1869; curves.dart:1520). */
private val Ease = CubicBezierEasing(0.25f, 0.1f, 0.25f, 1f)

/** Colors.black54's alpha, 0x8A (bottom_sheet.dart:1123; colors.dart:335). */
private const val BARRIER_ALPHA = 0x8A / 255f

/** A drag let go below half the panel closes it (`_kCloseProgressThreshold`, bottom_sheet.dart:33). */
private const val CLOSE_THRESHOLD = 0.5f

/** A drag let go faster down than this closes it (`_kMinFlingVelocity`, bottom_sheet.dart:32). */
private const val MIN_FLING_DP_PER_S = 700

/** M3's sheet constraints (bottom_sheet_defaults_m3.g.dart:18). */
private const val MAX_WIDTH_DP = 640

/** OrcaPage's Container: white, top corners 24, antiAlias (orca_page.dart:358-369). */
private val PANEL_SHAPE = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)

/** Flutter's route label on Android, MaterialLocalizations.dialogLabel (material_localizations.dart:1122). */
private const val PANE_TITLE = "Dialog"

/** The barrier's label and its tap hint: scrimLabel, scrimOnTapHint(bottomSheetLabel) (material_localizations.dart:1137-1143). */
private const val SCRIM_LABEL = "Scrim"
private const val SCRIM_HINT = "Close Bottom Sheet"
