package com.orcagateway.core.capabilities

import com.orcagateway.core.models.Action
import com.orcagateway.core.models.BoolExpr
import com.orcagateway.core.models.Value
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.core.support.Fixtures
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * T6.1.6: the generated caps vector advertises only widgets the manifest gives
 * the `android` target, equals sdk-kotlin/capabilities.json, and Kotlin's
 * canonicalisation hashes exactly like the engine's.
 */
class CapabilitiesTest {
    private fun json(path: String): JsonElement =
        Json.parseToJsonElement(File(Fixtures.repoRoot, path).readText())

    private fun strings(element: JsonElement?): Set<String> =
        element?.jsonArray?.map { it.jsonPrimitive.content }?.toSet() ?: emptySet()

    private fun manifestAndroidWidgets(): Set<String> {
        val widgets = json("schema/widget-registry.json").jsonObject["widgets"]!!.jsonArray
        assertEquals(93, widgets.size)
        return widgets.mapNotNull { w ->
            val o = w.jsonObject
            if ("android" in strings(o["targets"])) o["type"]!!.jsonPrimitive.content else null
        }.toSet()
    }

    @Test
    fun widgetsAreAndroidTargetsAndMatchTheImplementedList() {
        val android = manifestAndroidWidgets()
        val advertised = GeneratedCapabilities.widgets.toSet()
        assertTrue(android.containsAll(advertised), "advertised without android target: ${advertised - android}")
        val listed = strings(json("sdk-kotlin/capabilities.json").jsonObject["widgets"])
        assertEquals(listed, advertised)
        // Android draws Material, so no widget lacks the android target.
        assertEquals(93, android.size)
    }

    /**
     * S9.13: Android draws the iOS set, the 15 core widgets plus the ten S9
     * added and then AnimatedBuilder, Transform and Video, and the generated vector is the regenerated list (sorted as the
     * generator sorts, hashed as the engine hashes), not a hand edit.
     *
     * B10.C-K: S10 adds Drawer, BottomNavigationBar and BottomNavItem, so the
     * pin moves from 28 to 31 (a pin moved to the new truth).
     *
     * B12.2-K to B12.5-K: S12 adds AnimatedContainer, AnimatedOpacity,
     * AnimatedAlign, AnimatedSwitcher and Hero, so the pin moves from 31 to
     * 36 (again to the new truth).
     *
     * A3.1: native parity step 3 adds the 13 layout wrappers ([A3_1]), so the
     * pin moves on to 49; Swift lands the same 13 in the same step.
     *
     * A4.x: native parity step 4 adds the 11 effect and touch wrappers ([A4]),
     * so the pin moves from 49 to 60; Swift lands the same 11 in the same step.
     *
     * B13.3-K: S13 adds ReorderableListView, 60 to 61.
     *
     * B13.4-K: S13 adds SubPage, 61 to 62.
     *
     * C18.4: S18 adds UnsupportedWidgetPlaceholder: the pin moves to 63.
     *
     * A5.x: native parity step 5 adds its five scroll widgets ([A5]), so the
     * pin moves from 63 to 68; Swift lands the same five in the same step.
     *
     * B13.1-K, B13.2-K: native parity step 13 adds CustomScrollView and the
     * four slivers ([SLIVERS]), so the pin moves from 68 to 73; Swift lands
     * the same five in the same step.
     */
    @Test
    fun c1_kotlinAdvertisesTheSame73WidgetsAsSwift() {
        val kotlin = json("sdk-kotlin/capabilities.json").jsonObject["widgets"]!!.jsonArray.map { it.jsonPrimitive.content }
        val swift = strings(json("sdk-swift/capabilities.json").jsonObject["widgets"])
        assertEquals(73, kotlin.size)
        assertEquals(swift, kotlin.toSet())
        assertEquals(kotlin.sorted(), kotlin, "capabilities.json keeps its widgets sorted")
        val added = setOf(
            "Icon", "Image", "Container", "Expanded", "Spacer", "TextField",
            "Stack", "Positioned", "ClipRRect", "GestureDetector",
            "AnimatedBuilder", "Transform", "Video",
        )
        assertTrue(kotlin.containsAll(added), "missing: ${added - kotlin.toSet()}")
        val s10 = setOf("BottomNavItem", "BottomNavigationBar", "Drawer")
        assertTrue(kotlin.containsAll(s10), "missing: ${s10 - kotlin.toSet()}")
        assertTrue(GeneratedCapabilities.widgets.containsAll(s10), "not advertised: ${s10 - GeneratedCapabilities.widgets.toSet()}")
        val s12 = setOf("AnimatedAlign", "AnimatedContainer", "AnimatedOpacity", "AnimatedSwitcher", "Hero")
        assertTrue(kotlin.containsAll(s12), "missing: ${s12 - kotlin.toSet()}")
        assertTrue(GeneratedCapabilities.widgets.containsAll(s12), "not advertised: ${s12 - GeneratedCapabilities.widgets.toSet()}")
        assertTrue(kotlin.containsAll(A3_1), "missing: ${A3_1 - kotlin.toSet()}")
        assertTrue(kotlin.containsAll(A4), "missing: ${A4 - kotlin.toSet()}")
        assertTrue("ReorderableListView" in kotlin, "missing: ReorderableListView")
        assertTrue("ReorderableListView" in GeneratedCapabilities.widgets, "not advertised: ReorderableListView")
        assertTrue("SubPage" in kotlin, "missing: SubPage")
        assertTrue("SubPage" in GeneratedCapabilities.widgets, "not advertised: SubPage")
        assertTrue("UnsupportedWidgetPlaceholder" in GeneratedCapabilities.widgets, "S18's UnsupportedWidgetPlaceholder is not advertised")
        assertTrue(kotlin.containsAll(A5), "missing: ${A5 - kotlin.toSet()}")
        assertTrue(kotlin.containsAll(SLIVERS), "missing: ${SLIVERS - kotlin.toSet()}")
        assertEquals(kotlin, GeneratedCapabilities.widgets)
        assertEquals(GeneratedCapabilities.capsHash, CapabilityVector.current.hash)
    }

