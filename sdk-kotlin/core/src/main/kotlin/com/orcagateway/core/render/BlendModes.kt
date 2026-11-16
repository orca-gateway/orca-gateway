package com.orcagateway.core.render

/**
 * The blend modes a ColorFiltered can use, Flutter's `BlendMode` as the
 * Flutter builder's `_parseBlendMode` reads them (layout_builders.dart
 * :758-783): 21 names, each the entry of the same name. How each mode
 * combines a colour (source) with a pixel (destination) is Flutter's
 * (dart:ui `BlendMode`); the UI layer draws it. Named `OrcaBlendMode`, not
 * `BlendMode`, so it never clashes with Compose's.
 */
public enum class OrcaBlendMode(public val wire: String) {
    SrcOver("srcOver"),
    SrcIn("srcIn"),
    SrcATop("srcATop"),
    DstOver("dstOver"),
    DstIn("dstIn"),
    DstATop("dstATop"),
    Multiply("multiply"),
    Screen("screen"),
    Overlay("overlay"),
    Darken("darken"),
    Lighten("lighten"),
    ColorDodge("colorDodge"),
    ColorBurn("colorBurn"),
    HardLight("hardLight"),
    SoftLight("softLight"),
    Difference("difference"),
    Exclusion("exclusion"),
    Hue("hue"),
    Saturation("saturation"),
    Color("color"),
    Luminosity("luminosity"),
    ;

    public companion object {
        /** The mode named [value] exactly as Flutter spells it; srcATop when it is missing, unknown or in another case. */
        public fun of(value: String?): OrcaBlendMode = entries.firstOrNull { it.wire == value } ?: SrcATop
    }
}
