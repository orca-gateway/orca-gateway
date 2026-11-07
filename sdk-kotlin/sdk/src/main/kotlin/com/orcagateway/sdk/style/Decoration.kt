package com.orcagateway.sdk.style

import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.center
import androidx.compose.ui.geometry.toRect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue

/**
 * A rectangle with its own radius per corner: Flutter's `RRect` from a
 * `BorderRadius`, for a decoration, a clip (Container, ClipRRect) and a
 * shadow. The corners are absolute, as Flutter's are, so the layout
 * direction is not read. Radii that do not fit shrink as [roundRect] says.
 */
internal data class CornersShape(val radii: CornerRadii) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline =
        Outline.Rounded(radii.roundRect(size.toRect(), density))
}

/**
 * These radii on [rect], in pixels at [density]. [deflate] (pixels) moves
 * every side in and takes as much off every radius, as Flutter's
 * `RRect.deflate` does for a border's inner edge. A negative radius is 0, and
 * radii that do not fit shrink by one factor until every side holds its two
 * corners: Flutter's `RRect.scaleRadii`, which Skia and Impeller apply when
 * Flutter paints, so one radius on all four corners stops at half the
 * shorter side.
 */
internal fun CornerRadii.roundRect(rect: Rect, density: Density, deflate: Float = 0f): RoundRect {
    val box = rect.deflate(deflate)
    fun px(radius: Double): Float = (with(density) { Props.lengthOf(radius).toPx() } - deflate).coerceAtLeast(0f)
    val tl = px(topLeft)
    val tr = px(topRight)
    val bl = px(bottomLeft)
    val br = px(bottomRight)
    val scale = minOf(fit(box.width, tl + tr), fit(box.width, bl + br), fit(box.height, tl + bl), fit(box.height, tr + br))
    return RoundRect(
        box,
        topLeft = CornerRadius(tl * scale),
        topRight = CornerRadius(tr * scale),
        bottomRight = CornerRadius(br * scale),
        bottomLeft = CornerRadius(bl * scale),
    )
}

/** How far two corners on one side must shrink to fit it: 1 when they fit. */
private fun fit(side: Float, corners: Float): Float = if (corners > side) side.coerceAtLeast(0f) / corners else 1f

/**
 * Flutter `BoxDecoration` as the Flutter SDK reads it (`parseBoxDecoration`
 * in builder_helpers.dart): color, borderRadius, border, boxShadow and
 * gradient, lengths in logical pixels as sent. Read with [of], drawn with
 * [boxDecoration]. A value the Flutter SDK would throw on (a shadow that is
 * not an object, a colour that does not parse in a gradient) is skipped or
 * clear instead, as Swift's port does.
 */
