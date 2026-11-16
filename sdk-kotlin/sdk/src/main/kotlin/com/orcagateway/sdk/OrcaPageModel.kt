package com.orcagateway.sdk

import android.util.Log
import androidx.compose.runtime.RememberObserver
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import com.orcagateway.core.animation.AnimationRegistry
import com.orcagateway.core.client.ActionClient
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.render.PageRenderer
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.resolver.ValueResolver
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.core.state.ActionSource
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.OrcaUrlPolicy
import com.orcagateway.core.state.SavedState
import com.orcagateway.core.subpage.SubPage
import com.orcagateway.core.subpage.SubPageHost
import com.orcagateway.core.subpage.SubPageMounts
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/**
 * A snackbar or toast to show. [OrcaPageView] draws a snackbar in the page's
 * Material 3 `SnackbarHost` and a toast as an Android `Toast`. Two toasts
 * are never equal, even with the same text (identity, as Swift's UUID).
 */
public class OrcaToast(
    public val message: String,
    /** How long it stays on screen, in milliseconds. */
    public val durationMillis: Long,
    public val style: Style,
) {
    public enum class Style { Snackbar, Toast }

    override fun toString(): String = "OrcaToast($style, \"$message\", ${durationMillis}ms)"
}

/**
 * One rendered page: its nodes, its store, and the executor that runs its
 * actions. Views resolve nodes through it and fire triggers into it.
 *
 * Snackbars and toasts are drawn by the page itself ([toast]), and
 * `animateForward` / `animateReverse` run on its own animation controllers.
 * Navigation and system effects go to [effectHandler] (the host's router
 * sets it), and a server action's structural changes edit the node tree here.
 *
 * Actions run on the main dispatcher in a scope the model owns; [close]
 * cancels whatever is still running. Use the model from the main thread.
 *
 * With a [savedState] (a router's, see [OrcaPageLoader]) the page's saved
 * entry is laid over its declared initials right after the seed, as
 * Flutter's `StateManager.initPage` does, and the page's `persistState` and
 * `clearState` save to and clear it ([ActionExecutor.savedState]). The
 * first read of an entry reads its file, on the calling thread. A sub-page's
 * state lives in this page's store and has no entry of its own.
 */
