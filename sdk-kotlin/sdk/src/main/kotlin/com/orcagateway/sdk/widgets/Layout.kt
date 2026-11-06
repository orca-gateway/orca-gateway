package com.orcagateway.sdk.widgets

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Insets
import com.orcagateway.sdk.style.Props

// Compose passes constraints down the way Flutter does, so these widgets
// keep Flutter's sizing with plain modifiers. A pass-through box keeps the
// parent's minimum (`propagateMinConstraints`), so a size the parent forces
// reaches the child, as a tight constraint passes through Padding and
// SizedBox in Flutter. Swift's `TightAxes` environment stands in for this
// on SwiftUI and has no Compose port.

/** Flutter `Center`: as big as it may be (its child's size where unbounded), the child loose in the middle. */
@Composable
internal fun CenterWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        ChildView(node, model)
    }
}

/** Flutter `Padding`: the child inset by `padding`; with no child, a box of the padding. */
@Composable
internal fun PaddingWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val insets = Props.insets(node["padding"]) ?: Insets.Zero
    Box(modifier.padding(insets.paddingValues()), propagateMinConstraints = true) {
        ChildView(node, model)
    }
}

/**
 * Flutter `SizedBox`: a fixed size on the axes it names, forced on its
 * child; with no child, an empty box of that size (the parent's minimum on
 * an axis it leaves out, 0 in a loose parent).
 */
@Composable
internal fun SizedBoxWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    var sized = modifier
    Props.length(node["width"])?.let { sized = sized.width(it) }
    Props.length(node["height"])?.let { sized = sized.height(it) }
    if (node.childIds.isEmpty()) {
        Spacer(sized)
    } else {
        Box(sized, propagateMinConstraints = true) { ChildView(node, model) }
    }
}

/**
 * Flutter `SingleChildScrollView`: `scrollDirection` (`vertical` by default)
 * and `padding` inside the scrolled content. On an axis with no limit (a
 * scroll view inside a Column) it takes its child's size and does not
 * scroll, as Flutter's viewport does; Compose would throw there.
 */
@Composable
internal fun ScrollWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val horizontal = node["scrollDirection"]?.stringValue == "horizontal"
    val insets = Props.insets(node["padding"]) ?: Insets.Zero
    BoxWithConstraints(modifier, propagateMinConstraints = true) {
        val bounded = if (horizontal) constraints.hasBoundedWidth else constraints.hasBoundedHeight
        val state = rememberScrollState()
        val scroll = when {
            !bounded -> Modifier
            horizontal -> Modifier.horizontalScroll(state)
            else -> Modifier.verticalScroll(state)
        }
        Box(scroll.padding(insets.paddingValues()), propagateMinConstraints = true) {
            ChildView(node, model)
        }
    }
}
