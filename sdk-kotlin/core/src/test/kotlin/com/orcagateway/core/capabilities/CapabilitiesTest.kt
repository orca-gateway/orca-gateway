package com.orcagateway.core.capabilities

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
        assertEquals(92, widgets.size)
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
        assertEquals(92, android.size)
    }

    @Test
    fun actionKindsMatchTheImplementedList() {
        val listed = strings(json("sdk-kotlin/capabilities.json").jsonObject["actionKinds"])
        assertEquals(listed, GeneratedCapabilities.actionKinds.toSet())
        assertEquals(15, listed.size)
        // Swift's twin: the iOS SDK advertises the same 15 kinds.
        assertEquals(strings(json("sdk-swift/capabilities.json").jsonObject["actionKinds"]), listed)
    }

    @Test
    fun valueKindsTransformsAndOpsComeFromTheEngine() {
        assertEquals(9, GeneratedCapabilities.valueKinds.size)
        assertEquals(31, GeneratedCapabilities.transformKinds.size)
        assertEquals(13, GeneratedCapabilities.boolExprOps.size)
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
}
