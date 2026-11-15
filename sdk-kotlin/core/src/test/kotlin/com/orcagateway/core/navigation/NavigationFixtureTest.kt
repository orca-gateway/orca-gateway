package com.orcagateway.core.navigation

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.RouteTransitionDef
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * schema/fixtures/navigation through the Kotlin [RouteTable], as the Flutter
 * runner (sdk/test/conformance/navigation_fixtures_test.dart) runs them
 * through the real GoRouter. Each case builds the config, lays the fixture's
 * `appState` over `config.initialAppState`, resolves the location once and
 * compares every field of `expected`. A file's `sessions` run on a
 * [TabShell]: boot at `config.initialRoute`, then one operation per step, with
 * the location, the tab index, the app state and the page requests compared
 * after the boot and after every step.
 */
class NavigationFixtureTest {
    @Test
    fun b9_2_paramMatch() = runFiles("01_")

    @Test
    fun b9_3_unknownPath() = runFiles("02_", "03_")

    @Test
    fun b9_4_redirect() = runFiles("04_", "05_", "06_")

    @Test
    fun b9_5_initialAppState() = runFiles("07_")

    @Test
    fun b9_9_nestedChildren() = runFiles("08_")

    @Test
    fun b9_10_everyNavigationFixturePasses() {
        val files = Fixtures.navigationFiles().map { it.name }
        assertEquals(14, files.size, "navigation fixture files")
        val counts = files.map { runFile(it) }
        assertEquals(56, counts.sumOf { it.cases }, "navigation fixture cases")
        assertEquals(15, counts.sumOf { it.sessions }, "navigation fixture sessions")
        assertEquals(87, counts.sumOf { it.steps }, "navigation fixture session steps")
    }

    /** B10.2-CK: the tab sessions of file 12 pass on [TabShell]. */
    @Test
    fun b10_2_tabSessions() {
        assertEquals(Counts(0, 5, 36), countFiles("12_"))
    }

    /** B10.3-CK: `_tabIndex` (file 13) and `switchTab` (file 14) pass on [TabShell]. */
    @Test
    fun b10_3_tabIndexStateAndSwitchTab() {
        assertEquals(Counts(0, 10, 51), countFiles("13_", "14_"))
    }

