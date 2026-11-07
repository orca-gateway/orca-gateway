package com.orcagateway.sdk

import androidx.compose.runtime.RememberObserver
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.orcagateway.core.client.ActionClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.render.PageRenderer
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.OrcaUrlPolicy
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
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
 * Snackbars and toasts are drawn by the page itself ([toast]). Navigation
 * and system effects go to [effectHandler] (the host's router sets it), and
 * a server action's structural changes edit the node tree here.
 *
 * Actions run on the main dispatcher in a scope the model owns; [close]
 * cancels whatever is still running. Use the model from the main thread.
 */
public class OrcaPageModel(
    page: PageResponse,
    public val store: ElmStore = ElmStore(),
    registry: WidgetRegistry = WidgetRegistry.shared,
    client: ActionClient? = null,
) : AutoCloseable {
    public val renderer: PageRenderer = PageRenderer(page, registry)
    public val executor: ActionExecutor = ActionExecutor(store, client)

    /** The snackbar or toast showing now (Compose state). */
    public var toast: OrcaToast? by mutableStateOf(null)

    /**
     * Bumped after every change to the node tree (a server action adding,
     * updating, replacing or deleting components). Compose state.
     */
    public var structureRevision: Int by mutableIntStateOf(0)
        private set

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
        executor.onEffect = { effect -> onEffect?.invoke(effect) }
        executor.perform = { effect -> perform(effect) }
        executor.onMutation = { mutation -> apply(mutation) }
    }

    public val page: PageResponse get() = renderer.page

    public fun resolve(id: String): ResolvedNode? = renderer.resolve(id, store.state)

    public fun watches(of: String): List<String> = renderer.node(of)?.watches ?: emptyList()

    /**
     * Run the node's action for a trigger (`onTap`, `onLongPress`, ...), the
     * Flutter `fireAction`: nothing happens (null) when the node has none.
     * The run is asynchronous (a server action waits on the network); the
     * returned job finishes when the action does, which tests join.
     */
    public fun fire(trigger: String, on: ResolvedNode, eventData: Map<String, JsonValue>? = null): Job? {
        val action = on.actions[trigger] ?: return null
        return scope.launch { run(action, eventData) }
    }

    /** Run one action to the end; a failure goes to [onError], never up. */
    public suspend fun run(action: Action, eventData: Map<String, JsonValue>? = null) {
        try {
            executor.execute(action, eventData)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            // DevTools reporting arrives with the adapters slice (S8).
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
            else -> effectHandler?.invoke(effect)
        }
    }

    internal fun apply(mutation: ComponentMutation) {
        renderer.apply(mutation)
        structureRevision += 1
        for (listener in structureListeners.toList()) listener()
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

    /** A watched key changed: redraw. */
    private fun watchedChanged() {
        revision += 1
        // DevTools reporting arrives with the adapters slice (S8).
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