    /**
     * A3.1: Compose draws the 13 layout wrappers, so the generated vector
     * advertises them and the core registry lets them through instead of
     * degrading them; WidgetBuildersTest pins standard() to the same set.
     * The pin is 73: with S12's 5 animated ones (49), then native parity
     * step 4's 11 effect and touch wrappers (A4.x, 60), then S13's
     * ReorderableListView and SubPage, then S18's
     * UnsupportedWidgetPlaceholder (63), then native parity step 5's five
     * scroll widgets (A5.x, 68), then step 13's CustomScrollView and four
     * slivers (B13.1-K, B13.2-K).
     */
    @Test
    fun a3_1_theThirteenLayoutWrappersAreAdvertisedAndLetThrough() {
        val advertised = GeneratedCapabilities.widgets.toSet()
        assertEquals(emptySet(), A3_1 - advertised, "not advertised")
        assertEquals(73, GeneratedCapabilities.widgets.size)
        assertEquals(emptySet(), A3_1 - WidgetRegistry.shared.types, "degraded by the core registry")
    }

    /**
     * A4.x: Compose draws native parity step 4's 11 effect and touch wrappers,
     * so capabilities.json lists each of them, the generated vector advertises
     * each once, every one carries the manifest's android target, and the core
     * registry lets them through; WidgetBuildersTest pins standard() to the
     * same set.
     */
    @Test
    fun a4_x_theElevenEffectAndTouchWrappersAreAdvertisedAndLetThrough() {
        val listed = strings(json("sdk-kotlin/capabilities.json").jsonObject["widgets"])
        assertEquals(emptySet(), A4 - listed, "not in capabilities.json")
        for (wrapper in A4.sorted()) {
            assertEquals(
                1, GeneratedCapabilities.widgets.count { it == wrapper },
                "$wrapper is not advertised exactly once",
            )
        }
        assertEquals(emptySet(), A4 - manifestAndroidWidgets(), "a wrapper lacks the android target")
        assertEquals(emptySet(), A4 - WidgetRegistry.shared.types, "degraded by the core registry")
    }