    /** What no session pins, with the same answers as the Swift twin's test of the same name. */
    @Test
    fun unpinnedTabCornersAgreeWithSwift() {
        fun routes(vararg paths: String) = listOf(mapOf("name" to "main", "routes" to paths.map { mapOf("path" to it) }))
        val tabbed = RouteTable(
            NavConfig.fromJson(
                obj(
                    "initialRoute" to "/home",
                    "tabs" to listOf(
                        mapOf("id" to "home", "label" to "Home", "icon" to "home", "initialRoute" to "/home"),
                        mapOf("id" to "search", "label" to "Search", "icon" to "search", "initialRoute" to "/search"),
                    ),
                    "flows" to routes("home", "home/detail", "search", "settings"),
                ),
            ),
        )
        val none = TabShellChange(emptyList(), emptyList(), null)
        val state = emptyMap<String, JsonValue>()
        val ids = ArrayList<Int>()
        fun TabShellChange.seen(): TabShellChange = also { change -> ids += change.requested.map { it.id } }
        fun snapshot(shell: TabShell) = listOf(shell.hasShell, shell.currentTab, shell.tabStacks, shell.over, shell.location)

        val shell = TabShell(tabbed)
        assertEquals(0, shell.go("/home", state).seen().tabIndexWrite)
        shell.push("/home/detail", state).seen()
        val before = snapshot(shell)

        // 1. selectTab with an index outside the tabs: no change.
        assertEquals(none, shell.selectTab(2, state).seen())
        assertEquals(none, shell.selectTab(-1, state).seen())
        // 2. `_tabIndex` written with an int outside the tabs: no change, no write.
        assertEquals(none, shell.tabIndexChanged(j(2), state).seen())
        assertEquals(none, shell.tabIndexChanged(j(-1), state).seen())
        assertEquals(before, snapshot(shell))

        // 3. pop at a tab root with nothing over: no change.
        assertEquals(listOf("home/detail"), shell.pop().seen().dropped.map { it.pagePath })
        val atRoot = snapshot(shell)
        assertEquals(none, shell.pop().seen())
        assertEquals(atRoot, snapshot(shell))
        assertEquals("/home", shell.location)

        // 6. selectTab of another tab under a pushed route: the route is dropped and the tab restored.
        shell.selectTab(1, state).seen()
        shell.selectTab(0, state).seen()
        shell.push("/home/detail", state).seen()
        shell.push("/settings", state).seen()
        assertEquals(listOf("settings"), shell.over.map { it.pagePath })
        val restored = shell.selectTab(1, state).seen()
        assertEquals(emptyList(), restored.requested)
        assertEquals(listOf("settings"), restored.dropped.map { it.pagePath })
        assertEquals(1, restored.tabIndexWrite)
        assertEquals(emptyList(), shell.over)
        assertEquals("/search", shell.location)
        assertEquals(1, shell.tabIndex)
        assertEquals(listOf("home", "home/detail"), shell.tabStacks[0].map { it.pagePath })

        // 4. and 5. without tabs: pop at the root and switchTab change nothing.
        val plainShell = TabShell(RouteTable(NavConfig.fromJson(obj("initialRoute" to "/home", "flows" to routes("home", "other")))))
        assertEquals(listOf("home"), plainShell.go("/home", state).requested.map { it.pagePath })
        val plainBefore = snapshot(plainShell)
        assertEquals(none, plainShell.pop())
        assertEquals(none, plainShell.switchTab("home", state))
        assertEquals(none, plainShell.selectTab(0, state))
        assertEquals(none, plainShell.tabIndexChanged(j(0), state))
        assertEquals(plainBefore, snapshot(plainShell))
        assertEquals(false, plainShell.hasShell)
        assertNull(plainShell.tabIndex)
        assertEquals("/home", plainShell.location)

        // 7. entry ids are unique and increasing across every operation of a shell.
        shell.go("/settings", state).seen()
        shell.switchTab("home", state).seen()
        shell.go("/nope", state).seen()
        assertEquals(7, ids.size, "home, detail, search, detail, settings, settings, home: $ids")
        assertEquals(ids.toSet().size, ids.size, "unique: $ids")
        assertEquals(ids.sorted(), ids, "increasing: $ids")
        assertEquals(ids.last() + 1, shell.over.single().id, "the error entry is the newest")

        // Corners 8 to 14 on three tabs, `/home` with a child, and one route outside the tabs.
        val table = RouteTable(
            NavConfig.fromJson(
                obj(
                    "initialRoute" to "/home",
                    "tabs" to listOf(
                        mapOf("id" to "home", "label" to "Home", "icon" to "home", "initialRoute" to "/home"),
                        mapOf("id" to "search", "label" to "Search", "icon" to "search", "initialRoute" to "/search"),
                        mapOf("id" to "more", "label" to "More", "icon" to "more", "initialRoute" to "/more"),
                    ),
                    "flows" to listOf(
                        mapOf(
                            "name" to "main",
                            "routes" to listOf(
                                mapOf("path" to "home", "children" to listOf(mapOf("path" to "home/product/:id"))),
                                mapOf("path" to "search"),
                                mapOf("path" to "more"),
                                mapOf("path" to "settings"),
                            ),
                        ),
                    ),
                ),
            ),
        )
        fun List<TabShellEntry>.paths() = map { it.pagePath }
        fun List<TabShellEntry>.ids() = map { it.id }
        val noStacks = listOf(emptyList<TabShellEntry>(), emptyList(), emptyList())

        // 8. entry ids start at 1 and grow by 1 per created entry, error entries included.
        val a = TabShell(table)
        assertEquals(listOf(1, 2), a.go("/home/product/7?ref=x", state).requested.ids())
        assertEquals(none, a.push("/nope?x=1", state))
        assertEquals(3, a.over.single().id)
        assertEquals(listOf(4), a.push("/settings", state).requested.ids())

        // 9. an unknown location: an error entry on the stack, not requested, top, its path without slash and query.
        val pushedError = a.over.first()
        assertEquals(RouteResolutionKind.Error, pushedError.resolution.kind)
        assertEquals("nope", pushedError.pagePath)
        assertEquals(true, pushedError.isTop)
        assertEquals("/nope?x=1", pushedError.location)
        assertEquals(listOf("nope", "settings"), a.over.paths())
        // Pushed, it lies over the shell.
        assertEquals(true, a.hasShell)
        assertEquals(0, a.tabIndex)
        assertEquals(listOf("home", "home/product/7"), a.tabStacks[0].paths())
        assertEquals(listOf("settings"), a.pop().dropped.paths())
        assertEquals("/nope?x=1", a.location)
        // Gone to, it unmounts the shell as a route outside the tabs does.
        val lost = a.go("/missing/page?x=1", state)
        assertEquals(emptyList(), lost.requested)
        assertEquals(listOf("home", "home/product/7", "nope"), lost.dropped.paths())
        assertNull(lost.tabIndexWrite)
        assertEquals(false, a.hasShell)
        assertNull(a.tabIndex)
        assertEquals(noStacks, a.tabStacks)
        val goneError = a.over.single()
        assertEquals(5, goneError.id)
        assertEquals(RouteResolutionKind.Error, goneError.resolution.kind)
        assertEquals("missing/page", goneError.pagePath)
        assertEquals(true, goneError.isTop)
        assertEquals("/missing/page?x=1", a.location)
        val back = a.go("/home", state)
        assertEquals(listOf(6), back.requested.ids())
        assertEquals(listOf(5), back.dropped.ids())
        assertEquals(0, back.tabIndexWrite)

        // 10. locations: the resolution's for a top entry, "/" + pagePath under it; a missing leading slash is added.
        val b = TabShell(table)
        assertEquals("", b.location)
        assertEquals(listOf("home", "home/product/7"), b.go("home/product/7?ref=x", state).requested.paths())
        assertEquals(listOf(false, true), b.visible.map { it.isTop })
        assertEquals(listOf("/home", "/home/product/7?ref=x"), b.visible.map { it.location })
        assertEquals("/home/product/7?ref=x", b.visible.last().resolution.location)
        assertEquals("/home/product/7?ref=x", b.location)
        b.pop()
        assertEquals("/home", b.location)
        assertEquals(listOf("settings"), b.push("settings?from=home", state).requested.paths())
        assertEquals("/settings?from=home", b.over.single().location)
        assertEquals("/settings?from=home", b.location)
        assertEquals(emptyList(), b.push("nope", state).requested)
        assertEquals("nope", b.over.last().pagePath)
        assertEquals("/nope", b.location)

        // 11. `go` into a tab keeps an entry with the same page at the same position; the kept top follows the new location.
        val c = TabShell(table)
        val first = c.go("/search?q=a", state).requested.single()
        assertEquals(none, c.go("/search?q=a", state))
        val second = c.go("/search?q=b", state)
        assertEquals(emptyList(), second.requested)
        assertEquals(emptyList(), second.dropped)
        val kept = c.tabStacks[1].single()
        assertEquals(first.id, kept.id, "the same entry")
        assertEquals("/search?q=b", kept.location)
        assertEquals("/search?q=b", kept.resolution.location)
        assertEquals(true, kept.isTop)
        assertEquals("/search?q=b", c.location)
        // A kept page that becomes the top is the top; one that no longer is, is not.
        val h = TabShell(table)
        val (homeId, childId) = h.go("/home/product/7", state).requested.ids()
        val up = h.go("/home", state)
        assertEquals(emptyList(), up.requested)
        assertEquals(listOf(childId), up.dropped.ids())
        assertNull(up.tabIndexWrite)
        val root = h.visible.last()
        assertEquals(homeId, root.id)
        assertEquals(true, root.isTop)
        assertEquals("/home", root.location)
        assertEquals("/home", h.location)
        val down = h.go("/home/product/7", state)
        assertEquals(listOf("home/product/7"), down.requested.paths())
        assertTrue(down.requested.single().id != childId, "a new id")
        assertEquals(emptyList(), down.dropped)
        assertEquals(homeId, h.tabStacks[0].first().id)
        assertEquals(false, h.tabStacks[0].first().isTop)
        assertEquals(listOf("/home", "/home/product/7"), h.visible.map { it.location })

        // 12. with something over the shell, or no shell, every push goes onto `over`; reselect drops it all.
        val e = TabShell(table)
        e.go("/home", state)
        e.push("/home/product/1", state)
        e.push("/settings", state)
        assertEquals(listOf("home/product/2"), e.push("/home/product/2", state).requested.paths())
        assertEquals(listOf("home", "home/product/1"), e.tabStacks[0].paths())
        assertEquals(listOf("settings", "home/product/2"), e.over.paths())
        assertEquals("/home/product/2", e.location)
        val reselected = e.selectTab(0, state)
        assertEquals(emptyList(), reselected.requested)
        assertEquals(listOf("home/product/1", "settings", "home/product/2"), reselected.dropped.paths())
        assertNull(reselected.tabIndexWrite)
        assertEquals(emptyList(), e.over)
        assertEquals(listOf("home"), e.tabStacks[0].paths())
        assertEquals("/home", e.location)
        assertEquals(0, e.tabIndex)
        e.go("/settings", state)
        assertEquals(listOf("home/product/3"), e.push("/home/product/3", state).requested.paths())
        assertEquals(listOf("settings", "home/product/3"), e.over.paths())
        assertEquals(false, e.hasShell)
        assertNull(e.tabIndex)
        assertEquals(noStacks, e.tabStacks)

        // 13. `_tabIndex`: written by the shell on mount and on a tab change only; read as another valid int only.
        val f = TabShell(table)
        assertEquals(none, f.tabIndexChanged(j(1), state))
        assertEquals(0, f.go("/home", state).tabIndexWrite)
        val toSearch = f.tabIndexChanged(j(1), state)
        assertEquals(1, toSearch.tabIndexWrite)
        assertEquals(listOf("search"), toSearch.requested.paths())
        val onSearch = snapshot(f)
        assertEquals(none, f.tabIndexChanged(j(1), state))
        assertEquals(none, f.tabIndexChanged(j("0"), state))
        assertEquals(none, f.tabIndexChanged(j(1.5), state))
        assertEquals(none, f.tabIndexChanged(j(true), state))
        assertEquals(none, f.tabIndexChanged(JsonValue.Null, state))
        assertEquals(none, f.tabIndexChanged(null, state))
        assertEquals(onSearch, snapshot(f))
        assertEquals(TabShellChange(emptyList(), emptyList(), 0), f.tabIndexChanged(j(0), state))
        val inside = f.go("/home/product/9", state)
        assertEquals(listOf("home/product/9"), inside.requested.paths())
        assertNull(inside.tabIndexWrite)
        assertEquals(TabShellChange(emptyList(), emptyList(), 1), f.go("/search", state))
        // With no shell, `go` into a tab makes the whole chain anew.
        f.go("/settings", state)
        assertEquals(none, f.tabIndexChanged(j(1), state))
        val mounted = f.go("/home/product/9", state)
        assertEquals(listOf("home", "home/product/9"), mounted.requested.paths())
        assertEquals(listOf("settings"), mounted.dropped.paths())
        assertEquals(0, mounted.tabIndexWrite)
        f.go("/settings", state)
        val again = f.go("/home/product/9", state)
        assertEquals(listOf("home", "home/product/9"), again.requested.paths())
        assertTrue(again.requested.ids().min() > mounted.requested.ids().max(), "fresh entries")
        assertEquals(0, again.tabIndexWrite)

        // 14. an unknown location's error entry: its path without the query and without the `#fragment`.
        val i = TabShell(table)
        assertEquals(none.requested, i.go("/nowhere/x?y=1#frag", state).requested)
        assertEquals("nowhere/x", i.over.single().pagePath)
    }

