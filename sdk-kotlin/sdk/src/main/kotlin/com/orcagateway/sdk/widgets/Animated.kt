package com.orcagateway.sdk.widgets

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.RememberObserver
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.semantics.SemanticsPropertyKey
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.IntSize
import com.orcagateway.core.animation.AnimationDuration
import com.orcagateway.core.animation.AnimationMix
import com.orcagateway.core.animation.ImplicitAnimation
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.LocalOrcaFrozenNodes
import com.orcagateway.sdk.LocalOrcaNodeRecorder
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaNodeSnapshot
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilder
import com.orcagateway.sdk.style.Props
import kotlin.math.roundToInt

// Flutter's implicitly animated widgets (layout_builders.dart
// `_buildAnimatedContainer` ... `_buildHero`). Each of the first three is its
// plain twin drawn with props that move: the core's ImplicitAnimation mixes
// the old resolved props and the new ones at the page's frame time, and the
// mix goes to the same drawing code a Container, an opacity or an Align uses.

/**
 * [node] with the props to draw now: its own when nothing moves, the core's
 * mix of the old and the new ones while a run is live.
 *
 * The first composition shows [target] as it is. When [target] changes the
 * widget keeps what is on screen until the next frame, where the run begins
 * (`duration` ms, 300; `curve` by name, easeInOut when missing or unknown)
 * from the value on screen, also in the middle of a run; it takes frames
 * only until the run ends. Reduced motion ([orcaReduceMotion]) or a
 * duration of 0: [target] at once, no frame taken.
 *
 * [target] is [node]'s props with Flutter's defaults filled in, so a prop
 * the page leaves out animates from the default as it does in Flutter.
 */
@Composable
private fun sampled(
    node: ResolvedNode,
    model: OrcaPageModel,
    target: Map<String, JsonValue> = node.props,
): ResolvedNode {
    val animation = remember(node.id) {
        ImplicitAnimation(mix = AnimationMix::props).also { it.retarget(target, 0.0) }
    }
    animation.durationMs = AnimationDuration.milliseconds(node["duration"])
    animation.curve = node["curve"]?.stringValue
    animation.reduceMotion = orcaReduceMotion()
    val jumps = animation.reduceMotion || animation.durationMs <= 0

    var onScreen by remember(animation) { mutableStateOf(target) }
    LaunchedEffect(model, animation, target, jumps) {
        if (jumps) {
            animation.retarget(target, model.animationFrameMs)
            onScreen = target
            return@LaunchedEffect
        }
        if (animation.target == target) return@LaunchedEffect
        model.withAnimationFrame { now ->
            animation.retarget(target, now)
            onScreen = animation.value(now) ?: target
        }
        while (animation.isRunning(model.animationFrameMs)) {
            model.withAnimationFrame { now -> onScreen = animation.value(now) ?: target }
        }
    }
    return node.copy(props = if (jumps) target else onScreen)
}

/** [node]'s props with [prop] set to [default] when the page leaves it out. */
private fun ResolvedNode.propsWith(prop: String, default: JsonValue): Map<String, JsonValue> =
    if (this[prop] == null) props + (prop to default) else props

/**
 * Flutter `AnimatedContainer`: a Container whose `width`, `height`, `color`,
 * `padding`, `margin`, `decoration` and `alignment` move to their new value
 * over `duration` through `curve` ([sampled]). Everything else, and how the
 * props are drawn (`color` only without a `decoration`, the sizing with and
 * without a child or an alignment), is [ContainerWidget]'s, which [draw]
 * calls with the sampled props.
 */
@Composable
internal fun AnimatedContainerWidget(
    node: ResolvedNode,
    model: OrcaPageModel,
    modifier: Modifier,
    draw: WidgetBuilder = { sampled, m, mod -> ContainerWidget(sampled, m, mod) },
) {
    draw(sampled(node, model), model, modifier)
}

/**
 * Flutter `AnimatedOpacity`: `opacity` (1 when missing) moves to its new
 * value over `duration` through `curve`; [draw] is [OpacityWidget] with the
 * sampled props.
 */
