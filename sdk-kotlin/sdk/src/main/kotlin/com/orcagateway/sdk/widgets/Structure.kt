package com.orcagateway.sdk.widgets

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.contentColorFor
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.DefaultShadowColor
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.LocalOrcaSnackbars
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.indexedSlots
import com.orcagateway.sdk.navigation.LocalOrcaNavigation
import com.orcagateway.sdk.style.Insets
import com.orcagateway.sdk.style.Props

/**
 * Scaffold as the Material 3 `Scaffold`: the `appBar` slot is its top bar
 * (an AppBar draws as a `TopAppBar`; any other widget is drawn there as
 * is), `body` fills the rest at the top-start with loose constraints,
 * `floatingActionButton` floats bottom-end, and `bottomNavigationBar` sits
 * under the `persistentFooterButton_N` row. The page's snackbars show in its
 * `SnackbarHost` when it is the page root. Drawers and bottom sheets are not
 * drawn yet.
 *
 * Flutter's Scaffold lays out its slots with fresh, loose constraints, so a
 * size forced on the Scaffold reaches neither the AppBar title nor the body.
 */
@Composable
internal fun ScaffoldWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val snackbars = LocalOrcaSnackbars.current
    val footer = indexedSlots(node, "persistentFooterButton")
    val bottomBar = node.slots["bottomNavigationBar"]
    val window = LocalWindowInfo.current.containerSize
    CompositionLocalProvider(LocalOrcaSnackbars provides null) {
        Scaffold(
            modifier = modifier.boundedBy(window),
            topBar = { node.slots["appBar"]?.let { NodeView(it, model) } },
            bottomBar = {
                if (footer.isNotEmpty() || bottomBar != null) {
                    Column {
                        if (footer.isNotEmpty()) {
                            Row(
                                Modifier.fillMaxWidth().padding(8.dp),
                                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End),
                            ) {
                                for (id in footer) NodeView(id, model)
                            }
                        }
                        if (bottomBar != null) NodeView(bottomBar, model)
                    }
                }
            },
            snackbarHost = { if (snackbars != null) SnackbarHost(snackbars) },
            floatingActionButton = { node.slots["floatingActionButton"]?.let { NodeView(it, model) } },
            containerColor = Props.color(node["backgroundColor"]) ?: MaterialTheme.colorScheme.background,
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding).consumeWindowInsets(padding)) {
                node.slots["body"]?.let { NodeView(it, model) }
            }
        }
    }
}

/**
 * A Material 3 Scaffold needs a finite size. Where its parent leaves an axis
 * unbounded (a Scaffold inside a Column or a scroll view, where Flutter
 * throws), that axis is bounded by the window instead.
 */
private fun Modifier.boundedBy(window: IntSize): Modifier = layout { measurable, constraints ->
    val bounded = if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
        constraints
    } else {
        val maxWidth = if (constraints.hasBoundedWidth) constraints.maxWidth else maxOf(window.width, constraints.minWidth)
        val maxHeight = if (constraints.hasBoundedHeight) constraints.maxHeight else maxOf(window.height, constraints.minHeight)
        Constraints(constraints.minWidth, maxWidth, constraints.minHeight, maxHeight)
    }
    val placeable = measurable.measure(bounded)
    layout(placeable.width, placeable.height) { placeable.place(0, 0) }
}

