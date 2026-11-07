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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.client.ImageLoader
import com.orcagateway.sdk.style.Props

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
 * false`. `repeat` is not drawn (Swift's F7). Without `width` or
 * `height` the loaded image takes Compose's size for the bitmap, one
 * device pixel per image pixel; Flutter gives it one logical pixel each.
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
        modifier = box,
        alignment = Props.alignment(node["alignment"]),
        contentScale = imageFit(node["fit"]),
        colorFilter = Props.color(node["color"])?.let { ColorFilter.tint(it, BlendMode.SrcIn) },
    )
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
