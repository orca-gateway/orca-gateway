package com.orcagateway.sdk.widgets

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.client.ImageLoader
import com.orcagateway.sdk.style.IconNames
import com.orcagateway.sdk.style.Props
import kotlin.math.roundToInt

/**
 * Flutter `Icon` as the Flutter builder (`_buildIcon`) makes it: the
 * Material icon named by `name` (else `icon`) through [IconNames], a filled
 * circle for an unknown or missing name, in a `size` square (24 by
 * default), tinted `color` or else the content colour, as Flutter's
 * IconTheme. No label: the builder gives the icon none.
 *
 * A `src` takes precedence, as Flutter's `ImageIcon` (the builder's
 * ImageIcon node draws here too): a network raster from
 * [ImageLoader.shared] at one dp per image pixel, as a network image at
 * scale 1, fitted `scaleDown` into the square (shrunk to fit keeping its
 * aspect ratio, never enlarged), centred, and always tinted srcIn with
 * `color` or else the content colour. The square is empty while it loads
 * and after a failed load, as Flutter's `Image` with no image yet.
 */
@Composable
internal fun IconWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val box = modifier.size(Props.length(node["size"]) ?: 24.dp)
    val tint = Props.color(node["color"]) ?: LocalContentColor.current
    val src = node["src"]?.takeUnless { it.isNull }?.let { Props.text(it) }
    if (src == null) {
        val name = node["name"]?.stringValue ?: node["icon"]?.stringValue
        Icon(IconNames.vector(name), contentDescription = null, modifier = box, tint = tint)
        return
    }
    var bitmap by remember(src) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(src) { bitmap = ImageLoader.shared.load(src) }
    val image = bitmap
    if (image == null) {
        Box(box)
        return
    }
    Canvas(box) {
        // Flutter's paintImage with BoxFit.scaleDown and Alignment.center.
        val natural = Size(image.width * density, image.height * density)
        val scale = ContentScale.Inside.computeScaleFactor(natural, size)
        val drawn = IntSize((natural.width * scale.scaleX).roundToInt(), (natural.height * scale.scaleY).roundToInt())
        if (drawn.width <= 0 || drawn.height <= 0) return@Canvas
        val at = Alignment.Center.align(drawn, IntSize(size.width.roundToInt(), size.height.roundToInt()), layoutDirection)
        drawImage(image, dstOffset = at, dstSize = drawn, colorFilter = ColorFilter.tint(tint, BlendMode.SrcIn))
    }
}