    @Test
    fun transitionAndQueryOfTheFinalLocation() {
        val config = NavConfig.fromJson(
            obj(
                "flows" to listOf(
                    mapOf(
                        "name" to "main",
                        "routes" to listOf(
                            mapOf("path" to "home"),
                            mapOf("path" to "sheet/:id", "transition" to mapOf("type" to "slideUp", "duration" to 150)),
                            mapOf("path" to "old", "redirect" to mapOf("when" to "moved", "equals" to true, "to" to "/sheet/1?tab=a%20b")),
                        ),
                    ),
                ),
            ),
        )
        val table = RouteTable(config)

        val plain = table.resolve("/sheet/a%20b?ref=home&empty", emptyMap())
        assertEquals(RouteTransitionDef("slideUp", 150), plain.transition)
        assertEquals(mapOf("ref" to "home", "empty" to ""), plain.queryParameters)
        assertEquals(mapOf("id" to "a b"), plain.params)
        assertEquals("sheet/a%20b", plain.pagePath)
        assertNull(table.resolve("/home?x=1", emptyMap()).transition)

        val moved = table.resolve("/old?from=menu", props("moved" to true))
        assertEquals("/sheet/1?tab=a%20b", moved.location)
        assertTrue(moved.redirected)
        assertEquals("sheet/1", moved.pagePath)
        assertEquals(mapOf("tab" to "a b"), moved.queryParameters)
        assertEquals(RouteTransitionDef("slideUp", 150), moved.transition)

        val error = table.resolve("/nope?x=1", emptyMap())
        assertEquals(RouteResolutionKind.Error, error.kind)
        assertEquals(mapOf("x" to "1"), error.queryParameters)
        assertNull(error.pagePath)
        assertNull(error.routePath)
        assertEquals(emptyMap(), error.params)
        assertEquals(emptyList(), error.stack)
    }