@Composable
internal fun AnimatedOpacityWidget(
    node: ResolvedNode,
    model: OrcaPageModel,
    modifier: Modifier,
    draw: WidgetBuilder = { sampled, m, mod -> OpacityWidget(sampled, m, mod) },
) {
    draw(sampled(node, model, node.propsWith("opacity", JsonValue.Double(1.0))), model, modifier)
}

/**
 * Flutter `Opacity`: the child drawn with `opacity` (0 to 1; an elastic
 * curve's overshoot is cut off), laid out as if it were not there. With no
 * child it is an empty box of the size its parent forces.
 */
@Composable
internal fun OpacityWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val opacity = (Props.number(node["opacity"]) ?: 1.0).coerceIn(0.0, 1.0).toFloat()
    Box(modifier.alpha(opacity), propagateMinConstraints = true) {
        ChildView(node, model)
    }
}

/**
 * Flutter `AnimatedAlign`: `alignment` (center when missing), `widthFactor`
 * and `heightFactor` move to their new value over `duration` through
 * `curve`; [draw] is [AlignWidget] with the sampled props. Between two
 * names the alignment is an `{x, y}` point, which [Props.alignment] reads.
 */
@Composable
internal fun AnimatedAlignWidget(
    node: ResolvedNode,
    model: OrcaPageModel,
    modifier: Modifier,
    draw: WidgetBuilder = { sampled, m, mod -> AlignWidget(sampled, m, mod) },
) {
    draw(sampled(node, model, node.propsWith("alignment", JsonValue.String("center"))), model, modifier)
}

/**
 * Flutter `Align` (`RenderPositionedBox`, as [CenterWidget] for the
 * centre): the child loose at `alignment`. On an axis with a factor
 * (`widthFactor`, `heightFactor`) or no limit it is the child's size times
 * the factor (1 when absent); on the others as big as it may be.
 */
@Composable
internal fun AlignWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val alignment = Props.alignment(node["alignment"])
    val widthFactor = Props.number(node["widthFactor"])
    val heightFactor = Props.number(node["heightFactor"])
    Layout(content = { ChildView(node, model) }, modifier = modifier) { measurables, constraints ->
        val child = measurables.firstOrNull()?.measure(constraints.copy(minWidth = 0, minHeight = 0))
        val width = alignedSide(child?.width ?: 0, widthFactor, constraints.hasBoundedWidth, constraints.maxWidth)
            .coerceIn(constraints.minWidth, constraints.maxWidth)
        val height = alignedSide(child?.height ?: 0, heightFactor, constraints.hasBoundedHeight, constraints.maxHeight)
            .coerceIn(constraints.minHeight, constraints.maxHeight)
        layout(width, height) {
            child?.place(alignment.align(IntSize(child.width, child.height), IntSize(width, height), layoutDirection))
        }
    }
}

/** Flutter's shrink-wrapped side (the child's times the factor) with a factor or no limit, else the limit. */
private fun alignedSide(child: Int, factor: Double?, bounded: Boolean, max: Int): Int =
    if (factor != null || !bounded) (child * (factor ?: 1.0)).coerceAtLeast(0.0).roundToInt() else max

/**
 * Which children an AnimatedSwitcher shows and how opaque each is: the
 * [current] one, and while a fade is live the [outgoing] one under it. No
 * timer inside: [frame] takes the page's frame time. [progress] is Compose
 * state, so a composable that reads an alpha is redrawn as the fade moves.
 */
internal class SwitcherFade {
    /** The child shown; null before the first [show] and for a switcher with no child. */
    var current: String? = null
        private set

    /** The child fading out; null when no fade is live. */
    var outgoing: String? = null
        private set

    /** Where the [current] child's nodes are recorded as they are drawn: the next [outgoingNodes]. */
    var recorder: OrcaNodeSnapshot = OrcaNodeSnapshot()
        private set

    /**
     * The [outgoing] child as it was last drawn, to draw it from while it
     * fades (the page may have dropped it); null when no fade is live.
     */
    var outgoingNodes: Map<String, ResolvedNode>? = null
        private set

    private var shown = false
    private var startMs: Double? = null
    private var durationMs = 0.0
    private var outgoingFrom = 1.0