public class OrcaPageModel(
    page: PageResponse,
    public val store: ElmStore = ElmStore(),
    registry: WidgetRegistry = WidgetRegistry.shared,
    client: ActionClient? = null,
    savedState: SavedState? = null,
) : AutoCloseable {
    /** The page's node tree. A refetch ([replacePage]) takes the new page's nodes into it. */
    public val renderer: PageRenderer = PageRenderer(page, registry)
    public val executor: ActionExecutor = ActionExecutor(store, client)

    /** The snackbar or toast showing now (Compose state). */
    public var toast: OrcaToast? by mutableStateOf(null)

    /**
     * Bumped after every change to the node tree (a server action adding,
     * updating, replacing or deleting components, a refetch). Compose state.
     */
    public var structureRevision: Int by mutableIntStateOf(0)
        private set

    /**
     * The page's animation controllers by `animationId` (Flutter's
     * AnimationRegistry, one per page): each AnimatedBuilder with an id
     * registers here while it is on screen, and the `animateForward` and
     * `animateReverse` effects drive them. Every time passed to it is a frame
     * time in milliseconds ([withAnimationFrame]). Internal, as that clock
     * is: a host drives an animation with the two effects.
     */
    internal val animations: AnimationRegistry = AnimationRegistry()

    /**
     * The time of the last frame an animated widget of this page took, in
     * milliseconds: the "now" a targeted tween is resolved at.
     */
    internal var animationFrameMs: Double = 0.0
        private set

    /** Bumped by every animate effect that waits for a frame: wakes the builders at rest. */
    private val animationRequests = MutableStateFlow(0)

    /** The animate effects performed since the last frame: (forward, id), in order. */
    private val pendingAnimations = ArrayList<Pair<Boolean, String>>()

    /** Every effect as data, before it is performed (DevTools, logging). */
    public var onEffect: ((ActionEffect) -> Unit)? = null

    /** Performs what the page does not: navigation, URL, clipboard, share. */
    public var effectHandler: ((ActionEffect) -> Unit)? = null

    /**
     * An action that threw and had no lifecycle `onError` to catch it. Dart
     * leaves such a future unhandled; Kotlin reports it here and moves on.
     */
    public var onError: ((Throwable) -> Unit)? = null

    /** The Compose builders this page draws with (see [WidgetBuilders]). */
    internal var builders: WidgetBuilders = WidgetBuilders.shared

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val structureListeners = ArrayList<() -> Unit>()

    init {
        store.pageId = page.pageId
        store.seed(page.state)
        // The saved keys replace the declared initials, or are added (contract S5).
        savedState?.restorePage(store, page.pageId)
        executor.savedState = savedState
        executor.onEffect = { effect -> onEffect?.invoke(effect) }
        executor.perform = { effect -> perform(effect) }
        executor.onMutation = { mutation -> apply(mutation) }
        executor.subPagePrefixes = { subPages.prefixes }
        executor.onUpdateSubPage = { id, pageId, params, mode -> updateSubPage(id, pageId, params, mode) }
        // DevTools' affectedWidgets: the renderer's current nodes, in the page's order.
        executor.pageNodes = { renderer.nodes.values }
    }

    public val page: PageResponse get() = renderer.page

    public fun resolve(id: String): ResolvedNode? = renderer.resolve(id, store.state)

    /** Resolve under an AnimatedBuilder: `tween` props take [animationProgress]. */
    public fun resolve(id: String, animationProgress: Double?): ResolvedNode? {
        val resolved = renderer.resolve(id, store.state, animationProgress = animationProgress) ?: return null
        val source = renderer.node(id)?.props ?: return resolved
        if (source.values.none(::namesAnimation)) return resolved
        // A tween naming an `animationId` reads that controller's curved
        // progress, 0 for an id no builder has (Dart `value_resolver.dart`).
        val resolver = ValueResolver(
            state = store.state.merged,
            animationProgress = animationProgress,
            animationProgressFor = { animations.progress(it, animationFrameMs) },
        )
        return resolved.copy(props = source.mapValues { resolver.resolveDeep(it.value) })
    }

    /** Whether a prop holds, at any depth, a `tween` or `tweenSequence` naming an `animationId`. */
    private fun namesAnimation(value: JsonValue): Boolean = when (value) {
        is JsonValue.Object -> {
            val type = value.members["type"]?.stringValue
            ((type == "tween" || type == "tweenSequence") && value.members["animationId"]?.stringValue != null) ||
                value.members.values.any(::namesAnimation)
        }
        is JsonValue.Array -> value.items.any(::namesAnimation)
        else -> false
    }

    /**
     * Waits for the next frame and runs [block] in it with its time in
     * milliseconds: the clock of every animated widget of the page (call it
     * from a composition's coroutine, which has the frame clock). State
     * [block] writes is drawn in that same frame. The animate effects
     * performed since the last frame start at this time, before [block].
     */
    internal suspend fun <R> withAnimationFrame(block: (Double) -> R): R = withFrameNanos { nanos ->
        val now = nanos / NANOS_PER_MILLI
        animationFrameMs = now
        val pending = pendingAnimations.toList()
        pendingAnimations.clear()
        for ((forward, id) in pending) {
            if (forward) animations.forward(id, now) else animations.reverse(id, now)
        }
        block(now)
    }

    /** Whether an animate effect still waits for a frame to start at. */
    internal val hasPendingAnimation: Boolean get() = pendingAnimations.isNotEmpty()

    /**
     * Suspends until an animate effect is performed after [seen] (a value of
     * [animationRequestCount] read earlier), so a builder at rest takes no frames.
     */
    internal suspend fun awaitAnimationRequest(seen: Int) {
        animationRequests.first { it != seen }
    }

    internal val animationRequestCount: Int get() = animationRequests.value

    /**
     * `animateForward` / `animateReverse`: nothing for a missing id or one no
     * builder has registered. The run starts at the next frame's time: the
     * builder that owns the controller is woken and takes that frame.
     */
    private fun animate(forward: Boolean, id: String?) {
        if (id == null || animations.controller(id) == null) return
        pendingAnimations.add(forward to id)
        animationRequests.value += 1
    }

    public fun watches(of: String): List<String> = renderer.node(of)?.watches ?: emptyList()

    /**
     * Run the node's action for a trigger (`onTap`, `onLongPress`, ...), the
     * Flutter `fireAction`: nothing happens (null) when the node has none.
     * The run is asynchronous (a server action waits on the network); the
     * returned job finishes when the action does, which tests join. Its
     * source is the node and the trigger, so a `once` in it runs one time
     * per widget and trigger.
     */
    public fun fire(trigger: String, on: ResolvedNode, eventData: Map<String, JsonValue>? = null): Job? {
        val action = on.actions[trigger] ?: return null
        // A node drawn from a snapshot ([OrcaNodeSnapshot.frozen]) runs nothing.
        if (action === INERT_ACTION) return null
        return scope.launch { run(action, eventData, ActionSource(on.id, trigger)) }
    }

    /**
     * Run one action to the end; a failure goes to DevTools as an `error`
     * event and to [onError], never up. A cancelled run is not a failure.
     * [source] is the widget and trigger that fired it, for `once`.
     */
    public suspend fun run(action: Action, eventData: Map<String, JsonValue>? = null, source: ActionSource? = null) {
        try {
            executor.execute(action, eventData, source)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            OrcaDebug.report { DevToolsEvent.error(message = "$e", context = "action ${action.kind} on ${page.pageId}") }
            onError?.invoke(e)
        }
    }

    /** Cancel every action still running. The model draws on, but runs nothing more. */
    override fun close() {
        scope.cancel()
    }

    /**
     * Runs once, the first time the page is on screen (the loader's
     * DevTools `timing` event, which needs the first frame).
     */
    internal var onFirstAppear: (() -> Unit)? = null

    internal fun appeared() {
        val first = onFirstAppear
        onFirstAppear = null
        first?.invoke()
    }

    /** The `id::trigger` of each onInit and onVisible that ran (see [firstMount]). */
    private val mounted = HashSet<String>()

    /**
     * True the first time node [id]'s mount [trigger] (onInit, onVisible)
     * asks, false ever after: the guard of widgets/Lifecycle.kt. It lives on
     * the model, not in the composition, because a page under a pushed one
     * leaves the composition (NavHost) and coming back is no new mount, while
     * a reload or a restored process builds a new model, whose state the
     * trigger must set again.
     */
    internal fun firstMount(id: String, trigger: String): Boolean = mounted.add("$id::$trigger")

    /**
     * A link the page itself draws, such as a FallbackPrompt's call to action
     * (Flutter: `OrcaUrlPolicy.isAllowed`, then `launchUrl`). A URL the policy
     * refuses does nothing. Under a router it goes out as an `openUrl`
     * effect, like the action; a page shown on its own opens it with
     * [fallback] (Compose's `UriHandler`).
     */
    internal fun openLink(raw: String, fallback: (String) -> Unit) {
        val url = OrcaUrlPolicy.standard.url(raw)?.toString() ?: return
        val handler = effectHandler
        if (handler != null) {
            handler(ActionEffect("openUrl", mapOf("url" to JsonValue.String(url))))
        } else {
            fallback(url)
        }
    }

    internal fun perform(effect: ActionEffect) {
        when (effect.type) {
            "showSnackbar", "showToast" -> toast = OrcaToast(
                message = effect.payload["message"]?.stringValue ?: "",
                durationMillis = effect.payload["duration"]?.intValue ?: DEFAULT_DURATION_MILLIS,
                style = if (effect.type == "showSnackbar") OrcaToast.Style.Snackbar else OrcaToast.Style.Toast,
            )
            "animateForward", "animateReverse" ->
                animate(forward = effect.type == "animateForward", id = effect.payload["animationId"]?.stringValue)
            "debugLog" -> {
                log(effect)
                effectHandler?.invoke(effect)
            }
            else -> effectHandler?.invoke(effect)
        }
    }

    /**
     * Prints a debugLog effect to logcat, as Flutter's `developer.log`: under
     * its tag, at its level (debug, info, warn, error; anything else debug),
     * the message then the data as JSON.
     */
    private fun log(effect: ActionEffect) {
        val tag = effect.payload["tag"]?.stringValue ?: "orca"
        val line = listOfNotNull(
            effect.payload["message"]?.stringValue,
            effect.payload["data"]?.toJsonElement()?.toString(),
        ).joinToString(" ")
        when (effect.payload["level"]?.stringValue) {
            "info" -> Log.i(tag, line)
            "warn" -> Log.w(tag, line)
            "error" -> Log.e(tag, line)
            else -> Log.d(tag, line)
        }
    }

    internal fun apply(mutation: ComponentMutation) {
        renderer.apply(mutation)
        // S8: a SubPage node the mutation took out takes its mounted pages with it.
        subPages.sweep()
        structureChanged()
    }

    /**
     * Show [page] in place of the current one, in this model (Flutter's
     * refetch in OrcaPage, sdk/lib/src/widgets/orca_page.dart onRefetchPage,
     * and ComponentStore.init): page state starts again from its initials,
     * the saved entry laid over them as at set-up (`initPage`), and
     * app state is kept, only unset app keys taking its initials (`initPage`).
     * The pages mounted in SubPages stay, their nodes and their state keys;
     * every other node is the new page's, and a SubPage whose node did not
     * come back is unmounted. The executor, its `once` keys and the onInit
     * guard stay, so nodes keeping their id do not fire onInit again.
     */
    internal fun replacePage(page: PageResponse) {
        val prefixes = subPages.prefixes
        val mounted = { key: String -> prefixes.any(key::startsWith) }
        val carried = store.state.page.filterKeys(mounted)
        store.pageId = page.pageId
        store.seed(page.state)
        executor.savedState?.restorePage(store, page.pageId)
        if (carried.isNotEmpty()) store.dispatch(carried)
        renderer.replace(page, keep = mounted)
        subPages.sweep()
        structureChanged()
    }

    /** The node tree changed: forget the SubPages that left, then draw every node again. */
    private fun structureChanged() {
        val left = subPageSlots.values.filter { !isMounted(it) }
        for (slot in left) {
            slot.job?.cancel()
            subPageSlots.remove(slot.mounts.subPageKey)
        }
        structureRevision += 1
        for (listener in structureListeners.toList()) listener()
    }

    // MARK: Sub-pages

    /**
     * The sub-pages mounted in this page (contract S3, `schema/fixtures/subpage/README.md`): their nodes are
     * in [renderer] and their state in [store], under a prefix per mounted page.
     */
    internal val subPages: SubPageHost = SubPageHost(renderer, store)

    /** What the SubPage widgets of this page hold besides their mounted pages, by node id. */
    private val subPageSlots = HashMap<String, SubPageSlot>()

    /** The page route, when the client has one: sub-pages are fetched through it. */
    private val pageClient: OrcaClient? = client as? OrcaClient

    private fun isMounted(slot: SubPageSlot): Boolean = subPages.mounts(slot.mounts.subPageKey) === slot.mounts

    /**
     * The slot of the SubPage node [id], registered the first time it is drawn. It lives as long as the node
     * is in the page, not as long as the widget is composed: a page under a pushed one leaves the composition
     * and keeps its sub-pages.
     */
    internal fun subPage(id: String): SubPageSlot {
        subPageSlots[id]?.takeIf(::isMounted)?.let { return it }
        return SubPageSlot(subPages.register(id)).also { subPageSlots[id] = it }
    }

    /**
     * The SubPage widget's own fetch (S4), a replace: nothing when [location] (`SubPage.request`) is the one
     * it last asked for. What is mounted stays while it runs; a failure is drawn by the widget
     * ([SubPageSlot.error]). An answer is dropped when a newer fetch started, an `updateSubPage` overtook it or
     * the SubPage left the page; the fetch it overtakes is cancelled.
     */
    internal fun loadSubPage(slot: SubPageSlot, location: String) {
        if (slot.location == location) return
        slot.location = location
        slot.job?.cancel()
        val load = ++slot.load
        slot.job = scope.launch {
            try {
                val page = fetchSubPage(location)
                if (slot.load == load) mount(slot, "replace", page)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (slot.load == load && isMounted(slot)) slot.error = e.message ?: "$e"
            }
        }
    }

    /**
     * `updateSubPage` (S7). An id no SubPage of the page has: nothing. The old content stays while the fetch
     * runs; a failed fetch leaves it and is thrown to the action chain. `join` mounts the page after the
     * others, anything else replaces them.
     */
    private suspend fun updateSubPage(id: String, pageId: String, params: Map<String, JsonValue>?, mode: String) {
        val slot = subPageSlots[id]?.takeIf(::isMounted) ?: return
        val page = fetchSubPage(SubPage.request(pageId, params).location)
        // The update wins over a fetch of the widget's own that is still out.
        slot.load += 1
        slot.job?.cancel()
        mount(slot, mode, page)
    }

    /** S4: the normal page route, with the app state posted as on any page fetch. */
    private suspend fun fetchSubPage(location: String): PageResponse {
        val client = pageClient ?: throw IllegalStateException("SubPage needs an OrcaClient to fetch its page")
        return client.fetchPage(location, store.state.app)
    }

    /** Mounts a fetched page, unless the SubPage left the page meanwhile, and draws the tree again. */
    private fun mount(slot: SubPageSlot, mode: String, page: PageResponse) {
        if (!isMounted(slot)) return
        if (mode != "join" || slot.mounts.pages.isEmpty()) slot.generation += 1
        subPages.mount(slot.mounts.subPageKey, mode, page)
        slot.error = null
        structureChanged()
    }

    /**
     * Calls [listener] after every change to the node tree, until the
     * returned handle is closed. The tree is already new when it runs.
     */
    internal fun onStructureChange(listener: () -> Unit): AutoCloseable {
        structureListeners.add(listener)
        return AutoCloseable { structureListeners.remove(listener) }
    }

    internal companion object {
        /** Dart's snackbar default, also used when an effect carries none. */
        const val DEFAULT_DURATION_MILLIS: Long = 4000

        const val NANOS_PER_MILLI: Double = 1_000_000.0

        /**
         * What every trigger of a snapshot node holds instead of its action:
         * the node still looks like one with the trigger set, and [fire]
         * (which knows this instance) runs nothing for it.
         */
        val INERT_ACTION: Action = Action.Unknown(JsonValue.Null)
    }
}

