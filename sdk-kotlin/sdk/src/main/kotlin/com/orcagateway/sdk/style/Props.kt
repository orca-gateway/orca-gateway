package com.orcagateway.sdk.style

import android.graphics.Typeface
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.ui.Alignment
import androidx.compose.ui.BiasAbsoluteAlignment
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue

/**
 * Prop parsers shared by the widget builders, ported from the Swift SDK's
 * `Style/Props.swift` (itself from the Flutter SDK's
 * `builders/builder_helpers.dart`). Unknown or malformed values fall back to
 * the Flutter default instead of failing.
 */
internal object Props {
    /**
     * The largest length a prop may ask for, in dp. Compose cannot represent
     * a constraint much past this on a dense screen, and a fixed size this
     * large is a server bug, so it is capped rather than thrown on.
     */
    const val MAX_LENGTH: Float = 10_000f

    /**
     * `#RRGGBB` (opaque) or `#RRGGBBAA` (alpha last, CSS order); anything
     * else is null (Dart `parseColor`). Only hex digits are read: no sign,
     * no spaces.
     */
    fun color(value: JsonValue?): Color? {
        val text = value?.stringValue ?: return null
        if (!text.startsWith("#")) return null
        val hex = text.substring(1)
        if (hex.length != 6 && hex.length != 8) return null
        if (!hex.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }) return null
        val raw = hex.toLong(16)
        val rgba = if (hex.length == 6) (raw shl 8) or 0xFF else raw
        return Color(
            red = ((rgba shr 24) and 0xFF).toInt(),
            green = ((rgba shr 16) and 0xFF).toInt(),
            blue = ((rgba shr 8) and 0xFF).toInt(),
            alpha = (rgba and 0xFF).toInt(),
        )
    }

    /** A colour the SDK itself names (`#RRGGBB`); a typo is a bug, so it throws. */
    fun hex(text: String): Color = requireNotNull(color(JsonValue.String(text))) { "Not a colour: $text" }

    fun number(value: JsonValue?): Double? = value?.doubleValue

    /**
     * A length in dp for a size, a gap or a padding side: negative values
     * are 0 (Compose refuses them; Flutter asserts) and huge ones are capped
     * at [MAX_LENGTH].
     */
    fun length(value: JsonValue?): Dp? = number(value)?.let { lengthOf(it) }

    fun lengthOf(number: Double): Dp = number.coerceIn(0.0, MAX_LENGTH.toDouble()).toFloat().dp

    fun bool(value: JsonValue?): Boolean? = value?.boolValue

    fun string(value: JsonValue?): String? = value?.stringValue

    /** Dart `resolveStringValue`: null is "", numbers and bools are printed the Dart way. */
    fun text(value: JsonValue?): String {
        if (value == null || value.isNull) return ""
        return DartFormat.string(value)
    }

    /**
     * `{top, right, bottom, left}`, missing sides 0; anything else null. The
     * engine always sends all four (engine/src/components/edge-insets.ts).
     */
    fun insets(value: JsonValue?): Insets? {
        val o = value?.objectValue ?: return null
        fun side(key: String): Double = o[key]?.doubleValue ?: 0.0
        return Insets(top = side("top"), left = side("left"), bottom = side("bottom"), right = side("right"))
    }

    /** `w100`...`w900`, `normal` (w400), `bold` (w700); null inherits. */
    fun fontWeight(value: JsonValue?): FontWeight? = when (value?.stringValue) {
        "w100" -> FontWeight.W100
        "w200" -> FontWeight.W200
        "w300" -> FontWeight.W300
        "w400", "normal" -> FontWeight.W400
        "w500" -> FontWeight.W500
        "w600" -> FontWeight.W600
        "w700", "bold" -> FontWeight.W700
        "w800" -> FontWeight.W800
        "w900" -> FontWeight.W900
        else -> null
    }

    /** Flutter `MainAxisAlignment`; anything unknown is `start`. */
    enum class MainAxis(val wire: String) {
        Start("start"),
        End("end"),
        Center("center"),
        SpaceBetween("spaceBetween"),
        SpaceAround("spaceAround"),
        SpaceEvenly("spaceEvenly"),
    }

    fun mainAxis(value: JsonValue?): MainAxis =
        MainAxis.entries.firstOrNull { it.wire == value?.stringValue } ?: MainAxis.Start

    /** Flutter `CrossAxisAlignment`; anything unknown is `center`. */
    enum class CrossAxis(val wire: String) {
        Start("start"),
        End("end"),
        Center("center"),
        Stretch("stretch"),
        Baseline("baseline"),
    }

    fun crossAxis(value: JsonValue?): CrossAxis =
        CrossAxis.entries.firstOrNull { it.wire == value?.stringValue } ?: CrossAxis.Center

    /** `min` or `max` (the default). */
    fun fillsMainAxis(value: JsonValue?): Boolean = value?.stringValue != "min"

    /**
     * Flutter `TextAlign`: the six names, null otherwise. Compose has all
     * six, so `justify`, `start` and `end` stay what they are (SwiftUI folds
     * them into leading and trailing).
     */
    fun textAlign(value: JsonValue?): TextAlign? = when (value?.stringValue) {
        "left" -> TextAlign.Left
        "right" -> TextAlign.Right
        "center" -> TextAlign.Center
        "justify" -> TextAlign.Justify
        "start" -> TextAlign.Start
        "end" -> TextAlign.End
        else -> null
    }

    /**
     * Flutter `TextOverflow`: `ellipsis` and `visible` as named; `clip`,
     * `fade` (Compose cannot fade) and anything else clip, the Flutter
     * default.
     */
    fun overflow(value: JsonValue?): TextOverflow = when (value?.stringValue) {
        "ellipsis" -> TextOverflow.Ellipsis
        "visible" -> TextOverflow.Visible
        else -> TextOverflow.Clip
    }

    /**
     * Flutter `parseAlignment`: the nine `Alignment` names, anything else
     * `center`. Flutter's `Alignment` is absolute (it is not
     * `AlignmentDirectional`), so `topLeft` stays top left under a
     * right-to-left layout (SwiftUI's port maps it to topLeading). For a
     * Container's or Stack's child and an Image in its box.
     */
    fun alignment(value: JsonValue?): Alignment {
        val bias = alignmentBias(value)
        return BiasAbsoluteAlignment(bias.x, bias.y)
    }

    /**
     * The same names as a point of the unit square, (0, 0) top left and
     * (1, 1) bottom right (Swift's `unitPoint`): where a gradient starts and
     * ends, as Flutter's `Alignment.withinRect` places it.
     */
    fun unitPoint(value: JsonValue?): Offset {
        val bias = alignmentBias(value)
        return Offset((bias.x + 1) / 2, (bias.y + 1) / 2)
    }

    /** Flutter's `Alignment(x, y)` for a name, -1 to 1 on each axis; center when unknown. */
    private fun alignmentBias(value: JsonValue?): Offset =
        value?.stringValue?.let(ALIGNMENTS::get) ?: Offset.Zero

    private val ALIGNMENTS: Map<String, Offset> = mapOf(
        "topLeft" to Offset(-1f, -1f),
        "topCenter" to Offset(0f, -1f),
        "topRight" to Offset(1f, -1f),
        "centerLeft" to Offset(-1f, 0f),
        "center" to Offset(0f, 0f),
        "centerRight" to Offset(1f, 0f),
        "bottomLeft" to Offset(-1f, 1f),
        "bottomCenter" to Offset(0f, 1f),
        "bottomRight" to Offset(1f, 1f),
    )

    /**
     * Flutter `_parseBorderRadius`: a number rounds every corner, an object
     * `{topLeft, topRight, bottomLeft, bottomRight}` rounds each (missing
     * ones 0); anything else is null. For a decoration and a ClipRRect.
     */
    fun radii(value: JsonValue?): CornerRadii? {
        value?.doubleValue?.let { return CornerRadii.all(it) }
        val o = value?.objectValue ?: return null
        fun corner(key: String): Double = o[key]?.doubleValue ?: 0.0
        return CornerRadii(
            topLeft = corner("topLeft"),
            topRight = corner("topRight"),
            bottomLeft = corner("bottomLeft"),
            bottomRight = corner("bottomRight"),
        )
    }

    /**
     * Flutter `parseClip`: `hardEdge`, `antiAlias` and
     * `antiAliasWithSaveLayer` clip; `none` (the default), no value and
     * anything else do not. Compose clips anti-aliased in all three cases.
     */
    fun clips(value: JsonValue?): Boolean = when (value?.stringValue) {
        "hardEdge", "antiAlias", "antiAliasWithSaveLayer" -> true
        else -> false
    }
}

