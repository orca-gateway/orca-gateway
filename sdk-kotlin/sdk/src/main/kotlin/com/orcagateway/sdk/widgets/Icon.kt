package com.orcagateway.sdk.widgets

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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.client.ImageLoader
import com.orcagateway.sdk.style.IconNames
import com.orcagateway.sdk.style.Props

/**
 * Flutter `Icon` as the Flutter builder (`_buildIcon`) makes it: the
 * Material icon named by `name` (else `icon`) through [IconNames], a filled
 * circle for an unknown or missing name, in a `size` square (24 by
 * default), tinted `color` or else the content colour, as Flutter's
 * IconTheme. No label: the builder gives the icon none.
 *
 * A `src` takes precedence, as Flutter's `ImageIcon`: a network raster from
 * [ImageLoader.shared], tinted the same way (srcIn) and fitted into the
 * square; the square is empty while it loads and after a failed load.
 * Flutter fits it with `scaleDown`, so an image smaller than the square
 * stays its size there, where here it is scaled up to the square.
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
    } else {
        Icon(image, contentDescription = null, modifier = box, tint = tint)
    }
}