/**
 * What one SubPage node holds while it is in its page: its mounted pages ([mounts], the core's) and the state
 * of its own fetch. Main thread only.
 */
internal class SubPageSlot(val mounts: SubPageMounts) {
    /** The location the widget last asked for; null before its first fetch. */
    var location: String? = null

    /** Counts the fetches for this SubPage; an answer that is no longer the latest is dropped. */
    var load: Int = 0

    /** The widget's own fetch, while it runs. */
    var job: Job? = null

    /**
     * Counts the mounts that are not a join. It is part of the key of each drawn page, so a page that replaces
     * another is composed anew: nothing the old page's composables remembered carries over.
     */
    var generation: Int = 0

    /** Why the widget's own fetch failed, drawn in the place of the pages; cleared by the next mount (Compose state). */
    var error: String? by mutableStateOf(null)
}

/**
 * The resolved nodes last drawn below one point of a page, by id: what an
 * AnimatedSwitcher keeps of its child so it can still draw it, fading out,
 * once a server action has removed it from the page.
 *
 * [NodeView] hands every node it resolves to the nearest one
 * (`LocalOrcaNodeRecorder`), which costs a map entry holding a reference to
 * the node already resolved for drawing; each also tells its [parent], so
 * an outer switcher's snapshot includes what an inner one draws. [frozen]
 * is the copy to draw from (`LocalOrcaFrozenNodes`); [keep] drops what a
 * change to the page took out of the subtree. Main thread only.
 */