/**
 * Flutter `EdgeInsets`, in logical pixels as sent. Flutter's left and right
 * are absolute sides, so they stay left and right under a right-to-left
 * layout (SwiftUI's port maps them to leading and trailing).
 */
internal data class Insets(val top: Double, val left: Double, val bottom: Double, val right: Double) {
    /** As Compose padding; a negative side is 0, as Compose refuses one. */
    fun paddingValues(): PaddingValues = PaddingValues.Absolute(
        left = Props.lengthOf(left),
        top = Props.lengthOf(top),
        right = Props.lengthOf(right),
        bottom = Props.lengthOf(bottom),
    )

    companion object {
        val Zero: Insets = Insets(0.0, 0.0, 0.0, 0.0)
    }
}

/**
 * Flutter `BorderRadius`, in logical pixels as sent. The corners are
 * absolute, as Flutter's `BorderRadius` is (not `BorderRadiusDirectional`):
 * `topLeft` stays top left under a right-to-left layout. Drawn as a
 * [CornersShape], which caps radii that do not fit and makes a negative one 0.
 */
internal data class CornerRadii(
    val topLeft: Double = 0.0,
    val topRight: Double = 0.0,
    val bottomLeft: Double = 0.0,
    val bottomRight: Double = 0.0,
) {
    companion object {
        val Zero: CornerRadii = CornerRadii()

        fun all(radius: Double): CornerRadii = CornerRadii(radius, radius, radius, radius)
    }
}

