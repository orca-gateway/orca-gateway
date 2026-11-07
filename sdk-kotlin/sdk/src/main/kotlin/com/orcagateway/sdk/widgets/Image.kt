package com.orcagateway.sdk.widgets

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.constrain
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.client.ImageLoader
import com.orcagateway.sdk.style.Props
import kotlin.math.roundToInt

/**
 * Flutter `Image.network` as the Flutter builder makes it: `src` loaded
 * through [ImageLoader.shared], fitted by `fit` ([imageFit], cover by
 * default) and placed by `alignment` (center by default) in a `width` by
 * `height` box. `color` tints it with Flutter's default `colorBlendMode`
 * for an Image, `srcIn`. `alt` is the box's content description, there
 * while the image loads too, as Flutter's `Semantics(image: true)`.
 *
 * While the image loads, after a failed load, and for a `src` that is not
 * an http or https URL (asset names are not in S9), the image is an empty
 * box of that size; Flutter's error builder draws "!" there. A new `src`
 * empties the box until it loads, as Flutter's default `gaplessPlayback:
 * false`. `repeat` is not drawn (Swift's F7).
 *
 * Loaded, it is sized as Flutter's `RenderImage._sizeForConstraints`:
 * `width` and `height` folded into the parent's constraints, then the
 * bitmap's size at one dp per image pixel (a network image's scale 1)
 * fitted in them keeping its aspect ratio ([preservingAspectRatio]). With
 * neither, it is its pixel size in dp, scaled down to what the parent
 * allows; with one, the other side follows the aspect ratio; with both, it
 * is that box. `fit` then draws the image inside it.
 */
@Composable
internal fun ImageWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val src = Props.text(node["src"])
    var bitmap by remember(src) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(src) { bitmap = ImageLoader.shared.load(src) }

    var box = modifier
    Props.length(node["width"])?.let { box = box.width(it) }
    Props.length(node["height"])?.let { box = box.height(it) }
    val alt = node["alt"]?.stringValue
    box = box.semantics {
        alt?.let { contentDescription = it }
        role = Role.Image
    }

    val image = bitmap
    if (image == null) {
        Box(box)
        return
    }
    Image(
        bitmap = image,
        contentDescription = null,
        modifier = box.layout { measurable, constraints ->
            val size = constraints.preservingAspectRatio(image.width * density, image.height * density)
            val placeable = measurable.measure(Constraints.fixed(size.width, size.height))
            layout(placeable.width, placeable.height) { placeable.place(0, 0) }
        },
        alignment = Props.alignment(node["alignment"]),
        contentScale = imageFit(node["fit"]),
        colorFilter = Props.color(node["color"])?.let { ColorFilter.tint(it, BlendMode.SrcIn) },
    )
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