internal class OrcaNodeSnapshot {
    /** The recorder around the widget that owns this one, if any. */
    var parent: OrcaNodeSnapshot? = null

    private val nodes = HashMap<String, ResolvedNode>()

    fun record(node: ResolvedNode) {
        nodes[node.id] = node
        parent?.record(node)
    }

    /**
     * Forgets every node that is not in the subtree under [root] as last
     * drawn (all of them for null): a node a server action deleted or
     * replaced inside it is not held on. Call it once the subtree has been
     * drawn from the changed page; the parent prunes itself.
     */
    fun keep(root: String?) {
        val held = if (root == null) emptySet() else reachable(root)
        nodes.keys.retainAll(held)
    }

    /**
     * The subtree under [root] as last drawn: the nodes reachable from it
     * through children and slots, each with its triggers made inert
     * ([OrcaPageModel.INERT_ACTION]). Empty when [root] was never drawn.
     */
    fun frozen(root: String): Map<String, ResolvedNode> = reachable(root).associateWithTo(LinkedHashMap()) { id ->
        val node = nodes.getValue(id)
        if (node.actions.isEmpty()) node else node.copy(actions = node.actions.mapValues { OrcaPageModel.INERT_ACTION })
    }

    /** The recorded ids reachable from [root] through children and slots, [root] first. */
    private fun reachable(root: String): Set<String> {
        val out = LinkedHashSet<String>()
        val pending = ArrayDeque(listOf(root))
        while (pending.isNotEmpty()) {
            val id = pending.removeFirst()
            val node = nodes[id] ?: continue
            if (!out.add(id)) continue
            pending.addAll(node.childIds)
            pending.addAll(node.slots.values)
        }
        return out
    }
}

