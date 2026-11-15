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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DrawerDefaults
import androidx.compose.material3.DrawerState
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.LocalOrcaSnackbars
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.indexedSlots
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.style.IconNames
import com.orcagateway.sdk.style.Insets
import com.orcagateway.sdk.style.Props
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * The route a page is drawn for, and its router: how the page's Scaffold
 * hears that the router asked this route to open its own drawer
 * ([OrcaRouter.pageDrawerRequest]). Null for a page drawn without a router.
 */
internal data class PageDrawerHost(val router: OrcaRouter, val routeId: UUID)

internal val LocalOrcaPageDrawerHost = compositionLocalOf<PageDrawerHost?> { null }

/** What opens the drawers of the Scaffold an AppBar is the `appBar` of; null for a drawer it does not have. */
private class ScaffoldDrawers(val openStart: (() -> Unit)?, val openEnd: (() -> Unit)?)

private val LocalScaffoldDrawers = compositionLocalOf<ScaffoldDrawers?> { null }

/**
 * The layout direction a Drawer gives back to its child: set by a host that
 * turned the direction around to put the sheet on the trailing edge.
 */
private val LocalDrawerChildDirection = compositionLocalOf<LayoutDirection?> { null }

/**
 * Scaffold as the Material 3 `Scaffold`: the `appBar` slot is its top bar
 * (an AppBar draws as a `TopAppBar`; any other widget is drawn there as
 * is), `body` fills the rest at the top-start with loose constraints,
 * `floatingActionButton` floats bottom-end, and `bottomNavigationBar` sits
 * under the `persistentFooterButton_N` row. The page's snackbars show in its
 * `SnackbarHost` when it is the page root. Bottom sheets are not drawn yet.
 *
 * A `drawer` slot is a modal drawer on the leading edge and an `endDrawer`
 * slot one on the trailing edge ([PageDrawer]), each closed until it is
 * opened: by a swipe from its edge, by the menu button the AppBar shows for
 * it ([AppBarWidget]), and the leading one by the `openDrawer` action when
 * the router hands it to this page ([OrcaRouter.pageDrawerRequest], which
 * is then cleared). With both, a swipe opens the leading one only: the two
 * would take each other's swipes.
 *
 * Flutter's Scaffold lays out its slots with fresh, loose constraints, so a
 * size forced on the Scaffold reaches neither the AppBar title nor the body.
 */
@Composable
internal fun ScaffoldWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val snackbars = LocalOrcaSnackbars.current
    val window = LocalWindowInfo.current.containerSize

    val start = node.slots["drawer"]
    val end = node.slots["endDrawer"]
    val scope = rememberCoroutineScope()
    val startState = rememberDrawerState(DrawerValue.Closed)
    val endState = rememberDrawerState(DrawerValue.Closed)
    val drawers = remember(start != null, end != null) {
        ScaffoldDrawers(
            openStart = if (start != null) ({ scope.launch { startState.open() } }) else null,
            openEnd = if (end != null) ({ scope.launch { endState.open() } }) else null,
        )
    }
    val host = LocalOrcaPageDrawerHost.current
    val asked = start != null && host != null && host.router.pageDrawerRequest == host.routeId
    LaunchedEffect(asked) {
        if (asked) {
            host.router.pageDrawerRequest = null
            // Not in this effect: clearing the request ends it.
            drawers.openStart?.invoke()
        }
    }

    CompositionLocalProvider(LocalOrcaSnackbars provides null) {
        PageDrawer(start, startState, end = false, gestures = true, model, modifier.boundedBy(window)) { inner ->
            PageDrawer(end, endState, end = true, gestures = start == null || endState.isOpen, model, inner) { innermost ->
                ScaffoldFrame(node, model, innermost, snackbars, drawers)
            }
        }
    }
}

/**
 * A Scaffold's drawer around its [content], a Material 3
 * `ModalNavigationDrawer`: the slot's widget (a Drawer draws the sheet) on
 * the leading edge, or on the trailing one for [end], behind a scrim whose
 * tap closes it. Without a [drawer] it is the content alone, which then
 * takes the [modifier].
 *
 * Material 3 has no trailing drawer: for one the layout direction is turned
 * around for the drawer, and turned back for the content and inside the
 * sheet.
 */
@Composable
private fun PageDrawer(
    drawer: String?,
    state: DrawerState,
    end: Boolean,
    gestures: Boolean,
    model: OrcaPageModel,
    modifier: Modifier,
    content: @Composable (Modifier) -> Unit,
) {
    if (drawer == null) {
        content(modifier)
        return
    }
    val direction = LocalLayoutDirection.current
    val edge = when {
        !end -> direction
        direction == LayoutDirection.Ltr -> LayoutDirection.Rtl
        else -> LayoutDirection.Ltr
    }
    // A Drawer keeps the turned direction for its sheet (the rounded corners face the page) and turns its child back.
    val isSheet = model.renderer.node(drawer)?.type == "Drawer"
    CompositionLocalProvider(LocalLayoutDirection provides edge) {
        ModalNavigationDrawer(
            drawerContent = {
                Box(Modifier.testTag(scaffoldDrawerTag(end))) {
                    CompositionLocalProvider(
                        LocalLayoutDirection provides if (isSheet) edge else direction,
                        LocalDrawerChildDirection provides if (isSheet) direction else null,
                    ) {
                        NodeView(drawer, model)
                    }
                }
            },
            modifier = modifier,
            drawerState = state,
            gesturesEnabled = gestures,
        ) {
            CompositionLocalProvider(LocalLayoutDirection provides direction) { content(Modifier) }
        }
    }
}

