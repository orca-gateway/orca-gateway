package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel

/*
 * Flutter's touch wrappers (layout_builders.dart). Both are proxy boxes:
 * the child laid out with the box's constraints, the box the child's size
 * (the smallest size without one), nothing drawn differently.
 */

/**
 * True under an ignoring [IgnorePointerWidget] or an absorbing
 * [AbsorbPointerWidget]: the subtree takes no touches and offers no click
 * actions to accessibility (Flutter's `isBlockingUserActions`). Read by
 * [GestureDetectorWidget], which then adds no pointer input, [ButtonWidget],
 * which draws its button without one, looking the same, the hit nodes of
 * DecoratedBox and BlurView, and [InteractiveViewerWidget], which then adds
 * no pointer input, so it neither pans nor zooms. Not read yet, so still
 * taking touches under an IgnorePointer and keeping their actions under
 * either wrapper: BasicTextField (Input.kt), the scroll views (Layout.kt
 * `ScrollWidget`), the clickable in Content.kt, Card's hit node, the AppBar
 * IconButtons and NavigationBarItem (Structure.kt).
 */
internal val LocalPointerBlocked = compositionLocalOf { false }

/**
 * Flutter `AbsorbPointer` (`_buildAbsorbPointer`, RenderAbsorbPointer):
 * `absorbing` (true by default) is hit over its whole box and its child is
 * not, so neither the child, whatever its builder, nor the siblings behind
 * get a touch there. As in Flutter, where a hit adds every ancestor of the
 * box hit, the boxes around it still get each touch, unconsumed: a
 * GestureDetector around it taps, a scroll view around it scrolls. Under
 * an ignoring IgnorePointer it is not hit either. Not absorbing, only the
 * child.
 */
@Composable
internal fun AbsorbPointerWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val absorbing = node["absorbing"]?.boolValue ?: true
    val blocked = LocalPointerBlocked.current
    Box(modifier, propagateMinConstraints = true) {
        CompositionLocalProvider(LocalPointerBlocked provides (blocked || absorbing)) {
            ChildView(node, model)
        }
        // Over the child: Compose stops at the topmost child hit.
        if (absorbing && !blocked) Box(Modifier.matchParentSize().pointerInput(Unit) {})
    }
}

/**
 * Flutter `IgnorePointer` (`_buildIgnorePointer`, RenderIgnorePointer):
 * `ignoring` (true by default) is never hit, nor is anything in it, so a
 * touch goes on to what is behind. Compose stops at the first sibling with
 * any pointer input in it, so the box adds none and the builders in it that
 * read [LocalPointerBlocked] add none either. Not ignoring, only the child.
 */
@Composable
internal fun IgnorePointerWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val ignoring = node["ignoring"]?.boolValue ?: true
    Box(modifier, propagateMinConstraints = true) {
        CompositionLocalProvider(LocalPointerBlocked provides (LocalPointerBlocked.current || ignoring)) {
            ChildView(node, model)
        }
    }
}