/**
 * Redraws one node when a key it watches changes, the Flutter
 * `WatchBuilder`: other nodes of the page are left alone. A change to the
 * node tree redraws every node, and picks up watches an update changed.
 *
 * It subscribes when created (as Swift's `StateObject` does) and is
 * remembered by [NodeView], so Compose closes it when the node leaves the
 * screen, or when the composition that created it is abandoned.
 */
internal class NodeObserver(private val model: OrcaPageModel, private val id: String) : RememberObserver, AutoCloseable {
    /** Bumped on every redraw this node needs (Compose state). */
    var revision: Int by mutableIntStateOf(0)
        private set

    private var watches: List<String> = emptyList()
    private var subscription: ElmStore.Subscription? = null
    private var structure: AutoCloseable? = null

    init {
        subscribe()
        // `apply` edits the tree before it calls the listeners, so the tree
        // is already new when this runs.
        structure = model.onStructureChange { structureChanged() }
    }

    private fun subscribe() {
        val next = model.watches(id)
        if (next == watches && subscription != null) return
        subscription?.cancel()
        watches = next
        subscription = if (next.isEmpty()) null else model.store.subscribe(next) { watchedChanged() }
    }

    /**
     * A watched key changed: redraw. DevTools hears of it from the core,
     * whose `PageRenderer.resolve` reports the traced `widget_rebuild` when
     * the redraw resolves the node.
     */
    private fun watchedChanged() {
        revision += 1
    }

    private fun structureChanged() {
        subscribe()
        revision += 1
    }

    override fun close() {
        subscription?.cancel()
        subscription = null
        structure?.close()
        structure = null
    }

    override fun onRemembered() {}

    override fun onForgotten(): Unit = close()

    override fun onAbandoned(): Unit = close()
}