    /** The live fade's linear time, 0 to 1; 1 at rest. */
    private var progress by mutableDoubleStateOf(1.0)

    val isFading: Boolean get() = progress < 1.0

    /** The [current] child's opacity: 0 to 1 over the fade, linear. */
    val incomingAlpha: Double get() = progress

    /**
     * The [outgoing] child's opacity: down from what it had when it was
     * replaced (1, or less when it was itself still fading in) at the same
     * linear rate, as Flutter reverses its controller.
     */
    val outgoingAlpha: Double get() = (outgoingFrom - progress).coerceAtLeast(0.0)

    /**
     * The switcher's child is now [id]. The first child, the same id again,
     * and any id when [jump] or [durationMs] is 0 or less: shown as it is.
     * Another id: a fade of [durationMs] that begins at the next [frame];
     * a child still fading out from an earlier change is dropped.
     */
    fun show(id: String?, durationMs: Double, jump: Boolean) {
        if (shown && id == current) return
        if (!shown || jump || durationMs <= 0) {
            shown = true
            current = id
            outgoing = null
            outgoingNodes = null
            recorder = OrcaNodeSnapshot()
            progress = 1.0
            return
        }
        outgoingFrom = incomingAlpha
        outgoing = current
        outgoingNodes = current?.let { recorder.frozen(it) }
        recorder = OrcaNodeSnapshot()
        current = id
        startMs = null
        this.durationMs = durationMs
        progress = 0.0
    }

    /** One frame at [now] ms: the first one of a fade is its start. */
    fun frame(now: Double) {
        if (!isFading) return
        val start = startMs ?: now.also { startMs = it }
        val next = ((now - start) / durationMs).coerceIn(0.0, 1.0)
        if (next >= 1.0) {
            outgoing = null
            outgoingNodes = null
        }
        progress = next
    }
}

/**
 * Flutter `AnimatedSwitcher`, with the child told apart by its node id
 * (D9; Flutter goes by widget class and key): when the first child's id
 * changes, the old child fades out and the new one in, both linear over
 * `duration` ms (300), stacked centred. The same id with new props is the
 * same child: no fade. Reduced motion ([orcaReduceMotion]): the swap is
 * immediate.
 *
 * The old child fades out from a snapshot, as a `replaceComponent` or a
 * delete has already taken it off the page: each time the current child is
 * drawn its resolved nodes are recorded ([SwitcherFade.recorder]), and when
 * the id changes the outgoing layer is drawn from that record
 * ([LocalOrcaFrozenNodes]) until the fade ends, when it is dropped. That
 * layer is inert: no pointer input, no action, no lifecycle trigger, no
 * animation controller, nothing read from the page. A switcher that is
 * itself inside such a layer swaps at once.
 */
@Composable
internal fun AnimatedSwitcherWidget(
    node: ResolvedNode,
    model: OrcaPageModel,
    modifier: Modifier,
    fade: SwitcherFade = remember(node.id) { SwitcherFade() },
) {
    val frozen = LocalOrcaFrozenNodes.current
    fade.show(
        node.childIds.firstOrNull(),
        AnimationDuration.milliseconds(node["duration"]),
        jump = orcaReduceMotion() || frozen != null,
    )
    fade.recorder.parent = LocalOrcaNodeRecorder.current
    val current = fade.current
    LaunchedEffect(model, fade, current) {
        while (fade.isFading) model.withAnimationFrame { now -> fade.frame(now) }
    }
    Box(modifier, contentAlignment = Alignment.Center) {
        val fading = fade.isFading
        // One call site keyed by id: a child keeps its composition as it turns from current to outgoing.
        for (id in listOfNotNull(fade.outgoing, current)) {
            key(id) {
                val leaving = id != current
                val alpha = if (leaving) fade.outgoingAlpha else fade.incomingAlpha
                val layer = if (fading) Modifier.alpha(alpha.toFloat()) else Modifier
                CompositionLocalProvider(
                    LocalOrcaFrozenNodes provides if (leaving) fade.outgoingNodes.orEmpty() else frozen,
                    LocalOrcaNodeRecorder provides if (leaving) null else fade.recorder,
                ) {
                    NodeView(id, model, if (leaving) layer.then(NoPointerInput) else layer)
                }
            }
        }
    }
}

