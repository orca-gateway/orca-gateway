package com.orcagateway.sdk.widgets

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Modifier
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.TextStyles
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel

/**
 * The DefaultTextStyle above this point, as the props [TextStyles.layer]
 * lays a Text's own over: `style`, `textAlign`, `maxLines` as sent, and
 * `overflow` (clip when not sent). Null, the default: none, so a Text
 * draws on [androidx.compose.material3.LocalTextStyle] as it always has.
 * A local of its own, not LocalTextStyle: Compose's ProvideTextStyle
 * merges, Flutter's DefaultTextStyle replaces. A Material host sets it
 * back to null, as Flutter's Material resets it (material.dart:470-474):
 * the whole Scaffold (every slot, its drawers too), the whole AppBar
 * toolbar (leading, title, actions), Card, the three buttons (their inert
 * path too), the FloatingActionButton and InkWell's child. IconButton has
 * no Material and passes it through. SliverAppBar draws its own row and
 * does not reset it on Kotlin yet.
 */
internal val LocalOrcaDefaultTextStyle = compositionLocalOf<Map<String, JsonValue>?> { null }

/**
 * Flutter `DefaultTextStyle` as the builder makes it (layout_builders.dart:
 * 588-601): the replacing constructor (widgets/text.dart:63), not
 * `.merge`, so the Texts below draw its style on the engine's defaults
 * ([com.orcagateway.sdk.style.ENGINE_TEXT_STYLE]), never on the ambient
 * style, and a DefaultTextStyle inside it replaces it whole. It hands down
 * `style`, `textAlign`, `maxLines` and `overflow` (?? clip); a Text lays its
 * own fields over them ([TextStyles.layer]). RichText never reads it.
 * Layout is its child's.
 */
@Composable
internal fun DefaultTextStyleWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val layer = buildMap {
        for (key in listOf("style", "textAlign", "maxLines")) node[key]?.let { put(key, it) }
        put("overflow", node["overflow"] ?: JsonValue.String("clip"))
    }
    CompositionLocalProvider(LocalOrcaDefaultTextStyle provides layer) { ChildView(node, model, modifier) }
}