internal data class BoxDecorationProps(
    val color: Color? = null,
    val radii: CornerRadii? = null,
    val border: Border? = null,
    val shadows: List<BoxShadow> = emptyList(),
    val gradient: Gradient? = null,
) {
    /** `Border.all`: one colour (black when left out) and width (1), drawn inside the edge. */
    data class Border(val color: Color, val width: Double)

    /** Flutter `BoxShadow`: `offset` is `{dx, dy}`, x right and y down. */
    data class BoxShadow(
        val color: Color,
        val blurRadius: Double,
        val spreadRadius: Double,
        val dx: Double,
        val dy: Double,
    )

    /**
     * Flutter `LinearGradient` (from [begin] to [end], points of the unit
     * square as [Props.unitPoint] gives) or, with `type: radial`,
     * `RadialGradient` (centred, radius half the shorter side; begin and end
     * unused). [stops] only when there is one per colour.
     */
    data class Gradient(
        val radial: Boolean,
        val colors: List<Color>,
        val stops: List<Float>?,
        val begin: Offset,
        val end: Offset,
    ) {
        /** The paint for a box of [size] pixels; one colour is a plain fill, none or an empty box paints nothing. */
        fun brush(size: Size): Brush? {
            if (size.isEmpty() || colors.isEmpty()) return null
            if (colors.size == 1) return SolidColor(colors.single())
            val stopped = stops?.zip(colors)?.toTypedArray()
            if (radial) {
                val radius = size.minDimension / 2
                return if (stopped != null) {
                    Brush.radialGradient(*stopped, center = size.center, radius = radius)
                } else {
                    Brush.radialGradient(colors, center = size.center, radius = radius)
                }
            }
            val start = Offset(begin.x * size.width, begin.y * size.height)
            val stop = Offset(end.x * size.width, end.y * size.height)
            return if (stopped != null) {
                Brush.linearGradient(*stopped, start = start, end = stop)
            } else {
                Brush.linearGradient(colors, start = start, end = stop)
            }
        }
    }

    /** The box's outline, square cornered without a borderRadius: what a clip clips to. */
    val shape: CornersShape get() = CornersShape(radii ?: CornerRadii.Zero)

    companion object {
        /** Flutter's `BoxShadow` colour when none is given, `Color(0x33000000)`. */
        private val DEFAULT_SHADOW = Color(red = 0, green = 0, blue = 0, alpha = 0x33)
        private val CENTER = Offset(0.5f, 0.5f)
        private val CENTER_RIGHT = Offset(1f, 0.5f)

        /** The decoration an object describes; anything else is null. */
        fun of(value: JsonValue?): BoxDecorationProps? {
            val d = value?.objectValue ?: return null
            return BoxDecorationProps(
                color = Props.color(d["color"]),
                radii = Props.radii(d["borderRadius"]),
                border = d["border"]?.objectValue?.takeIf { it["style"]?.stringValue != "none" }?.let { b ->
                    Border(color = Props.color(b["color"]) ?: Color.Black, width = Props.number(b["width"]) ?: 1.0)
                },
                shadows = d["boxShadow"]?.arrayValue.orEmpty().mapNotNull { it.objectValue?.let(::shadow) },
                gradient = d["gradient"]?.objectValue?.let(::gradient),
            )
        }

        private fun shadow(s: Map<String, JsonValue>): BoxShadow = BoxShadow(
            color = Props.color(s["color"]) ?: DEFAULT_SHADOW,
            blurRadius = Props.number(s["blurRadius"]) ?: 0.0,
            spreadRadius = Props.number(s["spreadRadius"]) ?: 0.0,
            dx = Props.number(s["offset"]?.get("dx")) ?: 0.0,
            dy = Props.number(s["offset"]?.get("dy")) ?: 0.0,
        )

        /** As the Flutter SDK: `begin` defaults to center, and an `end` of center (or none) is centerRight. */
        private fun gradient(g: Map<String, JsonValue>): Gradient? {
            val colors = g["colors"]?.arrayValue?.map { Props.color(it) ?: Color.Transparent } ?: return null
            val stops = g["stops"]?.arrayValue?.mapNotNull { it.doubleValue?.toFloat() }?.takeIf { it.size == colors.size }
            val end = Props.unitPoint(g["end"])
            return Gradient(
                radial = g["type"]?.stringValue == "radial",
                colors = colors,
                stops = stops,
                begin = Props.unitPoint(g["begin"]),
                end = if (end == CENTER) CENTER_RIGHT else end,
            )
        }
    }
}

/**
 * Paints [decoration] behind the content as Flutter's `BoxDecoration` does:
 * the shadows in list order, then the fill (the gradient, else the colour),
 * then the border inside the edge. The content is not clipped: a widget
 * whose `clipBehavior` [Props.clips] clips itself to
 * [BoxDecorationProps.shape].
 */
internal fun Modifier.boxDecoration(decoration: BoxDecorationProps): Modifier {
    val shape = decoration.shape
    return decoration.shadows
        .fold(this) { modifier, shadow -> modifier.dropShadow(shape, shadow.toShadow()) }
        .drawWithCache {
            val radii = decoration.radii ?: CornerRadii.Zero
            val outer = radii.roundRect(size.toRect(), this)
            val body = Path().apply { addRoundRect(outer) }
            val fill = decoration.gradient?.brush(size) ?: decoration.color?.let(::SolidColor)
            val border = decoration.border
            val ring = border?.let {
                val inner = radii.roundRect(size.toRect(), this, deflate = Props.lengthOf(it.width).toPx())
                Path().apply {
                    fillType = PathFillType.EvenOdd
                    addRoundRect(outer)
                    if (inner.width > 0f && inner.height > 0f) addRoundRect(inner)
                }
            }
            onDrawBehind {
                if (fill != null) drawPath(body, fill)
                if (ring != null) drawPath(ring, border.color)
            }
        }
}

/**
 * As Compose's drop shadow, which blurs as Flutter does (Skia's radius to
 * sigma). A spread below minus the blur is drawn at minus the blur, as
 * Compose's shadow bitmap would otherwise be empty.
 */
private fun BoxDecorationProps.BoxShadow.toShadow(): Shadow {
    val blur = Props.lengthOf(blurRadius)
    return Shadow(
        radius = blur,
        color = color,
        spread = spreadRadius.coerceIn(-blur.value.toDouble(), Props.MAX_LENGTH.toDouble()).toFloat().dp,
        offset = DpOffset(dx.toFloat().dp, dy.toFloat().dp),
    )
}