/**
 * Flutter `TextStyleData` as a Compose [TextStyle]. Values left out inherit
 * from the surrounding style (the page's body style, an app bar's title
 * style, a button's label style), as Flutter's `DefaultTextStyle` does.
 *
 * `decorationColor` is read but cannot be drawn: Compose text decorations
 * always take the text colour.
 */
internal class TextStyleProps(value: JsonValue?) {
    val size: Double?
    val weight: FontWeight?
    val family: String?
    val italic: Boolean
    val color: Color?
    val background: Color?
    val letterSpacing: Double?
    val underline: Boolean
    val strikethrough: Boolean
    val decorationColor: Color?

    init {
        val s = value?.objectValue.orEmpty()
        // A negative size inherits rather than reach Compose's paint.
        size = Props.number(s["fontSize"])?.takeIf { it >= 0 }
        weight = Props.fontWeight(s["fontWeight"])
        family = s["fontFamily"]?.stringValue
        italic = s["fontStyle"]?.stringValue == "italic"
        color = Props.color(s["color"])
        background = Props.color(s["backgroundColor"])
        letterSpacing = Props.number(s["letterSpacing"])
        underline = s["decoration"]?.stringValue == "underline"
        strikethrough = s["decoration"]?.stringValue == "lineThrough"
        decorationColor = Props.color(s["decorationColor"])
    }

    val decoration: TextDecoration?
        get() = when {
            underline -> TextDecoration.Underline
            strikethrough -> TextDecoration.LineThrough
            else -> null
        }

    /** The style to merge over the inherited one. */
    fun textStyle(): TextStyle = TextStyle(
        color = color ?: Color.Unspecified,
        fontSize = size?.sp ?: TextUnit.Unspecified,
        fontWeight = weight,
        fontStyle = if (italic) FontStyle.Italic else null,
        fontFamily = family?.let(::fontFamily),
        letterSpacing = letterSpacing?.sp ?: TextUnit.Unspecified,
        background = background ?: Color.Unspecified,
        textDecoration = decoration,
    )

    private companion object {
        /**
         * A family by name: the generic Flutter names map to Compose's, any
         * other name is looked up among the system fonts (Swift:
         * `Font.custom`), which falls back to the default face when missing.
         */
        fun fontFamily(name: String): FontFamily = when (name) {
            "serif" -> FontFamily.Serif
            "sans-serif" -> FontFamily.SansSerif
            "monospace" -> FontFamily.Monospace
            "cursive" -> FontFamily.Cursive
            else -> FontFamily(Typeface.create(name, Typeface.NORMAL))
        }
    }
}
