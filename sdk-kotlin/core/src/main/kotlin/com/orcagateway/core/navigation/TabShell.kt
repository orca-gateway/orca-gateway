package com.orcagateway.core.navigation

import com.orcagateway.core.json.JsonValue

/** One page on a stack of a [TabShell]. */
public data class TabShellEntry(
    /** Unique within the shell, increasing in creation order; the first is 1. */
    val id: Int,
    /** The resolution that created the entry, or the last [TabShell.go] that kept it as its top page. */
    val resolution: RouteResolution,
    /**
     * The page this entry requests, an element of [RouteResolution.stack].
     * For the "page not found" entry, which requests nothing: the location's
     * path without its leading slash and its query.
     */
    val pagePath: String,
    /** The last page of its chain: the one [RouteResolution.scaffoldTitle], the transition and not-found are about. */
    val isTop: Boolean,
) {
    /** The location shown while this entry is on top: the resolution's for the top of a chain, `/` + [pagePath] under it. */
    val location: String get() = if (isTop) resolution.location else "/$pagePath"
}

/** What one operation of a [TabShell] changed. All empty and null: nothing. */
public data class TabShellChange(
    /**
     * Entries the operation created whose page is to be requested, in the
     * order Flutter requests them. A "page not found" entry requests nothing
     * and is not listed.
     */
    val requested: List<TabShellEntry> = emptyList(),
    /** Entries that left every stack. */
    val dropped: List<TabShellEntry> = emptyList(),
    /** The `_tabIndex` value the caller must write into app state; null: no write. */
    val tabIndexWrite: Int? = null,
)

/**
 * The page stacks of an app over time, pure: one stack per tab while the tab
 * shell is mounted, and the routes above it. A port of what GoRouter's
 * `StatefulShellRoute.indexedStack` and `OrcaShell`
 * (sdk/lib/src/widgets/orca_shell.dart) do, pinned by the `sessions` of
 * schema/fixtures/navigation:
 *
 * - A tab's page is requested on its first visit; switching tabs restores the
 *   tab's stack and requests nothing. A tap on the current tab pops it to its
 *   root.
 * - [go] into a tab keeps the pages of that tab's stack the new chain starts
 *   with (the same page at the same position; one that becomes the top takes
 *   the new location under the same id, so a query-only change requests
 *   nothing), and drops whatever was pushed over the shell. [go] to a route
 *   outside the tabs, or to no route, unmounts the shell and forgets every
 *   tab stack.
 * - [push] adds the top page only: on the current tab's stack for a tab route
 *   (any tab's), above the shell for a route outside the tabs or no route, and
 *   for every route once something lies above the shell.
 * - The shell asks for a `_tabIndex` write when it mounts and whenever the
 *   current tab changes; a `_tabIndex` written by someone else switches the
 *   tab when it is another tab's index.
 *
 * With a config that has no tabs the shell is never mounted and [over] is the
 * one stack: [go] replaces it with the whole chain, [push] adds the top page.
 * The caller owns app state: it passes it in and applies
 * [TabShellChange.tabIndexWrite] itself. Not thread-safe.
 */