/** The Scaffold itself, inside its drawers: bars, body, floating button, snackbars. */
@Composable
private fun ScaffoldFrame(
    node: ResolvedNode,
    model: OrcaPageModel,
    modifier: Modifier,
    snackbars: SnackbarHostState?,
    drawers: ScaffoldDrawers,
) {
    val footer = indexedSlots(node, "persistentFooterButton")
    val bottomBar = node.slots["bottomNavigationBar"]
    Scaffold(
        modifier = modifier,
        topBar = {
            node.slots["appBar"]?.let {
                CompositionLocalProvider(LocalScaffoldDrawers provides drawers) { NodeView(it, model) }
            }
        },
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
 *
 * As the `appBar` of a Scaffold with drawers it shows a menu button for
 * each side it leaves empty, as Flutter's AppBar does: the leading one for
 * `drawer` when it has no `leading` (and `automaticallyImplyLeading` is not
 * false), the trailing one for `endDrawer` when it has no action.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AppBarWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val background = Props.color(node["backgroundColor"])
    val height = Props.length(node["toolbarHeight"]) ?: TopAppBarDefaults.TopAppBarExpandedHeight
    val title: @Composable () -> Unit = { node.slots["title"]?.let { NodeView(it, model) } }
    val drawers = LocalScaffoldDrawers.current
    val openStart = if (node["automaticallyImplyLeading"]?.boolValue != false) drawers?.openStart else null
    val leading: @Composable () -> Unit = {
        val own = node.slots["leading"]
        when {
            own != null -> NodeView(own, model)
            openStart != null -> DrawerMenuButton(SCAFFOLD_DRAWER_MENU_TAG, openStart)
        }
    }
    val openEnd = drawers?.openEnd
    val actions: @Composable RowScope.() -> Unit = {
        val own = indexedSlots(node, "action")
        for (id in own) NodeView(id, model)
        if (own.isEmpty() && openEnd != null) DrawerMenuButton(SCAFFOLD_END_DRAWER_MENU_TAG, openEnd)
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

/** The menu button an AppBar shows for a drawer of its Scaffold (Flutter's `DrawerButton`, `EndDrawerButton`). */
@Composable
private fun DrawerMenuButton(tag: String, open: () -> Unit) {
    IconButton(onClick = open, modifier = Modifier.testTag(tag)) {
        Icon(Icons.Filled.Menu, contentDescription = "Open navigation menu")
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

/** The test tag of item [index] of a BottomNavigationBar. */
internal fun bottomNavItemTag(index: Int): String = "orca-bottom-nav-item-$index"

/** The most items a BottomNavigationBar reads: slots `item_0` to `item_9`. */
private const val BOTTOM_NAV_SLOTS = 10

/** One item of a bar: the BottomNavItem's props as sent, not resolved (Flutter reads them raw). */
internal data class BottomNavEntry(val icon: String?, val activeIcon: String?, val label: String)

/**
 * The bar's items: the BottomNavItem nodes in slots `item_0` to `item_9`, in
 * order, stopping at the first slot that is missing or names no node (the
 * Flutter builder breaks there too).
 */
internal fun bottomNavEntries(node: ResolvedNode, model: OrcaPageModel): List<BottomNavEntry> {
    val entries = ArrayList<BottomNavEntry>()
    for (id in indexedSlots(node, "item").take(BOTTOM_NAV_SLOTS)) {
        val props = model.renderer.node(id)?.props ?: break
        entries.add(
            BottomNavEntry(
                icon = props["icon"]?.stringValue,
                activeIcon = props["activeIcon"]?.stringValue,
                label = props["label"]?.stringValue ?: "",
            ),
        )
    }
    return entries
}

/** The selected item: the resolved `currentIndex` (0 by default), kept inside the [count] items. */
internal fun bottomNavIndex(node: ResolvedNode, count: Int): Int =
    (Props.number(node["currentIndex"])?.toInt() ?: 0).coerceIn(0, maxOf(count - 1, 0))

/**
 * A tap on item [index], Flutter's `onTap`: when the bar's `currentIndex`
 * was sent as a state Value (`{type: "state", key, scope}`) the index is
 * written into that key first (app state for scope `app`, else page state),
 * then `onChange` runs with `{value: index}`. The job is the `onChange`
 * run, or null when the bar has none.
 */
internal fun bottomNavTap(node: ResolvedNode, model: OrcaPageModel, index: Int): Job? {
    val value = JsonValue.Int(index.toLong())
    val bound = model.renderer.node(node.id)?.props?.get("currentIndex")
    if (bound?.get("type")?.stringValue == "state") {
        bound["key"].stringValue?.let { key ->
            val scope = if (bound["scope"].stringValue == "app") StateScope.App else StateScope.Page
            model.store.dispatch(mapOf(key to value), scope)
        }
    }
    return model.fire("onChange", on = node, eventData = mapOf("value" to value))
}

/**
 * BottomNavigationBar as the Material 3 `NavigationBar`: one
 * `NavigationBarItem` per BottomNavItem in slots `item_0` to `item_9`
 * ([bottomNavEntries]), the `currentIndex` one selected and showing its
 * `activeIcon` when it has one. `backgroundColor` is the container colour,
 * `selectedItemColor` and `unselectedItemColor` tint icon and label. No
 * items draws nothing. A tap is [bottomNavTap]; item i carries the test tag
 * [bottomNavItemTag].
 */
@Composable
internal fun BottomNavigationBarWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val entries = bottomNavEntries(node, model)
    if (entries.isEmpty()) return
    val current = bottomNavIndex(node, entries.size)
    val selectedColor = Props.color(node["selectedItemColor"])
    val unselectedColor = Props.color(node["unselectedItemColor"])
    val defaults = NavigationBarItemDefaults.colors()
    val colors = NavigationBarItemDefaults.colors(
        selectedIconColor = selectedColor ?: defaults.selectedIconColor,
        selectedTextColor = selectedColor ?: defaults.selectedTextColor,
        unselectedIconColor = unselectedColor ?: defaults.unselectedIconColor,
        unselectedTextColor = unselectedColor ?: defaults.unselectedTextColor,
    )
    NavigationBar(
        modifier = modifier,
        containerColor = Props.color(node["backgroundColor"]) ?: NavigationBarDefaults.containerColor,
    ) {
        entries.forEachIndexed { i, entry ->
            val selected = i == current
            NavigationBarItem(
                selected = selected,
                onClick = { bottomNavTap(node, model, i) },
                icon = {
                    val name = if (selected && entry.activeIcon != null) entry.activeIcon else entry.icon
                    Icon(IconNames.vector(name), contentDescription = null)
                },
                modifier = Modifier.testTag(bottomNavItemTag(i)),
                label = { Text(entry.label) },
                colors = colors,
            )
        }
    }
}

/**
 * BottomNavItem outside a bar (a bar reads its items itself): the icon and,
 * when there is one, the label 4 after it in a row, as the Flutter builder.
 */
@Composable
internal fun BottomNavItemWidget(node: ResolvedNode, modifier: Modifier) {
    val label = node["label"]?.stringValue ?: ""
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(IconNames.vector(node["icon"]?.stringValue), contentDescription = null)
        if (label.isNotEmpty()) Text(label)
    }
}

/**
 * Drawer as a Material 3 `ModalDrawerSheet`: `backgroundColor` (default the
 * theme's surface), `width` (default the sheet's own, 240 to 360; never
 * wider than the space given), `elevation` as tonal elevation and shadow
 * (default the sheet's). Its child fills the sheet; no child is an empty
 * sheet. Drawn where it stands: opening and closing belong to its host. On
 * the trailing edge ([PageDrawer]) the sheet is mirrored and the child is
 * not.
 */
@Composable
internal fun DrawerWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val elevation = Props.length(node["elevation"])
    val childDirection = LocalDrawerChildDirection.current
    val shape = DrawerDefaults.shape
    var sheet = modifier
    Props.length(node["width"])?.let { sheet = sheet.width(it) }
    if (elevation != null) sheet = sheet.shadow(elevation, shape)
    ModalDrawerSheet(
        modifier = sheet,
        drawerShape = shape,
        drawerContainerColor = Props.color(node["backgroundColor"]) ?: MaterialTheme.colorScheme.surface,
        drawerTonalElevation = elevation ?: DrawerDefaults.ModalDrawerElevation,
    ) {
        CompositionLocalProvider(
            LocalLayoutDirection provides (childDirection ?: LocalLayoutDirection.current),
            LocalDrawerChildDirection provides null,
        ) {
            Box(Modifier.fillMaxSize(), propagateMinConstraints = true) {
                ChildView(node, model)
            }
        }
    }
}

/** The test tag of the sheet side of a page Scaffold's `drawer`, or of its `endDrawer`. */
internal fun scaffoldDrawerTag(end: Boolean): String = if (end) "orca-scaffold-end-drawer" else "orca-scaffold-drawer"

/** The test tag of the menu button an AppBar shows for its Scaffold's `drawer`. */
internal const val SCAFFOLD_DRAWER_MENU_TAG: String = "orca-scaffold-drawer-menu"

/** The test tag of the menu button an AppBar shows for its Scaffold's `endDrawer`. */
internal const val SCAFFOLD_END_DRAWER_MENU_TAG: String = "orca-scaffold-end-drawer-menu"