/** Takes every pointer event before the content below it can: an outgoing child is not clickable. */
private val NoPointerInput: Modifier = Modifier.pointerInput(Unit) {
    awaitPointerEventScope {
        while (true) awaitPointerEvent(PointerEventPass.Initial).changes.forEach { it.consume() }
    }
}

/** The `tag` of the Hero a node is drawn in (semantics): how a test finds it. */
internal val OrcaHeroTag: SemanticsPropertyKey<String> = SemanticsPropertyKey("OrcaHeroTag")

/** The `tag` of a Hero that is a shared element of its stack (semantics): set only where the flight is wired. */
internal val OrcaSharedHero: SemanticsPropertyKey<String> = SemanticsPropertyKey("OrcaSharedHero")

/**
 * What a Hero needs to fly: the single-stack NavHost's [shared] scope and
 * the [visibility] scope of the destination (one page) it is drawn on. One
 * per page; [claim] keeps one shared element per tag on it.
 */
internal class OrcaHeroStage(val shared: SharedTransitionScope, val visibility: AnimatedVisibilityScope) {
    private val owners = HashMap<String, Any>()

    /** Whether [owner] is the Hero that flies for [tag] on this page: the first one to ask. */
    fun claim(tag: String, owner: Any): Boolean = owners.getOrPut(tag) { owner } === owner

    fun release(tag: String, owner: Any) {
        if (owners[tag] === owner) owners.remove(tag)
    }
}

/** The page's [OrcaHeroStage]; null, the default, where no Hero flies (the tab shell, a page drawn on its own). */
internal val LocalOrcaHeroStage = compositionLocalOf<OrcaHeroStage?> { null }

/** One Hero's claim on its tag, given back when the Hero leaves the composition. */
private class HeroClaim(private val stage: OrcaHeroStage, private val tag: String) : RememberObserver {
    val owns: Boolean = stage.claim(tag, this)

    override fun onRemembered() {}

    override fun onForgotten() = stage.release(tag, this)

    override fun onAbandoned() = stage.release(tag, this)
}

/**
 * Where a Hero's `tag` meets its child's modifier (D10). A non-empty tag
 * marks the child with [OrcaHeroTag], and on a page of the single-stack
 * NavHost ([LocalOrcaHeroStage]) makes it a shared element with the tag as
 * its key (`Modifier.sharedElement`, marked [OrcaSharedHero]): when two
 * pages of the stack hold the tag as one replaces the other, the child
 * flies from its place on the page that leaves to its place on the page
 * that comes, over both.
 *
 * Just the child, no shared element: an empty tag, no stage, reduced motion
 * ([orcaReduceMotion]), a layer drawn from a snapshot
 * ([LocalOrcaFrozenNodes]), and every Hero after the first with one tag on
 * a page (Compose expects one visible element per key in a scene).
 */
@Composable
internal fun Modifier.orcaHero(tag: String): Modifier {
    if (tag.isEmpty()) return this
    val stage = LocalOrcaHeroStage.current
    val flies = stage != null && !orcaReduceMotion() && LocalOrcaFrozenNodes.current == null &&
        remember(stage, tag) { HeroClaim(stage, tag) }.owns
    if (stage == null || !flies) return semantics { this[OrcaHeroTag] = tag }
    // The marks go inside the shared element: they are where it is drawn, also in flight.
    return with(stage.shared) {
        sharedElement(rememberSharedContentState(key = tag), animatedVisibilityScope = stage.visibility)
            .semantics {
                this[OrcaHeroTag] = tag
                this[OrcaSharedHero] = tag
            }
    }
}

/**
 * Flutter `Hero`: its child, drawn as if the Hero were not there; an empty
 * or missing `tag`, or no child, is Flutter's plain child or nothing. The
 * flight between two pages is [orcaHero]'s.
 */
@Composable
internal fun HeroWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    ChildView(node, model, modifier.orcaHero(node["tag"]?.stringValue.orEmpty()))
}
