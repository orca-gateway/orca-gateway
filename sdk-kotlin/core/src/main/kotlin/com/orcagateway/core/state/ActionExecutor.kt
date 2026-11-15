package com.orcagateway.core.state

import com.orcagateway.core.client.ActionClient
import com.orcagateway.core.client.OrcaActionException
import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ActionList
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.resolver.ValueResolver
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.Continuation
import kotlin.coroutines.cancellation.CancellationException
import kotlin.coroutines.resume
import kotlin.coroutines.startCoroutine
import kotlin.coroutines.suspendCoroutine
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Where an action chain started: the node and the trigger that fired it
 * (Flutter `ActionSource`). `once` dedupes by it; nested runs inherit it.
 */
public data class ActionSource(public val widgetId: String, public val trigger: String) {
    /** `widgetId::trigger`, the key a `once` records. */
    public val dedupeKey: String get() = "$widgetId::$trigger"
}

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
    private val handlers = HashMap<String, OrcaActionHandler>()
    private var source: ActionSource? = null

    /**
     * The [ActionSource.dedupeKey]s of the `once` wrappers that have run, for
     * the life of this executor (the page model's). A `once` with a source
     * runs its action the first time its key is seen and never again; one
     * without a source (a run no widget fired) runs every time. `always`
     * just runs its action.
     *
     * Flutter's known limit, kept: the key holds no id of the wrapper, so two
     * `once` under one widget and trigger share it, and in
     * `Sequential(Once(a), Once(b))` b never runs.
     */
    private val firedOnceKeys = HashSet<String>()

    /**
     * Run [handler] for every action of [type] (Dart `registerHandler`,
     * sdk/lib/src/state/action_executor.dart). It overrides a built-in of
     * that name; registering a type again replaces its handler. An action
     * looks up its type as sent first, then the type without a leading
     * `custom:`, so a plugin registers its bare name.
     */
    public fun registerHandler(type: String, handler: OrcaActionHandler) {
        handlers[type] = handler
    }

    /**
     * Resolve a value expression against the store's page and app state and
     * the event data of the action being run (Dart `resolveValue`), for a
     * handler reading its own params (`V.event`, `V.pageState`, ...).
     */
    public fun resolve(value: JsonElement): JsonElement =
        resolver.resolve(JsonValue.fromJsonElement(value)).toJsonElement()

    /**
     * Run one action. [eventData] feeds `V.event(...)` for this action and
     * everything it runs, as Dart's `execute(action, eventData:)` does.
     * [source] is the widget and trigger that fired it, for `once`; nested
     * runs inherit both, and both are restored when this returns.
     */
    public suspend fun execute(action: Action, eventData: Map<String, JsonValue>? = null, source: ActionSource? = null) {
        val previousEventData = this.eventData
        val previousSource = this.source
        if (eventData != null) this.eventData = eventData
        if (source != null) this.source = source
        try {
            run(action)
        } finally {
            this.eventData = previousEventData
            this.source = previousSource
        }
    }

    /** Run actions one after another (Dart `executeAll`). */
    public suspend fun executeAll(actions: List<Action>, eventData: Map<String, JsonValue>? = null, source: ActionSource? = null) {
        for (action in actions) execute(action, eventData, source)
    }

    // MARK: Handlers

    private val resolver: ValueResolver get() = store.state.resolver(eventData)

    /**
     * Every action run, nested ones too, is a DevTools `action` event, sent
     * when it finishes (so children before their group) or throws. A
     * cancelled run is not a failure and did not finish: no event.
     */
    private suspend fun run(action: Action) {
        val kind = action.kind
        val handler = handlers[kind] ?: handlers[kind.removePrefix("custom:")]
        if (handler == null && kind !in kinds) return
        if (!OrcaDebug.isEnabled) return dispatch(action, handler)
        val start = OrcaDebug.now()
        var cancelled = false
        try {
            dispatch(action, handler)
        } catch (e: CancellationException) {
            cancelled = true
            throw e
        } finally {
            if (!cancelled) {
                OrcaDebug.report { DevToolsEvent.action(action, pageId = store.pageId ?: "", durationMs = OrcaDebug.now() - start) }
            }
        }
    }

    /** A registered handler gets the action as sent; otherwise the built-in runs. */
    private suspend fun dispatch(action: Action, handler: OrcaActionHandler?) {
        if (handler == null) return handle(action)
        val raw = action.json.toJsonElement() as? JsonObject ?: JsonObject(mapOf("type" to JsonPrimitive(action.kind)))
        handler.handle(raw, this)
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

            is Action.Once -> {
                val key = source?.dedupeKey
                if (key != null && !firedOnceKeys.add(key)) return
                run(action.action)
            }

            is Action.Always -> run(action.action)

            is Action.DebugLog -> runDebugLog(action)

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

            is Action.SwitchTab -> emit(ActionEffect("switchTab", mapOf("tabId" to JsonValue.String(action.tabId))))

            Action.OpenDrawer -> emit(ActionEffect("openDrawer", emptyMap()))

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
     * Dart's debugLog handler, as an effect: `{type: "debugLog", level, tag,
     * message?, data?}` with the level (default debug) and the tag (default
     * orca), the message resolved as text and `data` resolved entry by entry
     * when it is an object, even a Value's (Dart's `rawData is Map`), else as
     * one value; an entry that fails is "<unresolvable>". No timestamp and nothing
     * from the include* flags: the effect is deterministic, and printing it
     * is the host's job. Never throws, so a failing log cannot stop the
     * group it sits in; only cancellation goes on up.
     */
    private suspend fun runDebugLog(log: Action.DebugLog) {
        try {
            val resolver = this.resolver
            val payload = linkedMapOf<String, JsonValue>(
                "level" to JsonValue.String(log.level ?: "debug"),
                "tag" to JsonValue.String(log.tag ?: "orca"),
            )
            log.message?.takeUnless { it.isNull }?.let { raw ->
                val message = try {
                    resolver.resolveToString(raw)
                } catch (e: Exception) {
                    DartFormat.string(raw)
                }
                payload["message"] = JsonValue.String(message)
            }
            log.data?.takeUnless { it.isNull }?.let { raw ->
                fun resolved(value: JsonValue): JsonValue = try {
                    resolver.resolve(value)
                } catch (e: Exception) {
                    JsonValue.String("<unresolvable>")
                }
                val data = raw.objectValue?.let { entries -> JsonValue.Object(entries.mapValues { resolved(it.value) }) } ?: resolved(raw)
                if (!data.isNull) payload["data"] = data
            }
            emit(ActionEffect("debugLog", payload))
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            return
        }
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
         * The built-in kinds this executor runs. Anything else does nothing
         * unless a handler is registered for it (see [registerHandler]), as
         * in Dart. `replaceComponent` is a server
         * response kind outside action.ts, so it is handled but never
         * advertised.
         */
        public val kinds: Set<String> = setOf(
            "setState", "actionGroup", "showSnackbar", "showToast", "conditionalAction",
            "lifecycle", "navigate", "goBack", "switchTab", "openDrawer", "openUrl", "copyToClipboard", "share",
            "serverAction", "addComponent", "updateComponent", "deleteComponent", "replaceComponent",
            "once", "always", "debugLog",
        )

        /** True when the action and everything nested in it is implemented. */
        public fun implements(action: Action): Boolean = when (action) {
            is Action.ActionGroup -> action.actions.all(::implements)
            is Action.Lifecycle -> implements(action.action)
            is Action.Once -> implements(action.action)
            is Action.Always -> implements(action.action)
            is Action.ConditionalAction ->
                action.branches.all { implements(it.then) } && (action.elseAction?.let(::implements) ?: true)
            else -> action.kind in kinds
        }
    }
}