    /**
     * A5.x: Compose draws native parity step 5's five scroll widgets (A5.1-A5.5,
     * A5.7), so capabilities.json lists each of them, the generated vector
     * advertises each once, every one carries the manifest's android target,
     * and the core registry lets them through; WidgetBuildersTest pins
     * standard() to the same set.
     */
    @Test
    fun a5_x_theFiveScrollWidgetsAreAdvertisedAndLetThrough() {
        val listed = strings(json("sdk-kotlin/capabilities.json").jsonObject["widgets"])
        assertEquals(emptySet(), A5 - listed, "not in capabilities.json")
        for (widget in A5.sorted()) {
            assertEquals(
                1, GeneratedCapabilities.widgets.count { it == widget },
                "$widget is not advertised exactly once",
            )
        }
        assertEquals(emptySet(), A5 - manifestAndroidWidgets(), "a widget lacks the android target")
        assertEquals(emptySet(), A5 - WidgetRegistry.shared.types, "degraded by the core registry")
    }

    /**
     * C14.6: native parity step 14 implements persistState and clearState
     * (SavedState), so the pin moves from 24 to 26; Swift advertises the
     * same two in the same step.
     */
    @Test
    fun c14_6_actionKindsMatchTheImplementedList() {
        val listed = strings(json("sdk-kotlin/capabilities.json").jsonObject["actionKinds"])
        assertEquals(listed, GeneratedCapabilities.actionKinds.toSet())
        assertTrue(Action.kinds.toSet().containsAll(listed), "not wire kinds: ${listed - Action.kinds.toSet()}")
        // S12 added animateForward and animateReverse: 20 to 22. B13.5-K: S13 added updateSubPage, 23.
        // Step 5 added refetchPage (A5.6): 24. Step 14 added persistState and clearState: 26.
        assertEquals(26, listed.size)
        assertTrue(listed.containsAll(setOf("animateForward", "animateReverse")))
        assertTrue("updateSubPage" in listed, "missing: updateSubPage")
        assertTrue("refetchPage" in listed, "missing: refetchPage")
        assertTrue(listed.containsAll(setOf("switchTab", "openDrawer")))
        // Step 2 added the fire-mode wrappers and the debugLog effect.
        assertTrue(listed.containsAll(setOf("once", "always", "debugLog")), "missing: ${setOf("once", "always", "debugLog") - listed}")
        // Step 14 added the saved-state actions.
        assertTrue(listed.containsAll(setOf("persistState", "clearState")), "missing: ${setOf("persistState", "clearState") - listed}")
        assertEquals(GeneratedCapabilities.actionKinds.sorted(), GeneratedCapabilities.actionKinds, "the generator sorts the kinds")
        // Swift's twin: the iOS SDK advertises the same 26 kinds.
        assertEquals(strings(json("sdk-swift/capabilities.json").jsonObject["actionKinds"]), listed)
        // The executor runs exactly what is advertised, plus the server-only
        // replaceComponent (not in action.ts, so never advertised).
        assertEquals(listed + "replaceComponent", ActionExecutor.kinds)
    }

    /**
     * A5.6: the executor runs refetchPage (a no-op on its own, the page
     * loader's handler reloads, as Flutter's onRefetchPage), so the vector
     * advertises it once and the engine stops dropping nodes that carry it.
     */
    @Test
    fun a5_6_refetchPageIsAdvertisedAndRunByTheExecutor() {
        val listed = json("sdk-kotlin/capabilities.json").jsonObject["actionKinds"]!!.jsonArray.map { it.jsonPrimitive.content }
        assertTrue("refetchPage" in listed, "not in capabilities.json")
        assertEquals(listed.sorted(), listed, "capabilities.json keeps its action kinds sorted")
        assertEquals(1, GeneratedCapabilities.actionKinds.count { it == "refetchPage" }, "not advertised exactly once")
        assertTrue("refetchPage" in ActionExecutor.kinds, "not an executor kind")
        assertTrue(ActionExecutor.implements(Action.RefetchPage), "not implemented")
    }

