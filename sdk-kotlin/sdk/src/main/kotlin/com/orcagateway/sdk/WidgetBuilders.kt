package com.orcagateway.sdk

import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.widgets.AlignWidget
import com.orcagateway.sdk.widgets.AnimatedAlignWidget
import com.orcagateway.sdk.widgets.AnimatedBuilderWidget
import com.orcagateway.sdk.widgets.AnimatedContainerWidget
import com.orcagateway.sdk.widgets.AnimatedOpacityWidget
import com.orcagateway.sdk.widgets.AnimatedSwitcherWidget
import com.orcagateway.sdk.widgets.AppBarWidget
import com.orcagateway.sdk.widgets.AspectRatioWidget
import com.orcagateway.sdk.widgets.BaselineWidget
import com.orcagateway.sdk.widgets.BottomNavItemWidget
import com.orcagateway.sdk.widgets.BottomNavigationBarWidget
import com.orcagateway.sdk.widgets.ButtonWidget
import com.orcagateway.sdk.widgets.CardWidget
import com.orcagateway.sdk.widgets.CenterWidget
import com.orcagateway.sdk.widgets.ClipRRectWidget
import com.orcagateway.sdk.widgets.ConstrainedBoxWidget
import com.orcagateway.sdk.widgets.ContainerWidget
import com.orcagateway.sdk.widgets.DividerWidget
import com.orcagateway.sdk.widgets.DrawerWidget
import com.orcagateway.sdk.widgets.ExpandedWidget
import com.orcagateway.sdk.widgets.FallbackPromptWidget
import com.orcagateway.sdk.widgets.FittedBoxWidget
import com.orcagateway.sdk.widgets.FlexWidget
import com.orcagateway.sdk.widgets.FlexibleWidget
import com.orcagateway.sdk.widgets.FractionallySizedBoxWidget
import com.orcagateway.sdk.widgets.GestureDetectorWidget
import com.orcagateway.sdk.widgets.HeroWidget
import com.orcagateway.sdk.widgets.IconWidget
import com.orcagateway.sdk.widgets.ImageWidget
import com.orcagateway.sdk.widgets.IntrinsicHeightWidget
import com.orcagateway.sdk.widgets.IntrinsicWidthWidget
import com.orcagateway.sdk.widgets.LimitedBoxWidget
import com.orcagateway.sdk.widgets.OffstageWidget
import com.orcagateway.sdk.widgets.PaddingWidget
import com.orcagateway.sdk.widgets.PositionedWidget
import com.orcagateway.sdk.widgets.ReorderableListWidget
import com.orcagateway.sdk.widgets.SafeAreaWidget
import com.orcagateway.sdk.widgets.ScaffoldWidget
import com.orcagateway.sdk.widgets.ScrollWidget
import com.orcagateway.sdk.widgets.SizedBoxWidget
import com.orcagateway.sdk.widgets.SpacerWidget
import com.orcagateway.sdk.widgets.StackWidget
import com.orcagateway.sdk.widgets.TextFieldWidget
import com.orcagateway.sdk.widgets.TextWidget
import com.orcagateway.sdk.widgets.TransformWidget
import com.orcagateway.sdk.widgets.VideoWidget
import com.orcagateway.sdk.widgets.WrapWidget
import java.util.concurrent.ConcurrentHashMap

/**
 * Draws one resolved node. [modifier] comes from the parent (a stretched
 * Flex child, a slot) and goes on the builder's outermost layout; a builder
 * emits one layout node, or none. Dart `ComponentBuilder`
 * (sdk/lib/src/rendering/component_registry.dart): children are drawn with
 * [NodeView], triggers fired with [OrcaPageModel.fire].
 */
public typealias WidgetBuilder = @Composable (node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) -> Unit

/**
 * The Compose side of the registry: wire type to builder (Swift's
 * `WidgetView` switch, Flutter's `ComponentRegistry`). The core
 * `WidgetRegistry` has already turned a type it does not know into a
 * FallbackPrompt; a type that still has no builder here (one the core was
 * told about, such as a plugin's, or the core's `_Empty`) draws nothing,
 * takes no space and is logged once per type. Nothing here throws.
 *
 * Open: [register] adds or replaces a builder, which is how plugins and
 * hosts add their widgets, on an instance of their own from [standard].
 * Thread-safe.
 */
public class WidgetBuilders private constructor(initial: Map<String, WidgetBuilder>) {
    private val builders = ConcurrentHashMap(initial)
    private val missing: MutableSet<String> = ConcurrentHashMap.newKeySet()

    /** The builder for a wire [type], or null when none is registered. */
    public operator fun get(type: String): WidgetBuilder? = builders[type]

    /** Draw nodes of a wire [type] with [builder], replacing any builder it had. */
    public fun register(type: String, builder: WidgetBuilder) {
        builders[type] = builder
    }

    /** The wire types with a builder, a snapshot. */
    public val types: Set<String> get() = builders.keys.toSet()

