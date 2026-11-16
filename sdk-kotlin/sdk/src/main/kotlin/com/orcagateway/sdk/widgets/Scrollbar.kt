package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.ScrollMetrics
import com.orcagateway.core.render.ScrollbarFade
import com.orcagateway.core.render.ScrollbarThumb
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlinx.coroutines.flow.collectLatest

/**
 * A scroll view as the Scrollbar around it follows it: its axis, whether
 * offset 0 is at the far end ([reverse], before right to left mirrors a
 * horizontal view), and where it stands, in dp, read from snapshot state so
 * the thumb moves with it.
 */
internal class ScrollbarSource(
    val horizontal: Boolean,
    val reverse: Boolean,
    val metrics: () -> ScrollMetrics,
    val inProgress: () -> Boolean,
)

/** What the scroll view directly inside a Scrollbar reports itself to; the last one to report is followed. */
internal class ScrollbarHost {
    var source: ScrollbarSource? by mutableStateOf(null)
}

/** The Scrollbar a scroll view built here reports to: none outside a Scrollbar, and none inside another scroll view. */
internal val LocalScrollbarHost = staticCompositionLocalOf<ScrollbarHost?> { null }

/**
 * The Android thumb's colour: the light theme's `highlightColor`
 * (0x66BCBCBC) made opaque, material_ui scrollbar.dart:263-268,
 * theme_data.dart:595.
 */
private val THUMB_COLOR = Color(0xFFBCBCBC)

/**
 * Flutter `Scrollbar` (layout_builders.dart:603-611) as material_ui draws
 * it on Android: a square thumb `thickness` thick (4 dp by default) over
 * the child, along the far edge (the right, the left right to left, the
 * bottom for a horizontal view) for the scroll view directly inside it
 * (Flutter's depth-0 notifications; a scroll view nested in that one is
 * not followed), as [ScrollbarThumb] places it and [ScrollbarFade] shows
 * it: while scrolling, until 600 ms after, always with `thumbVisibility`.
 * The thumb takes no touch, as on Android in Flutter. Its track is the
 * whole viewport: Flutter also keeps it clear of the MediaQuery padding
 * (the system bars), which a Scrollbar inside a page body rarely meets.
 * Unlike Flutter, whose builder passes no controller (so thumbVisibility
 * asserts and shows nothing for a Scrollbar inside another scroll view),
 * such a Scrollbar works here.
 */
@Composable
internal fun ScrollbarWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val thumbVisibility = Props.bool(node["thumbVisibility"]) ?: false
    val thickness = Props.length(node["thickness"]) ?: ScrollbarThumb.THICKNESS.dp
    val host = remember { ScrollbarHost() }
    val fade = remember(thumbVisibility) { ScrollbarFade(thumbVisibility) }
    val opacity = remember { mutableFloatStateOf(0f) }
    LaunchedEffect(host, fade) {
        snapshotFlow { host.source?.let { it.metrics() to it.inProgress() } }.collectLatest { sample ->
            var now = withFrameMillis { it }
            if (sample != null) fade.observe(now, sample.first, sample.second)
            opacity.floatValue = fade.opacity(now).toFloat()
            while (!fade.isSettled(now)) {
                now = withFrameMillis { it }
                opacity.floatValue = fade.opacity(now).toFloat()
            }
        }
    }
    val painted = modifier.drawWithContent {
        drawContent()
        drawThumb(host.source, opacity.floatValue, thickness)
    }
    Box(painted, propagateMinConstraints = true) {
        CompositionLocalProvider(LocalScrollbarHost provides host) { ChildView(node, model) }
    }
}

/**
 * Reports [source] to the Scrollbar this scroll view sits directly in, if
 * any, while the view is shown, and builds [content] (the view's own
 * subtree) with no Scrollbar to report to.
 */
@Composable
internal fun ReportToScrollbar(source: ScrollbarSource, content: @Composable () -> Unit) {
    val host = LocalScrollbarHost.current
    if (host != null) {
        DisposableEffect(host, source) {
            host.source = source
            onDispose { if (host.source === source) host.source = null }
        }
    }
    CompositionLocalProvider(LocalScrollbarHost provides null, content = content)
}

/** Flutter `ScrollbarPainter._paintScrollbar` (widgets/scrollbar.dart:564-612) for a square thumb with no margin or padding. */
private fun DrawScope.drawThumb(source: ScrollbarSource?, opacity: Float, thickness: Dp) {
    if (source == null || opacity <= 0f) return
    val rtl = layoutDirection == LayoutDirection.Rtl
    val reverse = if (source.horizontal && rtl) !source.reverse else source.reverse
    val span = ScrollbarThumb.span(source.metrics(), reverse) ?: return
    val along = span.offset.toFloat() * density
    val length = span.extent.toFloat() * density
    val across = thickness.toPx()
    if (source.horizontal) {
        drawRect(THUMB_COLOR, Offset(along, size.height - across), Size(length, across), alpha = opacity)
    } else {
        drawRect(THUMB_COLOR, Offset(if (rtl) 0f else size.width - across, along), Size(across, length), alpha = opacity)
    }
}
