package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.BoxDecorationProps
import com.orcagateway.sdk.style.CornerRadii
import com.orcagateway.sdk.style.CornersShape
import com.orcagateway.sdk.style.Insets
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.style.boxDecoration

/**
 * Flutter `Container`, laid out as its `build` nests it, outside in:
 * `margin`; a fixed `width` and `height` (which include the padding, and
 * give way to a size the parent forces); the `decoration` (or `color` when
 * there is none, Flutter's shorthand for a decoration colour) painted
 * behind; `clipBehavior` other than `none` clipping what is inside to the
 * decoration's shape (a rectangle without one), the decoration itself
 * unclipped; then `padding` plus the border's width, as Flutter's
 * `BoxDecoration.padding` adds it.
 *
 * Sizing is Flutter's: with no child the box takes all the space it may
 * (its parent's minimum on an unbounded axis); with an `alignment` it does
 * the same and places its child, loose, in it; otherwise it takes its
 * child's size, a size the parent forces on an axis (a stretched Column's
 * width) passing through to the child.
 */
@Composable
internal fun ContainerWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val decoration = if (node["decoration"] == null) {
        Props.color(node["color"])?.let { BoxDecorationProps(color = it) }
    } else {
        BoxDecorationProps.of(node["decoration"])
    }
    val alignment = node["alignment"]?.let(Props::alignment)
    val padding = Props.insets(node["padding"]) ?: Insets.Zero
    val border = decoration?.border?.width ?: 0.0

    var box = modifier.padding((Props.insets(node["margin"]) ?: Insets.Zero).paddingValues())
    Props.length(node["width"])?.let { box = box.width(it) }
    Props.length(node["height"])?.let { box = box.height(it) }
    if (decoration != null) box = box.boxDecoration(decoration)
    if (Props.clips(node["clipBehavior"])) box = box.clip(decoration?.shape ?: CornersShape(CornerRadii.Zero))
    box = box.padding(
        Insets(
            top = padding.top + border,
            left = padding.left + border,
            bottom = padding.bottom + border,
            right = padding.right + border,
        ).paddingValues(),
    )
    if (node.childIds.isEmpty() || alignment != null) box = box.fillMaxSize()

    Box(box, contentAlignment = alignment ?: Alignment.TopStart, propagateMinConstraints = alignment == null) {
        ChildView(node, model)
    }
}

/**
 * Flutter `ClipRRect`: the child, laid out as if unclipped, cut to rounded
 * corners. `borderRadius` is one number for every corner or
 * `{topLeft, topRight, bottomLeft, bottomRight}` (the Flutter SDK reads only
 * the number); radii that do not fit shrink as [CornersShape] says. Always
 * clips, anti-aliased, as Flutter's default `clipBehavior` does.
 */
@Composable
internal fun ClipRRectWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val radii = Props.radii(node["borderRadius"]) ?: CornerRadii.Zero
    Box(modifier.clip(CornersShape(radii)), propagateMinConstraints = true) {
        ChildView(node, model)
    }
}