/**
 * AppBar as a Material 3 top app bar laid out as Flutter's Material 3
 * AppBar: `CenterAlignedTopAppBar` when `centerTitle` is true, `TopAppBar`
 * otherwise (Flutter's Android default). The `title` slot is the title (in
 * the bar's title style unless it has its own), `action_N` the actions. The
 * leading box is `leadingWidth` wide (56 when absent) and as high as the
 * bar, at the start: the `leading` slot is forced to its size; without one,
 * a pushed page ([LocalOrcaNavigation] can pop) shows a back arrow that
 * goes back, unless `automaticallyImplyLeading` is false. A title not
 * centred starts 16 past the leading box. The bar is `toolbarHeight` high
 * (Flutter's 56 when absent), in `backgroundColor`, and casts a shadow in
 * `shadowColor` at `elevation` (none when absent). Without a `shadowColor`
 * it casts none: Flutter's Material 3 AppBar shadow is transparent by
 * default. It pads itself for the status bar unless a Scaffold above
 * already did.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AppBarWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val background = Props.color(node["backgroundColor"])
    val height = Props.length(node["toolbarHeight"]) ?: 56.dp
    val elevation = Props.length(node["elevation"]) ?: 0.dp
    val shadowColor = Props.color(node["shadowColor"])
    val leadingWidth = Props.length(node["leadingWidth"]) ?: 56.dp
    val navigation = LocalOrcaNavigation.current
    val leadingId = node.slots["leading"]
    val impliesBack = leadingId == null && navigation.canPop && node["automaticallyImplyLeading"]?.boolValue != false
    val title: @Composable () -> Unit = { node.slots["title"]?.let { NodeView(it, model) } }
    val leading: @Composable () -> Unit = {
        if (leadingId != null || impliesBack) {
            // M3 sets the navigation icon 4 in and the title 4 past max(12, icon);
            // Flutter's leading box starts at 0 and its title 16 past the box.
            Box(
                Modifier.padding(end = 8.dp).offset(x = (-4).dp).size(leadingWidth, height),
                contentAlignment = Alignment.Center,
                propagateMinConstraints = leadingId != null,
            ) {
                if (leadingId != null) {
                    NodeView(leadingId, model)
                } else {
                    IconButton(onClick = navigation::goBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            }
        }
    }
    val actions: @Composable RowScope.() -> Unit = {
        for (id in indexedSlots(node, "action")) NodeView(id, model)
    }
    val colors = if (background != null) {
        TopAppBarDefaults.topAppBarColors(containerColor = background)
    } else {
        TopAppBarDefaults.topAppBarColors()
    }
    // TopAppBar takes no elevation; the shadow is drawn under the bar's box.
    val bar = if (shadowColor != null) {
        modifier.shadow(elevation, RectangleShape, clip = false, ambientColor = shadowColor, spotColor = shadowColor)
    } else {
        modifier
    }
    if (node["centerTitle"]?.boolValue == true) {
        CenterAlignedTopAppBar(
            title = title,
            modifier = bar,
            navigationIcon = leading,
            actions = actions,
            expandedHeight = height,
            colors = colors,
        )
    } else {
        TopAppBar(
            title = title,
            modifier = bar,
            navigationIcon = leading,
            actions = actions,
            expandedHeight = height,
            colors = colors,
        )
    }
}

/**
 * Card as Flutter's Material 3 Card: `color` (default the elevated card
 * colour) with `surfaceTintColor` laid over it at the opacity of its
 * `elevation` (default 1), a shadow at that elevation in `shadowColor`
 * (black when absent), `borderRadius` (default 12), inner `padding`, and
 * outer `margin` (default 4 on every side, the Material default). The child
 * is clipped to the card's shape only when `clipBehavior` asks for it
 * (Flutter's Card: `Clip.none` by default). A size forced on the Card
 * reaches its child.
 */
@Composable
internal fun CardWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val elevation = Props.length(node["elevation"]) ?: 1.dp
    val shape = RoundedCornerShape(Props.length(node["borderRadius"]) ?: 12.dp)
    val shadowColor = Props.color(node["shadowColor"]) ?: DefaultShadowColor
    val margin = Props.insets(node["margin"]) ?: Insets(4.0, 4.0, 4.0, 4.0)
    val padding = Props.insets(node["padding"]) ?: Insets.Zero
    val color = Props.color(node["color"]) ?: CardDefaults.elevatedCardColors().containerColor
    val tint = Props.color(node["surfaceTintColor"])
    val fill = tint?.copy(alpha = surfaceTintOpacity(elevation))?.compositeOver(color) ?: color
    // Drawn as M3 Surface draws (content colour, a semantics container that
    // takes the touches on it) but without its clip.
    CompositionLocalProvider(LocalContentColor provides contentColorFor(color)) {
        Box(
            modifier.padding(margin.paddingValues())
                .shadow(elevation, shape, clip = false, ambientColor = shadowColor, spotColor = shadowColor)
                .background(fill, shape)
                .then(if (Props.clips(node["clipBehavior"])) Modifier.clip(shape) else Modifier)
                .semantics { isTraversalGroup = true }
                .pointerInput(Unit) {},
            propagateMinConstraints = true,
        ) {
            Box(Modifier.padding(padding.paddingValues()), propagateMinConstraints = true) {
                ChildView(node, model)
            }
        }
    }
}

/**
 * Flutter `ElevationOverlay.applySurfaceTint`'s opacity at [elevation]:
 * 0 at 0, .05 at 1, .08 at 3, .11 at 6, .12 at 8, .14 at 12, linear
 * between, .14 above 12.
 */
private fun surfaceTintOpacity(elevation: Dp): Float {
    val e = elevation.value
    for ((low, high) in surfaceTintSteps.zipWithNext()) {
        if (e <= low.first) return low.second
        if (e < high.first) return low.second + (high.second - low.second) * (e - low.first) / (high.first - low.first)
    }
    return surfaceTintSteps.last().second
}

private val surfaceTintSteps = listOf(0f to 0f, 1f to 0.05f, 3f to 0.08f, 6f to 0.11f, 8f to 0.12f, 12f to 0.14f)
