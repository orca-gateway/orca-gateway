package com.orcagateway.sdk.widgets

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ProgressGeometry
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props

// The two progress indicators as the Flutter SDK's builders paint them
// (primitive_builders.dart:302-323, 364-384, painters :435-513), not as
// Material's: static pictures from ProgressGeometry on a Canvas, nothing
// animates. A DrawScope is never mirrored, so right to left draws the same.

/**
 * Flutter's `CircularProgressIndicator`: a [ProgressGeometry.CIRCULAR_SIZE]
 * dp square unless the parent forces a size (a non-square one draws an
 * ellipse), the arc's oval the box inset half the stroke (`strokeWidth`, 3
 * by default), in `color` (#2196F3 by default). Without a `value`, one
 * static arc from -0.5 rad over 4.5 rad; with one, a full track in the
 * colour at alpha 0x33, then the arc from 12 o'clock over the value (none at
 * 0), the arcs with round caps. Angles are Flutter's: from 3 o'clock,
 * clockwise.
 */
@Composable
internal fun CircularProgressIndicatorWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val color = Props.color(node["color"]) ?: Color(ProgressGeometry.DEFAULT_COLOR)
    val strokeWidth = ProgressGeometry.circularStroke(Props.number(node["strokeWidth"]))
    val arc = ProgressGeometry.circularArc(Props.number(node["value"]))
    Canvas(modifier.size(ProgressGeometry.CIRCULAR_SIZE.dp)) {
        val stroke = strokeWidth.dp.toPx()
        val rect = ProgressGeometry.circularRect(size.width.toDouble(), size.height.toDouble(), stroke.toDouble())
        val topLeft = Offset(rect.left.toFloat(), rect.top.toFloat())
        val oval = Size(rect.width.toFloat(), rect.height.toFloat())
        if (arc.track) {
            val track = Color(ProgressGeometry.trackColor(color.toArgb()))
            drawArc(track, 0f, 360f, useCenter = false, topLeft = topLeft, size = oval, style = Stroke(stroke))
        }
        if (arc.drawsArc) {
            drawArc(
                color, Math.toDegrees(arc.startRad).toFloat(), Math.toDegrees(arc.sweepRad).toFloat(),
                useCenter = false, topLeft = topLeft, size = oval, style = Stroke(stroke, cap = StrokeCap.Round),
            )
        }
    }
}

/**
 * Flutter's `LinearProgressIndicator`: `minHeight` (4 by default) high
 * across the parent's width, clipped to round ends of half that height; the
 * track in `backgroundColor` (#E0E0E0 by default), then, when there is a
 * `value`, a bar of that part of the width in `color` (#2196F3 by default)
 * from the left, right to left as well.
 */
@Composable
internal fun LinearProgressIndicatorWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val value = Props.number(node["value"])
    val color = Props.color(node["color"]) ?: Color(ProgressGeometry.DEFAULT_COLOR)
    val track = Props.color(node["backgroundColor"]) ?: Color(ProgressGeometry.LINEAR_TRACK_COLOR)
    val height = ProgressGeometry.linearHeight(Props.number(node["minHeight"]))
    val shape = RoundedCornerShape(ProgressGeometry.linearRadius(height).dp)
    Canvas(modifier.fillMaxWidth().height(Props.lengthOf(height)).clip(shape)) {
        drawRect(track)
        val bar = ProgressGeometry.linearBar(size.width.toDouble(), value) ?: return@Canvas
        drawRect(color, size = Size(bar.toFloat(), size.height))
    }
}
