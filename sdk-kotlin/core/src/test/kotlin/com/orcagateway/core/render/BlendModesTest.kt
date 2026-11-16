package com.orcagateway.core.render

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * A4.3, the core half of ColorFiltered: the Flutter builder's
 * `_parseBlendMode` (layout_builders.dart:758-783) maps 21 names to a
 * `BlendMode`; anything else, missing, unknown or in the wrong case, is
 * srcATop. The same cases as Swift's BlendModesTests.
 */
class BlendModesTest {
    private val flutterNames = listOf(
        "srcOver", "srcIn", "srcATop", "dstOver", "dstIn", "dstATop", "multiply", "screen", "overlay", "darken",
        "lighten", "colorDodge", "colorBurn", "hardLight", "softLight", "difference", "exclusion", "hue",
        "saturation", "color", "luminosity",
    )

    /** A4.3 (kt core): each of the 21 names is its own mode, and there are no others. */
    @Test
    fun a4_3_kt_eachOfThe21FlutterNamesIsItsOwnMode() {
        for (name in flutterNames) assertEquals(name, OrcaBlendMode.of(name).wire, name)
        assertEquals(flutterNames.toSet(), OrcaBlendMode.entries.map { it.wire }.toSet())
        assertEquals(21, OrcaBlendMode.entries.size)
    }

    /** A4.3 (kt core): a missing blend mode is srcATop. */
    @Test
    fun a4_3_kt_aMissingBlendModeIsSrcATop() {
        assertEquals(OrcaBlendMode.SrcATop, OrcaBlendMode.of(null))
    }

    /** A4.3 (kt core): a name Flutter does not map is srcATop, Flutter's other BlendMode values included. */
    @Test
    fun a4_3_kt_anUnknownBlendModeIsSrcATop() {
        for (name in listOf("", "normal", "plus", "modulate", "xor", "clear", "src", "dst", "srcOut", "sourceAtop", "blur")) {
            assertEquals(OrcaBlendMode.SrcATop, OrcaBlendMode.of(name), name)
        }
    }

    /** A4.3 (kt core): the names are matched as they are: the wrong case is srcATop. */
    @Test
    fun a4_3_kt_aBlendModeInTheWrongCaseIsSrcATop() {
        for (name in listOf("Multiply", "MULTIPLY", "srcin", "SrcIn", "dstatop", "ColorDodge", "src_over", " multiply")) {
            assertEquals(OrcaBlendMode.SrcATop, OrcaBlendMode.of(name), name)
        }
    }
}
