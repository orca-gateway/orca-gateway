package com.orcagateway.core.state

import com.orcagateway.core.client.ActionClient
import com.orcagateway.core.client.OrcaActionException
import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ActionList
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.resolver.ValueResolver
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.Continuation
import kotlin.coroutines.cancellation.CancellationException
import kotlin.coroutines.resume
import kotlin.coroutines.startCoroutine
import kotlin.coroutines.suspendCoroutine

/**
 * Runs a page's actions: state changes through the store, structural changes
 * through [onMutation], everything else as effects. A port of
 * `sdk/lib/src/state/action_executor.dart` for the kinds the caps vector
 * advertises (sdk-kotlin/capabilities.json).
 *
 * Every platform effect is first reported to [onEffect] as data (what the
 * cross-SDK fixtures in schema/fixtures/actions compare), then handed to
 * [perform] (the host's navigation, system and toast adapters). A
 * `serverAction` is the one effect the executor carries out itself: it emits
 * the request, POSTs it through [client] and runs the actions that come
 * back. Without [perform] or [client] the executor is pure, which is how the
 * fixtures run on the JVM.
 *
 * Use it from one thread, like the store it changes (the main dispatcher on
 * Android). The actions of a parallel group start as child coroutines of the
 * caller's context.
 */
public class ActionExecutor(
    public val store: ElmStore,
    public val client: ActionClient? = null,
) {
    /** Every effect, as data, before it is performed. */
    public var onEffect: ((ActionEffect) -> Unit)? = null

    /**
     * Performs an effect on the platform (navigation, URL, clipboard, share,
     * snackbar and toast). Not called for `serverAction`.
     */
    public var perform: (suspend (ActionEffect) -> Unit)? = null

    /** A structural change from a server action, for the page's node tree. */
    public var onMutation: ((ComponentMutation) -> Unit)? = null

    private val reducer = ActionReducer()
    private var eventData: Map<String, JsonValue>? = null

    /**
     * Run one action. [eventData] feeds `V.event(...)` for this action and
     * everything it runs, as Dart's `execute(action, eventData:)` does.
     */
    public suspend fun execute(action: Action, eventData: Map<String, JsonValue>? = null) {
        val previous = this.eventData
        if (eventData != null) this.eventData = eventData
        try {
            run(action)
        } finally {
            this.eventData = previous
        }
    }

    /** Run actions one after another (Dart `executeAll`). */
    public suspend fun executeAll(actions: List<Action>, eventData: Map<String, JsonValue>? = null) {
        for (action in actions) execute(action, eventData)
    }

    // MARK: Handlers

    private val resolver: ValueResolver get() = store.state.resolver(eventData)

    /**
     * Every action run, nested ones too, is a DevTools `action` event, sent
     * when it finishes (so children before their group) or throws. A
     * cancelled run is not a failure and did not finish: no event.
     */
    private suspend fun run(action: Action) {
        if (action.kind !in kinds) return
        if (!OrcaDebug.isEnabled) return handle(action)
        val start = OrcaDebug.now()
        var cancelled = false
        try {
            handle(action)
        } catch (e: CancellationException) {
            cancelled = true
            throw e
        } finally {
            if (!cancelled) {
                OrcaDebug.report { DevToolsEvent.action(action, pageId = store.pageId ?: "", durationMs = OrcaDebug.now() - start) }
            }
        }
    }

    private suspend fun handle(action: Action) {
        when (action) {
            is Action.SetState, is Action.ShowSnackbar, is Action.ShowToast -> {
                val (next, effects) = reducer.reduce(store.state, action, eventData)
                store.commit(next)
                for (effect in effects) emit(effect)
            }

            is Action.ActionGroup ->
                if (action.mode == "parallel") {
                    runParallel(action.actions)
                } else {
                    for (inner in action.actions) run(inner)
                }

            is Action.ConditionalAction -> {
                val resolver = this.resolver
                for (branch in action.branches) {
                    if (resolver.evaluate(branch.condition)) {
                        run(branch.then)
                        return
                    }
                }
                action.elseAction?.let { run(it) }
            }

            is Action.Lifecycle -> runLifecycle(action)

            is Action.Navigate -> {
                val resolver = this.resolver
                val route = resolver.resolveToString(action.route ?: action.path ?: JsonValue.Null)
                if (route.isEmpty()) return
                val payload = linkedMapOf<String, JsonValue>(
                    "route" to JsonValue.String(route),
                    "replace" to JsonValue.Bool(action.replace == true),
                )
                action.params?.let { params -> payload["params"] = JsonValue.Object(params.mapValues { resolver.resolve(it.value) }) }
                emit(ActionEffect("navigate", payload))
            }

            Action.GoBack -> emit(ActionEffect("goBack"))

            is Action.OpenUrl ->
                emit(ActionEffect("openUrl", mapOf("url" to JsonValue.String(resolver.resolveToString(action.url ?: JsonValue.Null)))))

            is Action.CopyToClipboard ->
                emit(
                    ActionEffect(
                        "copyToClipboard",
                        mapOf("text" to JsonValue.String(resolver.resolveToString(action.text ?: JsonValue.Null))),
                    ),
                )

            is Action.Share -> {
                val resolver = this.resolver
                val text = resolver.resolveToString(action.text ?: action.message ?: JsonValue.Null)
                val subject = resolver.resolveToString(action.subject ?: action.title ?: JsonValue.Null)
                val payload = linkedMapOf<String, JsonValue>("text" to JsonValue.String(text))
                if (subject.isNotEmpty()) payload["subject"] = JsonValue.String(subject)
                emit(ActionEffect("share", payload))
            }

            is Action.ServerAction -> runServerAction(action)

            is Action.UpdateComponent -> onMutation?.invoke(ComponentMutation.Update(action.id, action.props ?: emptyMap()))

            is Action.DeleteComponent -> onMutation?.invoke(ComponentMutation.Delete(action.id))

            is Action.AddComponent -> {
                val nodes = (action.components?.arrayValue ?: emptyList()).map { it.decode(ComponentNode.serializer()) }
                onMutation?.invoke(ComponentMutation.Add(action.parentId, nodes, action.position))
            }

            is Action.Unknown -> {
                if (action.kind != "replaceComponent") return
                val target = action.raw["targetId"].stringValue ?: return
                val nodes = (action.raw["components"].arrayValue ?: emptyList()).map { it.decode(ComponentNode.serializer()) }
                onMutation?.invoke(ComponentMutation.Replace(target, nodes))
            }

            else -> return
        }
    }

    /** Report an effect, then hand it to the platform. */
    private suspend fun emit(effect: ActionEffect) {
        onEffect?.invoke(effect)
        perform?.invoke(effect)
    }

    /**
     * Dart `Future.wait`: start every action, wait for all of them, then
     * throw the first error to occur, if any.
     */
    private suspend fun runParallel(actions: List<Action>) {
        if (actions.isEmpty()) return
        val lock = Any()
        var firstError: Throwable? = null
        suspendCoroutine<Unit> { done ->
            val remaining = AtomicInteger(actions.size)
            for (action in actions) {
                val child: suspend () -> Unit = { run(action) }
                child.startCoroutine(
                    Continuation(done.context) { result ->
                        result.exceptionOrNull()?.let { error ->
                            synchronized(lock) { if (firstError == null) firstError = error }
                        }
                        if (remaining.decrementAndGet() == 0) done.resume(Unit)
                    },
                )
            }
        }
        synchronized(lock) { firstError }?.let { throw it }
    }

    /**
     * onLoading, then the action and onSuccess; onError on a throw (or the
     * error goes on up when there is none); onComplete always, last.
     * Cancellation is not a failure: it goes straight up, skipping onError
     * and onComplete, as coroutines expect.
     */
    private suspend fun runLifecycle(l: Action.Lifecycle) {
        runList(l.onLoading)
        var failure: Throwable? = null
        try {
            run(l.action)
            runList(l.onSuccess)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            val onError = l.onError
            if (onError != null) {
                try {
                    runList(onError)
                } catch (c: CancellationException) {
                    throw c
                } catch (next: Exception) {
                    failure = next
                }
            } else {
                failure = e
            }
        }
        runList(l.onComplete)
        failure?.let { throw it }
    }

    private suspend fun runList(list: ActionList?) {
        for (action in list?.actions ?: emptyList()) run(action)
    }

    /**
     * Emit the request, POST it, run what comes back. A refused call (a
     * status other than 200) shows its message in a snackbar and does not
     * throw, as in Dart; a transport failure throws.
     */
    private suspend fun runServerAction(s: Action.ServerAction) {
        val resolver = this.resolver
        val params = s.params?.mapValues { resolver.resolve(it.value) }
        val payload = linkedMapOf<String, JsonValue>("id" to JsonValue.String(s.id))
        if (params != null) payload["params"] = JsonValue.Object(params)
        onEffect?.invoke(ActionEffect("serverAction", payload))

        val client = client ?: return
        try {
            val state = store.state
            val actions = client.executeAction(s.id, params, state.page, state.app)
            for (action in actions) run(action)
        } catch (e: OrcaActionException) {
            run(Action.ShowSnackbar(message = JsonValue.String(e.message)))
        }
    }

    public companion object {
        /**
         * The kinds this executor runs. Anything else does nothing, as an
         * unregistered handler does in Dart. `replaceComponent` is a server
         * response kind outside action.ts, so it is handled but never
         * advertised.
         */
        public val kinds: Set<String> = setOf(
            "setState", "actionGroup", "showSnackbar", "showToast", "conditionalAction",
            "lifecycle", "navigate", "goBack", "openUrl", "copyToClipboard", "share",
            "serverAction", "addComponent", "updateComponent", "deleteComponent", "replaceComponent",
        )

        /** True when the action and everything nested in it is implemented. */
        public fun implements(action: Action): Boolean = when (action) {
            is Action.ActionGroup -> action.actions.all(::implements)
            is Action.Lifecycle -> implements(action.action)
            is Action.ConditionalAction ->
                action.branches.all { implements(it.then) } && (action.elseAction?.let(::implements) ?: true)
            else -> action.kind in kinds
        }
    }
}
