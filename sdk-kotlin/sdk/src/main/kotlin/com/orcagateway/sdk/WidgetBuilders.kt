package com.orcagateway.sdk

import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.widgets.AppBarWidget
import com.orcagateway.sdk.widgets.ButtonWidget
import com.orcagateway.sdk.widgets.CardWidget
import com.orcagateway.sdk.widgets.CenterWidget
import com.orcagateway.sdk.widgets.DividerWidget
import com.orcagateway.sdk.widgets.FallbackPromptWidget
import com.orcagateway.sdk.widgets.FlexWidget
import com.orcagateway.sdk.widgets.PaddingWidget
import com.orcagateway.sdk.widgets.ScaffoldWidget
import com.orcagateway.sdk.widgets.ScrollWidget
import com.orcagateway.sdk.widgets.SizedBoxWidget
import com.orcagateway.sdk.widgets.TextWidget
import java.util.concurrent.ConcurrentHashMap

/**
 * Draws one resolved node. [modifier] comes from the parent (a stretched
 * Flex child, a slot) and goes on the builder's outermost layout; a builder
 * emits one layout node, or none.
 */
internal typealias WidgetBuilder = @Composable (node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) -> Unit

/**
 * The Compose side of the registry: wire type to builder (Swift's
 * `WidgetView` switch, Flutter's `ComponentRegistry`). The core
 * `WidgetRegistry` has already turned a type it does not know into a
 * FallbackPrompt; a type that still has no builder here (one the core was
 * told about, such as a plugin's, or the core's `_Empty`) draws nothing,
 * takes no space and is logged once per type. Nothing here throws.
 *
 * Open: [register] adds or replaces a builder, which is how plugins will
 * add their widgets. Thread-safe.
 */
internal class WidgetBuilders private constructor(initial: Map<String, WidgetBuilder>) {
    private val builders = ConcurrentHashMap(initial)
    private val missing: MutableSet<String> = ConcurrentHashMap.newKeySet()

    operator fun get(type: String): WidgetBuilder? = builders[type]

    fun register(type: String, builder: WidgetBuilder) {
        builders[type] = builder
    }

    val types: Set<String> get() = builders.keys.toSet()

    /** Log a type with no builder, once per type; true the first time. */
    fun reportMissing(type: String): Boolean {
        val first = missing.add(type)
        if (first) Log.w(LOG_TAG, "No Compose builder for widget type \"$type\"; it draws nothing.")
        return first
    }

    /** Types reported by [reportMissing] so far. */
    val reportedMissing: Set<String> get() = missing.toSet()

    companion object {
        const val LOG_TAG: String = "OrcaGateway"

        /** The builders every page draws with unless told otherwise. */
        val shared: WidgetBuilders = standard()

        /**
         * A fresh registry with the 15 widgets of sdk-kotlin/capabilities.json.
         * Keep the two lists in step: the caps vector advertises what this draws.
         */
        fun standard(): WidgetBuilders = WidgetBuilders(emptyMap()).apply {
            register("Scaffold") { node, model, modifier -> ScaffoldWidget(node, model, modifier) }
            register("AppBar") { node, model, modifier -> AppBarWidget(node, model, modifier) }
            register("Column") { node, model, modifier -> FlexWidget(node, model, modifier, vertical = true) }
            register("Row") { node, model, modifier -> FlexWidget(node, model, modifier, vertical = false) }
            register("Center") { node, model, modifier -> CenterWidget(node, model, modifier) }
            register("Padding") { node, model, modifier -> PaddingWidget(node, model, modifier) }
            register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier) }
            register("SingleChildScrollView") { node, model, modifier -> ScrollWidget(node, model, modifier) }
            register("Card") { node, model, modifier -> CardWidget(node, model, modifier) }
            register("Text") { node, _, modifier -> TextWidget(node, modifier) }
            register("Divider") { node, _, modifier -> DividerWidget(node, modifier) }
            register("ElevatedButton") { node, model, modifier -> ButtonWidget(node, model, modifier) }
            register("OutlinedButton") { node, model, modifier -> ButtonWidget(node, model, modifier) }
            register("TextButton") { node, model, modifier -> ButtonWidget(node, model, modifier) }
            register("FallbackPrompt") { node, model, modifier -> FallbackPromptWidget(node, model, modifier) }
        }
    }
}