    /** Inputs no fixture pins, with the same expectations as the Swift twin's test of the same name. */
    @Test
    fun unpinnedCornersAgreeWithSwift() {
        fun flows(vararg paths: String) = listOf(mapOf("name" to "main", "routes" to paths.map { mapOf("path" to it) }))

        val plain = RouteTable(NavConfig.fromJson(obj("flows" to flows("home/", "product/:id"))))
        assertEquals("/home", plain.resolve("/home", emptyMap()).routePath)
        assertEquals(mapOf("id" to "😀 x"), plain.resolve("/product/😀%20x", emptyMap()).params)
        assertEquals(mapOf("id" to "%FF"), plain.resolve("/product/%FF", emptyMap()).params)
        assertEquals(
            mapOf("q" to "%FF", "r" to "a b"),
            plain.resolve("/product/a?q=%FF&r=a+b", emptyMap()).queryParameters,
        )

        val tabbed = RouteTable(
            NavConfig.fromJson(
                obj(
                    "tabs" to listOf(
                        mapOf("id" to "home", "label" to "Home", "icon" to "home", "initialRoute" to "/home"),
                        mapOf("id" to "profile", "label" to "Profile", "icon" to "person", "initialRoute" to "/profile"),
                    ),
                    "flows" to flows("home", "profile", "😀stats", "ßeta"),
                ),
            ),
        )
        assertEquals("😀stats", tabbed.resolve("/😀stats", emptyMap()).scaffoldTitle)
        assertEquals("SSeta", tabbed.resolve("/ßeta", emptyMap()).scaffoldTitle)
    }