public class TabShell(
    /** The route table every location is resolved with. */
    public val table: RouteTable,
) {
    private val tabs = table.config.tabs
    private var nextId = 1
    private var stacks: List<List<TabShellEntry>> = tabs.map { emptyList() }

    /** A tab shell is mounted: the config has tabs and the last [go] landed in one. */
    public var hasShell: Boolean = false
        private set

    /** The tab on screen (also under a pushed route); null when [hasShell] is false. */
    public var currentTab: Int? = null
        private set

    /** The routes above the shell, bottom to top; with no shell the whole stack. */
    public var over: List<TabShellEntry> = emptyList()
        private set

    /** One stack per tab of the config, bottom to top; empty: not visited since the shell was mounted. */
    public val tabStacks: List<List<TabShellEntry>> get() = stacks

    /** The stack on screen, bottom to top: the current tab's stack, then [over]. */
    public val visible: List<TabShellEntry> get() = currentTab?.let { stacks[it] }.orEmpty() + over

    /** The visible location, as `location` in the fixtures; empty before the first [go]. */
    public val location: String
        get() = visible.lastOrNull()?.location ?: ""

    /** As `tabIndex` in the fixtures: [currentTab]. */
    public val tabIndex: Int? get() = currentTab

    /** Boot and replace navigation (GoRouter.go) to [location], resolved against [appState]. */
    public fun go(location: String, appState: Map<String, JsonValue>): TabShellChange {
        val resolution = table.resolve(slashed(location), appState)
        val tab = resolution.tabIndex
        if (resolution.kind == RouteResolutionKind.Error || tab == null) {
            val dropped = stacks.flatten() + over
            stacks = tabs.map { emptyList() }
            hasShell = false
            currentTab = null
            over = chain(resolution, from = 0)
            return TabShellChange(requested = requests(over), dropped = dropped)
        }

        val mounting = !hasShell
        val changed = mounting || currentTab != tab
        val old = stacks[tab]
        // The pages the tab already shows at the bottom of the new chain stay.
        var kept = 0
        while (kept < old.size && kept < resolution.stack.size && old[kept].pagePath == resolution.stack[kept]) kept++
        val created = chain(resolution, from = kept)
        val dropped = old.drop(kept) + over

        // A kept page follows the new chain: its top takes the new resolution, the others lie under it.
        val last = resolution.stack.lastIndex
        val staying = old.take(kept).mapIndexed { index, entry ->
            if (index == last) entry.copy(resolution = resolution, isTop = true) else entry.copy(isTop = false)
        }
        stacks = stacks.toMutableList().also { it[tab] = staying + created }
        over = emptyList()
        hasShell = true
        currentTab = tab
        return TabShellChange(created, dropped, if (changed) tab else null)
    }

    /** Push [location] over what is shown (GoRouter.push): its top page only. */
    public fun push(location: String, appState: Map<String, JsonValue>): TabShellChange {
        val resolution = table.resolve(slashed(location), appState)
        val entry = chain(resolution, from = 0).last()
        val tab = currentTab
        if (tab != null && over.isEmpty() && resolution.tabIndex != null) {
            stacks = stacks.toMutableList().also { it[tab] = it[tab] + entry }
        } else {
            over = over + entry
        }
        return TabShellChange(requested = requests(listOf(entry)))
    }

    /** Pop the top page; nothing at a tab root or at the root of the one stack. */
    public fun pop(): TabShellChange {
        val tab = currentTab
        if (over.isNotEmpty()) {
            if (tab == null && over.size == 1) return TabShellChange()
            val top = over.last()
            over = over.dropLast(1)
            return TabShellChange(dropped = listOf(top))
        }
        if (tab == null || stacks[tab].size <= 1) return TabShellChange()
        val top = stacks[tab].last()
        stacks = stacks.toMutableList().also { it[tab] = it[tab].dropLast(1) }
        return TabShellChange(dropped = listOf(top))
    }

    /**
     * A tap on the tab bar: another tab is restored (or visited for the first
     * time), the current one pops to its root. Routes pushed over the shell
     * are dropped. No shell or an [index] outside the tabs: nothing.
     */
    public fun selectTab(index: Int, appState: Map<String, JsonValue>): TabShellChange {
        val tab = currentTab ?: return TabShellChange()
        if (index !in tabs.indices) return TabShellChange()
        if (index != tab) return show(index, appState)
        val dropped = stacks[tab].drop(1) + over
        stacks = stacks.toMutableList().also { it[tab] = it[tab].take(1) }
        over = emptyList()
        return TabShellChange(dropped = dropped)
    }

    /** The `switchTab` action: [go] to the tab's `initialRoute`. An unknown [tabId] or no tabs: nothing. */
    public fun switchTab(tabId: String, appState: Map<String, JsonValue>): TabShellChange {
        val tab = tabs.firstOrNull { it.id == tabId } ?: return TabShellChange()
        return go(tab.initialRoute, appState)
    }

    /**
     * App state `_tabIndex` was written by someone else with [value] (null:
     * removed). An integer that is another tab's index switches to that tab
     * as a tap would; anything else (not an integer, the current index, out
     * of range, no shell) does nothing.
     */
    public fun tabIndexChanged(value: JsonValue?, appState: Map<String, JsonValue>): TabShellChange {
        val tab = currentTab ?: return TabShellChange()
        val index = (value as? JsonValue.Int)?.value ?: return TabShellChange()
        if (index == tab.toLong() || index < 0 || index >= tabs.size) return TabShellChange()
        return show(index.toInt(), appState)
    }

    /** Switches to another tab: its stack as it was left, or a [go] to its `initialRoute` on a first visit. */
    private fun show(index: Int, appState: Map<String, JsonValue>): TabShellChange {
        if (stacks[index].isEmpty()) return go(tabs[index].initialRoute, appState)
        val dropped = over
        over = emptyList()
        currentTab = index
        return TabShellChange(dropped = dropped, tabIndexWrite = index)
    }

    /** The entries of [created] whose page is requested: all but the not-found entry. */
    private fun requests(created: List<TabShellEntry>): List<TabShellEntry> =
        created.filter { it.resolution.kind == RouteResolutionKind.Page }

    private fun slashed(location: String): String = if (location.startsWith("/")) location else "/$location"

    /** New entries for the pages of [resolution] from index [from] up; the one not-found entry for an error. */
    private fun chain(resolution: RouteResolution, from: Int): List<TabShellEntry> {
        if (resolution.kind == RouteResolutionKind.Error) {
            val path = resolution.location.substringBefore('#').substringBefore('?').trimStart('/')
            return listOf(TabShellEntry(nextId++, resolution, path, isTop = true))
        }
        return (from until resolution.stack.size).map {
            TabShellEntry(nextId++, resolution, resolution.stack[it], isTop = it == resolution.stack.lastIndex)
        }
    }
}
