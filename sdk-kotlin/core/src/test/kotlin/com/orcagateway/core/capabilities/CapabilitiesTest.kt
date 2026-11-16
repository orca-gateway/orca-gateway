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
     */
    @Test
    fun c1_kotlinAdvertisesTheSame49WidgetsAsSwift() {
        val kotlin = json("sdk-kotlin/capabilities.json").jsonObject["widgets"]!!.jsonArray.map { it.jsonPrimitive.content }
        val swift = strings(json("sdk-swift/capabilities.json").jsonObject["widgets"])
        assertEquals(49, kotlin.size)
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
        assertEquals(kotlin, GeneratedCapabilities.widgets)
        assertEquals(GeneratedCapabilities.capsHash, CapabilityVector.current.hash)
    }

    /**
     * A3.1: Compose draws the 13 layout wrappers, so the generated vector
     * advertises them (49 in all, with S12's 5 animated ones) and the core registry lets them through
     * instead of degrading them; WidgetBuildersTest pins standard() to the
     * same set.
     */
    @Test
    fun a3_1_theThirteenLayoutWrappersAreAdvertisedAndLetThrough() {
        val advertised = GeneratedCapabilities.widgets.toSet()
        assertEquals(emptySet(), A3_1 - advertised, "not advertised")
        assertEquals(49, GeneratedCapabilities.widgets.size)
        assertEquals(emptySet(), A3_1 - WidgetRegistry.shared.types, "degraded by the core registry")
    }

    @Test
    fun actionKindsMatchTheImplementedList() {
        val listed = strings(json("sdk-kotlin/capabilities.json").jsonObject["actionKinds"])
        assertEquals(listed, GeneratedCapabilities.actionKinds.toSet())
        assertTrue(Action.kinds.toSet().containsAll(listed), "not wire kinds: ${listed - Action.kinds.toSet()}")
        // S12 added animateForward and animateReverse: 20 to 22.
        assertEquals(22, listed.size)
        assertTrue(listed.containsAll(setOf("animateForward", "animateReverse")))
        assertTrue(listed.containsAll(setOf("switchTab", "openDrawer")))
        // Step 2 added the fire-mode wrappers and the debugLog effect.
        assertTrue(listed.containsAll(setOf("once", "always", "debugLog")), "missing: ${setOf("once", "always", "debugLog") - listed}")
        // Swift's twin: the iOS SDK advertises the same 22 kinds.
        assertEquals(strings(json("sdk-swift/capabilities.json").jsonObject["actionKinds"]), listed)
        // The executor runs exactly what is advertised, plus the server-only
        // replaceComponent (not in action.ts, so never advertised).
        assertEquals(listed + "replaceComponent", ActionExecutor.kinds)
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
    }
}
