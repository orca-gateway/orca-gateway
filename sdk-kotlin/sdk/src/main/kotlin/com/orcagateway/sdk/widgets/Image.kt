package com.orcagateway.sdk.widgets

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.constrain
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.client.ImageLoader
import com.orcagateway.sdk.style.Props
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Flutter `Image.network` as the Flutter builder makes it: `src` loaded
 * through [ImageLoader.shared], fitted by `fit` ([imageFit], cover by
 * default) and placed by `alignment` (center by default) in a `width` by
 * `height` box. `color` tints it with Flutter's default `colorBlendMode`
 * for an Image, `srcIn`. `alt` is the box's content description, there
 * while the image loads too, as Flutter's `Semantics(image: true)`.
 *
 * While the image loads it is an empty box of that size. A failed load, an
 * empty `src` and one that is not an http or https URL (asset names are not
 * in S9, and Flutter's `Image.network` fails on them) draw "!" centred in
 * it, as the Flutter builder's error builder `SizedBox(width, height, child:
 * Center(child: Text('!')))`: a side with no size fills what the parent
 * offers when that is bounded, as `Center` does. The box is still read as
 * `alt` with the image role; the "!" is drawn but hidden from semantics, as
 * Swift's `.accessibilityElement()`. A new `src` empties the box
 * until it loads, as Flutter's default `gaplessPlayback: false`.
 *
 * Loaded, it is sized as Flutter's `RenderImage._sizeForConstraints`:
 * `width` and `height` folded into the parent's constraints, then the
 * bitmap's size at one dp per image pixel (a network image's scale 1)
 * fitted in them keeping its aspect ratio ([preservingAspectRatio]). With
 * neither, it is its pixel size in dp, scaled down to what the parent
 * allows; with one, the other side follows the aspect ratio; with both, it
 * is that box. [TiledImage] then draws it inside the box at that same one dp
 * per image pixel, fitted by `fit`, and tiled over the box by `repeat`
 * (`repeat`, `repeatX`, `repeatY`; `noRepeat` or none draws it once).
 */
@Composable
internal fun ImageWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val src = Props.text(node["src"])
    var bitmap by remember(src) { mutableStateOf<ImageBitmap?>(null) }
    var failed by remember(src) { mutableStateOf(false) }
    LaunchedEffect(src) {
        bitmap = ImageLoader.shared.load(src)
        failed = bitmap == null
    }

    var box = modifier
    Props.length(node["width"])?.let { box = box.width(it) }
    Props.length(node["height"])?.let { box = box.height(it) }
    val alt = node["alt"]?.stringValue
    box = box.semantics {
        alt?.let { contentDescription = it }
        role = Role.Image
    }

    val image = bitmap
    if (failed) {
        Box(box.fillMaxSize(), contentAlignment = Alignment.Center) { Text("!", Modifier.clearAndSetSemantics {}) }
        return
    }
    if (image == null) {
        Box(box)
        return
    }
    val fit = imageFit(node["fit"])
    val alignment = Props.alignment(node["alignment"])
    val repeat = node["repeat"]?.stringValue
    val painter = remember(image, fit, alignment, repeat) {
        TiledImage(
            image, fit, alignment,
            x = repeat == "repeat" || repeat == "repeatX",
            y = repeat == "repeat" || repeat == "repeatY",
        )
    }
    Image(
        painter = painter,
        contentDescription = null,
        modifier = box.layout { measurable, constraints ->
            val size = constraints.preservingAspectRatio(image.width * density, image.height * density)
            val placeable = measurable.measure(Constraints.fixed(size.width, size.height))
            layout(placeable.width, placeable.height) { placeable.place(0, 0) }
        },
        // The painter gets the whole box: it fits and places the image itself.
        contentScale = ContentScale.FillBounds,
        colorFilter = Props.color(node["color"])?.let { ColorFilter.tint(it, BlendMode.SrcIn) },
    )
}

/**
 * Flutter's `paintImage`: [image] at one dp per pixel fitted to the box by
 * [fit] as `applyBoxFit` (the destination is the scaled image cut to the
 * box, the source the part of the image it shows), both placed by
 * [alignment], then drawn again a destination's width apart across the box
 * when [x] and a height apart down it when [y] (`_generateImageTileRects`),
 * clipped to the box. Neither is `ImageRepeat.noRepeat`: the one image. A
 * drawn grid, not a repeating shader, so a cut source tiles as Flutter's
 * does.
 */
private class TiledImage(
    private val image: ImageBitmap,
    private val fit: ContentScale,
    private val alignment: Alignment,
    private val x: Boolean,
    private val y: Boolean,
) : Painter() {
    private var colorFilter: ColorFilter? = null

    override val intrinsicSize: Size get() = Size(image.width.toFloat(), image.height.toFloat())

    override fun applyColorFilter(colorFilter: ColorFilter?): Boolean {
        this.colorFilter = colorFilter
        return true
    }

    override fun DrawScope.onDraw() {
        val natural = Size(image.width * density, image.height * density)
        val scale = fit.computeScaleFactor(natural, size)
        val width = min(natural.width * scale.scaleX, size.width).roundToInt()
        val height = min(natural.height * scale.scaleY, size.height).roundToInt()
        if (width <= 0 || height <= 0) return
        val box = IntSize(size.width.roundToInt(), size.height.roundToInt())
        val at = alignment.align(IntSize(width, height), box, layoutDirection)
        val source = IntSize(
            (width / scale.scaleX / density).roundToInt().coerceIn(1, image.width),
            (height / scale.scaleY / density).roundToInt().coerceIn(1, image.height),
        )
        val from = alignment.align(source, IntSize(image.width, image.height), layoutDirection)
        val columns = if (x) tiles(at.x, width, box.width) else 0..0
        val rows = if (y) tiles(at.y, height, box.height) else 0..0
        clipRect {
            for (i in columns) {
                for (j in rows) {
                    drawImage(
                        image, from, source, IntOffset(at.x + i * width, at.y + j * height), IntSize(width, height),
                        colorFilter = colorFilter,
                    )
                }
            }
        }
    }

    /** The tiles a [stride] apart, by index from the one at [start], that cover 0 to [extent]. */
    private fun tiles(start: Int, stride: Int, extent: Int): IntRange =
        (-start).floorDiv(stride)..-(start + stride - extent).floorDiv(stride)
}

/**
 * Flutter's `BoxConstraints.constrainSizeAndAttemptToPreserveAspectRatio`
 * in pixels: tight constraints give their size; otherwise [width] by
 * [height] is brought within the maximum, then the minimum, one side at a
 * time with the other following the aspect ratio, and finally constrained.
 */
internal fun Constraints.preservingAspectRatio(width: Float, height: Float): IntSize {
    if (hasFixedWidth && hasFixedHeight) return IntSize(minWidth, minHeight)
    val ratio = width / height
    var w = width
    var h = height
    if (w > maxWidth) {
        w = maxWidth.toFloat()
        h = w / ratio
    }
    if (h > maxHeight) {
        h = maxHeight.toFloat()
        w = h * ratio
    }
    if (w < minWidth) {
        w = minWidth.toFloat()
        h = w / ratio
    }
    if (h < minHeight) {
        h = minHeight.toFloat()
        w = h * ratio
    }
    return constrain(IntSize(w.roundToInt(), h.roundToInt()))
}

/** Flutter `BoxFit` by name as a [ContentScale]; cover when unknown, as the Flutter builder. */
internal fun imageFit(value: JsonValue?): ContentScale = when (value?.stringValue) {
    "fill" -> ContentScale.FillBounds
    "contain" -> ContentScale.Fit
    "fitWidth" -> ContentScale.FillWidth
    "fitHeight" -> ContentScale.FillHeight
    "none" -> ContentScale.None
    "scaleDown" -> ContentScale.Inside
    else -> ContentScale.Crop
}