    /** Runs every file whose name starts with one of [prefixes]; each prefix must name a file. */
    private fun runFiles(vararg prefixes: String) {
        countFiles(*prefixes)
    }

    /** [runFiles], returning how much ran. */
    private fun countFiles(vararg prefixes: String): Counts {
        val names = Fixtures.navigationFiles().map { it.name }
        var total = Counts(0, 0, 0)
        for (prefix in prefixes) {
            val name = names.singleOrNull { it.startsWith(prefix) }
                ?: error("no single navigation fixture starts with $prefix")
            val ran = runFile(name)
            total = Counts(total.cases + ran.cases, total.sessions + ran.sessions, total.steps + ran.steps)
        }
        return total
    }

    /** How much of a file ran: its cases, its sessions and the steps of those. */
    private data class Counts(val cases: Int, val sessions: Int, val steps: Int)

    /**
     * Runs every case and every session of one file and returns how many
     * there were. A file carries `cases`, `sessions` or both, never neither.
     */
    private fun runFile(name: String): Counts {
        val fx = Fixtures.json("schema/fixtures/navigation/$name")
        val config = NavConfig.fromJson(fx["config"])
        val appState = config.initialAppState + fx["appState"].objectValue.orEmpty()
        val table = RouteTable(config)
        val cases = fx["cases"].arrayValue.orEmpty()
        val sessions = fx["sessions"].arrayValue.orEmpty()
        assertTrue(cases.isNotEmpty() || sessions.isNotEmpty(), "$name: no cases and no sessions")

        for (case in cases) {
            val at = "$name · ${case["name"].stringValue}"
            val location = case["location"].stringValue ?: error("$at: no location")
            val expected = case["expected"].objectValue ?: error("$at: no expected")
            val kind = expected["kind"]?.stringValue
            assertTrue(kind == "page" || kind == "error", "$at: unknown kind $kind")

            val got = table.resolve(location, appState)
            assertJsonEqual(asJson(got), JsonValue.Object(expected - "appState"), at)
            if (kind == "error") {
                assertNull(got.pagePath, "$at: an error has no page request")
                assertEquals(emptyList(), got.stack, "$at: an error has no stack")
            }
            expected["appState"]?.let { assertJsonEqual(JsonValue.Object(appState), it, "$at: appState") }
        }
        return Counts(cases.size, sessions.size, sessions.sumOf { runSession(name, config, table, it) })
    }