    /** Log a type with no builder, once per type; true the first time. */
    internal fun reportMissing(type: String): Boolean {
        val first = missing.add(type)
        if (first) Log.w(LOG_TAG, "No Compose builder for widget type \"$type\"; it draws nothing.")
        return first
    }

    /** Types reported by [reportMissing] so far. */
    internal val reportedMissing: Set<String> get() = missing.toSet()

    public companion object {
        internal const val LOG_TAG: String = "OrcaGateway"

        /** The builders every page draws with unless told otherwise. */
        internal val shared: WidgetBuilders = standard()

        /**
         * A fresh registry with the 50 widgets of sdk-kotlin/capabilities.json:
         * the 15 core ones (S7) and the rest of the iOS set (S9: Expanded,
         * Spacer, TextField, GestureDetector, Container, ClipRRect, Stack,
         * Positioned, Image, Icon), then AnimatedBuilder, Transform and Video,
         * S10's BottomNavigationBar, BottomNavItem and Drawer, S12's
         * AnimatedContainer, AnimatedOpacity, AnimatedAlign, AnimatedSwitcher
         * and Hero, the 13 layout wrappers of native parity step 3
         * (A3.1), and S13's ReorderableListView. Keep the two lists in
         * step: the caps vector advertises what this draws
         * (WidgetBuildersTest checks it).
         */
        public fun standard(): WidgetBuilders = WidgetBuilders(emptyMap()).apply {
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
            register("Expanded") { node, model, modifier -> ExpandedWidget(node, model, modifier) }
            register("Spacer") { node, model, modifier -> SpacerWidget(node, model, modifier) }
            register("TextField") { node, model, modifier -> TextFieldWidget(node, model, modifier) }
            register("GestureDetector") { node, model, modifier -> GestureDetectorWidget(node, model, modifier) }
            register("Container") { node, model, modifier -> ContainerWidget(node, model, modifier) }
            register("ClipRRect") { node, model, modifier -> ClipRRectWidget(node, model, modifier) }
            register("Stack") { node, model, modifier -> StackWidget(node, model, modifier) }
            register("Positioned") { node, model, modifier -> PositionedWidget(node, model, modifier) }
            register("Image") { node, model, modifier -> ImageWidget(node, model, modifier) }
            register("Icon") { node, model, modifier -> IconWidget(node, model, modifier) }
            register("AnimatedBuilder") { node, model, modifier -> AnimatedBuilderWidget(node, model, modifier) }
            register("Transform") { node, model, modifier -> TransformWidget(node, model, modifier) }
            register("Video") { node, _, modifier -> VideoWidget(node, modifier) }
            register("BottomNavigationBar") { node, model, modifier -> BottomNavigationBarWidget(node, model, modifier) }
            register("BottomNavItem") { node, _, modifier -> BottomNavItemWidget(node, modifier) }
            register("Drawer") { node, model, modifier -> DrawerWidget(node, model, modifier) }
            register("AnimatedContainer") { node, model, modifier -> AnimatedContainerWidget(node, model, modifier) }
            register("AnimatedOpacity") { node, model, modifier -> AnimatedOpacityWidget(node, model, modifier) }
            register("AnimatedAlign") { node, model, modifier -> AnimatedAlignWidget(node, model, modifier) }
            register("AnimatedSwitcher") { node, model, modifier -> AnimatedSwitcherWidget(node, model, modifier) }
            register("Hero") { node, model, modifier -> HeroWidget(node, model, modifier) }
            register("ReorderableListView") { node, model, modifier -> ReorderableListWidget(node, model, modifier) }
            register("Align") { node, model, modifier -> AlignWidget(node, model, modifier) }
            register("AspectRatio") { node, model, modifier -> AspectRatioWidget(node, model, modifier) }
            register("Baseline") { node, model, modifier -> BaselineWidget(node, model, modifier) }
            register("ConstrainedBox") { node, model, modifier -> ConstrainedBoxWidget(node, model, modifier) }
            register("FittedBox") { node, model, modifier -> FittedBoxWidget(node, model, modifier) }
            register("Flexible") { node, model, modifier -> FlexibleWidget(node, model, modifier) }
            register("FractionallySizedBox") { node, model, modifier ->
                FractionallySizedBoxWidget(node, model, modifier)
            }
            register("IntrinsicHeight") { node, model, modifier -> IntrinsicHeightWidget(node, model, modifier) }
            register("IntrinsicWidth") { node, model, modifier -> IntrinsicWidthWidget(node, model, modifier) }
            register("LimitedBox") { node, model, modifier -> LimitedBoxWidget(node, model, modifier) }
            register("Offstage") { node, model, modifier -> OffstageWidget(node, model, modifier) }
            register("SafeArea") { node, model, modifier -> SafeAreaWidget(node, model, modifier) }
            register("Wrap") { node, model, modifier -> WrapWidget(node, model, modifier) }
        }
    }
}
