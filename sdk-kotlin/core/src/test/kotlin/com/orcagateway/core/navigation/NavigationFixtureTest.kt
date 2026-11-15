package com.orcagateway.core.navigation

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.RouteTransitionDef
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.assertJsonEqual
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
 * compares every field of `expected`.
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
        assertEquals(11, files.size, "navigation fixture files")
        assertEquals(56, files.sumOf { runFile(it) }, "navigation fixture cases")
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
        val names = Fixtures.navigationFiles().map { it.name }
        for (prefix in prefixes) {
            val name = names.singleOrNull { it.startsWith(prefix) }
                ?: error("no single navigation fixture starts with $prefix")
            runFile(name)
        }
    }

    /** Runs every case of one file and returns how many there were (never zero). */
    private fun runFile(name: String): Int {
        val fx = Fixtures.json("schema/fixtures/navigation/$name")
        val config = NavConfig.fromJson(fx["config"])
        val appState = config.initialAppState + fx["appState"].objectValue.orEmpty()
        val table = RouteTable(config)
        val cases = fx["cases"].arrayValue.orEmpty()
        assertTrue(cases.isNotEmpty(), "$name: no cases")

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
        return cases.size
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
