package com.orcagateway.core.render

import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue

/** A piece of a RichText: [text] in [style], a wire TextStyleData object (null when nothing above it set one). */
public data class TextRun(public val text: String, public val style: JsonValue?)

/**
 * What a Text under a DefaultTextStyle draws with: [style] (wire
 * TextStyleData, null when neither sets one), [textAlign] and [overflow] as
 * their wire names, [maxLines] null for no limit.
 */
public data class TextLayer(
    public val style: JsonValue?,
    public val textAlign: String,
    public val maxLines: Long?,
    public val overflow: String,
)

/**
 * How wire text styles layer, Flutter's rules over the TextStyleData JSON
 * so the UI layers parse one merged style: a span over its parent in a
 * RichText, a Text's own style over a DefaultTextStyle's. The same cases
 * as Swift's TextStyles.
 */
public object TextStyles {
    private const val FONT_STYLE = "fontStyle"

    /**
     * [child] laid over [parent]: Flutter `TextStyle.merge` (painting/
     * text_style.dart:1078-1122) of two `parseTextStyle` results
     * (builder_helpers.dart:96-121). A child that is not an object
     * (`parseTextStyle` gives null) is the parent; else the child's fields
     * that are present and not null replace the parent's, and the result
     * always says fontStyle, "italic" when the child does, else "normal"
     * (:103-105), so a styled child is upright under an italic parent.
     * decoration "none" is a set value (:141) and stays, clearing a line.
     */
    public fun merge(parent: JsonValue?, child: JsonValue?): JsonValue? {
        val own = child?.objectValue ?: return parent
        val merged = parent?.objectValue.orEmpty().toMutableMap()
        own.forEach { (key, value) -> if (!value.isNull) merged[key] = value }
        merged[FONT_STYLE] = JsonValue.String(if (own[FONT_STYLE]?.stringValue == "italic") "italic" else "normal")
        return JsonValue.Object(merged)
    }

    /**
     * A RichText's `text` span tree as runs, depth first: Flutter
     * `_buildTextSpan` (primitive_builders.dart:339-348) drawn by the
     * engine, which starts each span from its parent's style
     * (lib/ui/text/paragraph_builder.cc:396), the root from [base]. A span's
     * `text` is `resolveStringValue` (:340, builder_helpers.dart:436-447):
     * absent or null an empty run, else its Dart string; a child that is
     * not an object is a run of `'$c'` (:344) in its parent's style. A root
     * that is not an object is one empty run in [base]: Flutter's
     * `const TextSpan()` (:332), an empty line in the base style.
     */
    public fun spans(root: JsonValue?, base: JsonValue?): List<TextRun> {
        val runs = mutableListOf<TextRun>()
        addSpan(root as? JsonValue.Object ?: JsonValue.Object(emptyMap()), base, runs)
        return runs
    }

    private fun addSpan(span: JsonValue, parent: JsonValue?, runs: MutableList<TextRun>) {
        val style = merge(parent, span["style"])
        val text = span["text"]
        runs += TextRun(if (text.isNull) "" else DartFormat.string(text), style)
        span["children"].arrayValue.orEmpty().forEach { child ->
            if (child is JsonValue.Object) addSpan(child, style, runs) else runs += TextRun(DartFormat.string(child), style)
        }
    }

    /**
     * A Text with props [own] under a DefaultTextStyle with props [dts]
     * (layout_builders.dart:588-601): Flutter `Text.build` (widgets/
     * text.dart:722-797). The style is the DTS style merged with the
     * Text's (:724-727); textAlign the Text's, else the DTS's, else "start"
     * (:789); maxLines the Text's, else the DTS's (:796); overflow the
     * Text's, else the merged style's (the Text style's, then the DTS
     * style's), else the DTS's, else "clip", the builder's default (:794,
     * layout_builders.dart:598). SelectableText takes the same style,
     * textAlign and maxLines (material selectable_text.dart:753-785).
     */
    public fun layer(dts: Map<String, JsonValue>, own: Map<String, JsonValue>): TextLayer {
        val style = merge(dts["style"], own["style"])
        return TextLayer(
            style = style,
            textAlign = own["textAlign"]?.stringValue ?: dts["textAlign"]?.stringValue ?: "start",
            maxLines = own["maxLines"]?.intValue ?: dts["maxLines"]?.intValue,
            overflow = own["overflow"]?.stringValue ?: style?.get("overflow")?.stringValue
                ?: dts["overflow"]?.stringValue ?: "clip",
        )
    }
}