    /**
     * One session on a fresh [TabShell], as the Flutter runner runs it on a
     * fresh `OrcaApp`: the seeded app state (no file overlay), a boot `go` to
     * `config.initialRoute`, then the steps. Returns how many steps ran.
     */
    private fun runSession(name: String, config: NavConfig, table: RouteTable, session: JsonValue): Int {
        val label = "$name · ${session["name"].stringValue ?: error("$name: a session has no name")}"
        val appState = LinkedHashMap(config.initialAppState)
        val shell = TabShell(table)

        fun observe(change: TabShellChange, expected: JsonValue, at: String) {
            change.tabIndexWrite?.let { appState["_tabIndex"] = j(it) }
            val want = expected.objectValue ?: error("$at: no expected")
            assertEquals(setOf("location", "tabIndex", "appState", "pageRequests"), want.keys, "$at: expected keys")
            val subset = want.getValue("appState").objectValue ?: error("$at: appState is not an object")
            val seen = obj(
                "location" to shell.location,
                "tabIndex" to shell.tabIndex,
                "appState" to subset.keys.filter { it in appState }.associateWith { appState.getValue(it) },
                "pageRequests" to change.requested.map { it.pagePath },
            )
            assertJsonEqual(seen, expected, at)
        }

        observe(shell.go(config.initialRoute, appState), session["boot"]["expected"], "$label · boot")

        val steps = session["steps"].arrayValue.orEmpty()
        assertTrue(steps.isNotEmpty(), "$label: no steps")
        steps.forEachIndexed { index, step ->
            val op = step["op"].stringValue
            val at = "$label · step ${index + 1} $op"
            val change = when (op) {
                "go" -> shell.go(step["location"].stringValue ?: error("$at: no location"), appState)
                "push" -> shell.push(step["location"].stringValue ?: error("$at: no location"), appState)
                "back" -> shell.pop()
                "tapTab" -> shell.selectTab((step["index"].intValue ?: error("$at: no index")).toInt(), appState)
                "switchTab" -> shell.switchTab(step["tabId"].stringValue ?: error("$at: no tabId"), appState)
                "setAppState" -> {
                    val key = step["key"].stringValue ?: error("$at: no key")
                    val value = step.objectValue?.get("value") ?: error("$at: no value")
                    appState[key] = value
                    if (key == "_tabIndex") shell.tabIndexChanged(value, appState) else TabShellChange(emptyList(), emptyList(), null)
                }
                else -> error("$at: unknown op")
            }
            observe(change, step["expected"], at)
        }
        return steps.size
    }

    /** A resolution in the shape of a fixture's `expected`: three fields for an error, all of them for a page. */
    private fun asJson(r: RouteResolution): JsonValue = when (r.kind) {
        RouteResolutionKind.Error -> obj("kind" to "error", "location" to r.location, "redirected" to r.redirected)
        RouteResolutionKind.Page -> obj(
            "kind" to "page",
            "location" to r.location,
            "redirected" to r.redirected,
            "pagePath" to r.pagePath,
            "routePath" to r.routePath,
            "params" to r.params,
            "stack" to r.stack,
            "tabIndex" to r.tabIndex,
            "scaffoldTitle" to r.scaffoldTitle,
        )
    }
}
