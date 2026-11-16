package com.orcagateway.core.render

import kotlin.math.PI
import kotlin.math.max

/** A rect in the indicator's box, in logical pixels (dp). */
public data class ProgressRect(public val left: Double, public val top: Double, public val width: Double, public val height: Double)

/**
 * What a CircularProgressIndicator strokes, angles in radians from 3
 * o'clock, clockwise: the full-circle [track] first when set, then the arc
 * from [startRad] over [sweepRad] with round caps when [drawsArc].
 */
public data class CircularArc(public val startRad: Double, public val sweepRad: Double, public val track: Boolean) {
    /** Flutter strokes the arc only when it sweeps (`if (v > 0)`, primitive_builders.dart:505). */
    public val drawsArc: Boolean get() = sweepRad > 0
}

/**
 * CircularProgressIndicator and LinearProgressIndicator as Flutter's
 * builders paint them (primitive_builders.dart:302-323, 364-384, painters
 * :435-513), not Material's: nothing animates. Colours are ARGB ints, as
 * Compose's `Color(Int)` and `toArgb()`. The same cases as Swift's
 * ProgressGeometry.
 */
public object ProgressGeometry {
    /** A Circular's box, width and height, unless its parent forces one (:303, :312-314; `size` is no engine prop). */
    public const val CIRCULAR_SIZE: Double = 36.0

    /** The arc's and the bar's colour when the node sets none, 0xFF2196F3 (:317, :378). */
    public const val DEFAULT_COLOR: Int = 0xFF2196F3.toInt()

    /** A Linear's track when it sets no backgroundColor, 0xFFE0E0E0 (:379). */
    public const val LINEAR_TRACK_COLOR: Int = 0xFFE0E0E0.toInt()

    private const val STROKE: Double = 3.0
    private const val LINEAR_HEIGHT: Double = 4.0
    private const val TRACK_ALPHA: Int = 0x33

    /** The stroke width: `strokeWidth ?? 3`, and 3 when not above 0 (NaN too), :305, :318. */
    public fun circularStroke(strokeWidth: Double?): Double = if (strokeWidth != null && strokeWidth > 0) strokeWidth else STROKE

    /**
     * Where the arc runs in a [width] x [height] box: the box inset by half
     * the [strokeWidth], never narrower than 0 (:480-486); a forced
     * non-square box makes it an ellipse.
     */
    public fun circularRect(width: Double, height: Double, strokeWidth: Double): ProgressRect {
        val inset = strokeWidth / 2
        return ProgressRect(inset, inset, max(0.0, width - strokeWidth), max(0.0, height - strokeWidth))
    }

    /**
     * The arc for [value]: none or NaN is one static arc from -0.5 rad
     * sweeping 4.5 rad over no track (:309-310, :493-497); else the value
     * clamped to 0..1, a full track and an arc from 12 o'clock (-π/2) of
     * 2π·v (:499-507), which [CircularArc.drawsArc] skips at 0.
     */
    public fun circularArc(value: Double?): CircularArc {
        if (value == null || value.isNaN()) return CircularArc(-0.5, 4.5, track = false)
        return CircularArc(-PI / 2, 2 * PI * value.coerceIn(0.0, 1.0), track = true)
    }

    /** The determinate track: [argb] with its alpha replaced by 0x33 (`withAlpha(0x33)`, :501). */
    public fun trackColor(argb: Int): Int = (argb and 0x00FFFFFF) or (TRACK_ALPHA shl 24)

    /**
     * A Linear's height: `minHeight ?? 4` (:368), 0 kept; one not above 0
     * (a negative one or NaN, which a divide transform can make) is 0, as a
     * release build clamps the SizedBox into a loose parent (a debug build
     * asserts).
     */
    public fun linearHeight(minHeight: Double?): Double {
        val height = minHeight ?: LINEAR_HEIGHT
        return if (height > 0) height else 0.0
    }

    /** The corner radius the Linear is clipped to, half its [height] (:373). */
    public fun linearRadius(height: Double): Double = height / 2

    /**
     * How wide the bar is in a track [width] wide, drawn from the left in
     * either direction: none without a [value] (the bare track, :451), else
     * the width times Dart's `value.clamp(0, 1)` (:454), where NaN is above
     * every number, so a full bar.
     */
    public fun linearBar(width: Double, value: Double?): Double? {
        if (value == null) return null
        return width * if (value.isNaN()) 1.0 else value.coerceIn(0.0, 1.0)
    }
}