    @Test
    fun valueKindsTransformsAndOpsComeFromTheEngine() {
        assertEquals(9, GeneratedCapabilities.valueKinds.size)
        assertEquals(31, GeneratedCapabilities.transformKinds.size)
        assertEquals(13, GeneratedCapabilities.boolExprOps.size)
        // The typed models know every advertised kind and op.
        assertEquals(Value.kinds.toSet(), GeneratedCapabilities.valueKinds.toSet())
        assertEquals(BoolExpr.ops.toSet(), GeneratedCapabilities.boolExprOps.toSet())
    }

    @Test
    fun semverAndProtocolComeFromTheirFiles() {
        assertEquals(File(Fixtures.repoRoot, "sdk-kotlin/VERSION").readText().trim(), GeneratedCapabilities.sdkSemver)
        assertEquals(
            json("schema/protocol.json").jsonObject["protocolVersion"]!!.jsonPrimitive.content,
            GeneratedCapabilities.protocolVersion,
        )
    }

    @Test
    fun hashMatchesTheEngineCanonicalisation() {
        // The generator hashed the vector with the engine's own
        // canonicalizeVector(); Kotlin must reach the same digest.
        assertEquals(GeneratedCapabilities.capsHash, CapabilityVector.current.hash)
    }

    @Test
    fun pinnedEngineVector() {
        // engine/test/capability-vector-cache.test.ts "known pinned-hash"; the
        // Dart and Swift SDKs pin the same value.
        val vector = CapabilityVector(
            protocolVersion = "1.0.0", sdkSemver = "0.1.0", widgets = listOf("b", "a"),
            valueKinds = listOf("static"), actionKinds = emptyList(), transformKinds = emptyList(),
            boolExprOps = emptyList(),
        )
        assertEquals(
            """{"protocolVersion":"1.0.0","sdkSemver":"0.1.0","widgets":["a","b"],"valueKinds":["static"],"actionKinds":[],"transformKinds":[],"boolExprOps":[]}""",
            vector.canonicalJson(),
        )
        assertEquals("c71ebd593604aa669274ce2d318d9d97b38facae6ca26360201907fda433db84", vector.hash)
    }

    @Test
    fun canonicalJsonEscapesLikeJsonStringify() {
        assertEquals("\"a/b\"", CapabilityVector.jsString("a/b"))
        assertEquals("\"q\\\"\\\\\"", CapabilityVector.jsString("q\"\\"))
        assertEquals("\"\\n\\u0001é\"", CapabilityVector.jsString("\n\u0001é"))
        // UTF-16 code-unit order, as Array.prototype.sort: "Z" < "a" < "é".
        val v = CapabilityVector("", "", listOf("é", "a", "Z"), emptyList(), emptyList(), emptyList(), emptyList())
        assertTrue(v.canonicalJson().contains("\"widgets\":[\"Z\",\"a\",\"é\"]"))
        assertFalse(v.canonicalJson().contains(" "))
    }

    private companion object {
        /** Native parity step 3's layout wrappers (A3.1), sorted. */
        val A3_1 = setOf(
            "Align", "AspectRatio", "Baseline", "ConstrainedBox", "FittedBox", "Flexible",
            "FractionallySizedBox", "IntrinsicHeight", "IntrinsicWidth", "LimitedBox", "Offstage",
            "SafeArea", "Wrap",
        )

        /** Native parity step 4's effect and touch wrappers (A4.1-A4.5), sorted. */
        val A4 = setOf(
            "AbsorbPointer", "BackdropFilter", "BlurView", "ClipOval", "ClipRect", "ColorFiltered",
            "DecoratedBox", "IgnorePointer", "InteractiveViewer", "Opacity", "RotatedBox",
        )

        /** Native parity step 5's scroll widgets (A5.1-A5.5, A5.7), sorted. */
        val A5 = setOf("GridView", "ListView", "PageView", "PullToRefresh", "Scrollbar")

        /** Native parity step 13: CustomScrollView and the four slivers. */
        val SLIVERS = setOf("CustomScrollView", "SliverAppBar", "SliverGrid", "SliverList", "SliverToBoxAdapter")
    }
}
