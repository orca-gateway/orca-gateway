package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.Surface
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.LocalOrcaSnackbars
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.indexedSlots
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
 * AppBar as a Material 3 top app bar: `CenterAlignedTopAppBar` when
 * `centerTitle` is true, `TopAppBar` otherwise (Flutter's Android default).
 * The `title` slot is the title (in the bar's title style unless it has its
 * own), `leading` the navigation icon, `action_N` the actions;
 * `backgroundColor` and `toolbarHeight` as sent. It pads itself for the
 * status bar unless a Scaffold above already did.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AppBarWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val background = Props.color(node["backgroundColor"])
    val height = Props.length(node["toolbarHeight"]) ?: TopAppBarDefaults.TopAppBarExpandedHeight
    val title: @Composable () -> Unit = { node.slots["title"]?.let { NodeView(it, model) } }
    val leading: @Composable () -> Unit = { node.slots["leading"]?.let { NodeView(it, model) } }
    val actions: @Composable RowScope.() -> Unit = {
        for (id in indexedSlots(node, "action")) NodeView(id, model)
    }
    val colors = if (background != null) {
        TopAppBarDefaults.topAppBarColors(containerColor = background)
    } else {
        TopAppBarDefaults.topAppBarColors()
    }
    if (node["centerTitle"]?.boolValue == true) {
        CenterAlignedTopAppBar(
            title = title,
            modifier = modifier,
            navigationIcon = leading,
            actions = actions,
            expandedHeight = height,
            colors = colors,
        )
    } else {
        TopAppBar(
            title = title,
            modifier = modifier,
            navigationIcon = leading,
            actions = actions,
            expandedHeight = height,
            colors = colors,
        )
    }
}

/**
 * Card as a Material 3 elevated card surface (Flutter's Material 3 Card):
 * `color` (default the elevated card colour), `elevation` (default 1),
 * `borderRadius` (default 12), `shadowColor`, inner `padding`, and outer
 * `margin` (default 4 on every side, the Material default). A size forced
 * on the Card reaches its child.
 */
@Composable
internal fun CardWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val elevation = Props.length(node["elevation"]) ?: 1.dp
    val shape = RoundedCornerShape(Props.length(node["borderRadius"]) ?: 12.dp)
    val shadowColor = Props.color(node["shadowColor"])
    val margin = Props.insets(node["margin"]) ?: Insets(4.0, 4.0, 4.0, 4.0)
    val padding = Props.insets(node["padding"]) ?: Insets.Zero
    var outer = modifier.padding(margin.paddingValues())
    // Surface's shadow takes no colour, so a coloured one is drawn here.
    if (shadowColor != null) outer = outer.shadow(elevation, shape, ambientColor = shadowColor, spotColor = shadowColor)
    Surface(
        modifier = outer,
        shape = shape,
        color = Props.color(node["color"]) ?: CardDefaults.elevatedCardColors().containerColor,
        shadowElevation = if (shadowColor != null) 0.dp else elevation,
    ) {
        Box(Modifier.padding(padding.paddingValues()), propagateMinConstraints = true) {
            ChildView(node, model)
        }
    }
}
