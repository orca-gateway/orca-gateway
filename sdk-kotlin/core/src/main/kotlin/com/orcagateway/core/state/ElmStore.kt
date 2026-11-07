package com.orcagateway.core.state

import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.Fields
import com.orcagateway.core.models.JsonTreeSerializer
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.resolver.StatePath
import com.orcagateway.core.resolver.ValueResolver
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import java.util.TreeMap

/**
 * Both state scopes as one value: what a reducer reads and returns, and the
 * shape of `state` and `expected.state` in schema/fixtures/actions.
 */
@Serializable(with = StoreStateSerializer::class)
public data class StoreState(
    public val page: Map<String, JsonValue> = emptyMap(),
    public val app: Map<String, JsonValue> = emptyMap(),
) {
    /** App first, page on top: the view every Dart call site resolves against. */
    public val merged: Map<String, JsonValue> get() = app + page

    /** Read a key (flat, or a dotted path) from the merged view. */
    public fun value(key: String): JsonValue = StatePath.lookup(merged, key)

    public operator fun get(scope: StateScope): Map<String, JsonValue> = if (scope == StateScope.App) app else page

    /** A copy with one scope replaced. */
    public fun with(scope: StateScope, values: Map<String, JsonValue>): StoreState =
        if (scope == StateScope.App) copy(app = values) else copy(page = values)

    /**
     * Pure write of one flat key, as the Dart `setState` handler does
     * (`theme.color` is stored as that flat key, which `lookup` finds first).
     */
    public fun setting(key: String, value: JsonValue, scope: StateScope): StoreState = with(scope, get(scope) + (key to value))

    /** Pure merge of several keys into one scope (Dart `ElmStore.dispatch`). */
    public fun merging(update: Map<String, JsonValue>, scope: StateScope): StoreState = with(scope, get(scope) + update)

    /** A resolver over the merged view. */
    public fun resolver(eventData: Map<String, JsonValue>? = null): ValueResolver =
        ValueResolver(state = merged, eventData = eventData)
}

/**
 * A side effect an action asks the host to perform, as data: navigation,
 * snackbar and toast, URL launch, clipboard, share, server call. Mirrors the
 * Dart `ActionEffect` (`{type, ...payload}`), so fixtures compare effects as
 * plain JSON and every SDK must emit the same list for the same actions.
 */
@Serializable(with = ActionEffectSerializer::class)
public data class ActionEffect(public val type: String, public val payload: Map<String, JsonValue> = emptyMap()) {
    /** `{"type": type, ...payload}`, the wire shape in the fixtures. */
    public val json: JsonValue get() = JsonValue.Object(payload + ("type" to JsonValue.String(type)))

    public companion object {
        /** Read `{"type": ..., ...payload}`; throws [SerializationException] without a string type. */
        public fun fromJson(json: JsonValue): ActionEffect {
            val o = json.objectValue
            val type = o?.get("type")?.stringValue
                ?: throw SerializationException("An effect is an object with a string type")
            return ActionEffect(type, o - "type")
        }
    }
}

/**
 * A reducer: the current state and one action in, the next state and the
 * effects to run out. Keeping it pure is what lets the action fixtures run
 * without a UI.
 */
public typealias Reducer = (StoreState, Action) -> Pair<StoreState, List<ActionEffect>>

/**
 * The observable state holder behind a page: page and app scopes, change
 * notifications scoped to the keys a view watches.
 *
 * A subscriber names the state keys it depends on (a node's `watches`;
 * dotted paths allowed). After every commit the store compares each
 * subscriber's watched values before and after against the merged view and
 * notifies only the subscribers whose values changed, which is what the
 * Flutter `WatchBuilder` does per node. Not thread-safe: use it from one
 * thread (the main thread in the UI layer).
 */
public class ElmStore(initial: StoreState = StoreState()) {
    public constructor(page: Map<String, JsonValue>, app: Map<String, JsonValue> = emptyMap()) :
        this(StoreState(page, app))

    public var state: StoreState = initial
        private set

    private class Subscriber(
        val watches: List<String>,
        var snapshot: List<JsonValue>,
        val onChange: (StoreState) -> Unit,
    )

    private val subscribers = TreeMap<Int, Subscriber>()
    private var nextId = 0

    /**
     * Called after every commit with the new state, before subscribers are
     * notified: how a navigator keeps the app scope shared between pages.
     */
    public var onCommit: ((StoreState) -> Unit)? = null

    /**
     * The page this store belongs to (Dart `ElmStore.pageId`); DevTools
     * reports changed keys against it.
     */
    public var pageId: String? = null

    /** Read a key from the merged view (flat key first, then dotted path). */
    public fun value(key: String): JsonValue = state.value(key)

    /**
     * Seed a page from its `PageResponse.state` (Dart `StateManager.initPage`):
     * page definitions replace the page scope; an app definition is applied
     * only when that app key is still unset, so app state survives navigation.
     */
    public fun seed(definitions: List<StateDefinition>) {
        val page = LinkedHashMap<String, JsonValue>()
        val app = LinkedHashMap(state.app)
        for (def in definitions) {
            when (def.scope) {
                StateScope.Page -> page[def.key] = def.initial
                StateScope.App -> if ((app[def.key] ?: JsonValue.Null).isNull) app[def.key] = def.initial
            }
        }
        commit(StoreState(page, app))
    }

    /** Merge keys into one scope and notify (Dart `ElmStore.dispatch`). */
    public fun dispatch(update: Map<String, JsonValue>, scope: StateScope = StateScope.Page) {
        commit(state.merging(update, scope))
    }

    /**
     * Run a pure reducer, commit its state, and hand back its effects for the
     * platform adapters to perform.
     */
    public fun apply(action: Action, reducer: Reducer): List<ActionEffect> {
        val (next, effects) = reducer(state, action)
        commit(next)
        return effects
    }

    /**
     * Replace the state and notify the subscribers whose watched values
     * changed. Subscribers are notified in subscription order.
     */
    public fun commit(next: StoreState) {
        val previous = state
        state = next
        val pageId = pageId
        if (pageId != null && OrcaDebug.isEnabled) {
            for (event in DevToolsEvent.stateChanges(previous, next, pageId)) OrcaDebug.report { event }
        }
        onCommit?.invoke(next)
        val merged = next.merged
        for (id in subscribers.keys.toList()) {
            val sub = subscribers[id] ?: continue
            val snapshot = sub.watches.map { StatePath.lookup(merged, it) }
            if (snapshot == sub.snapshot) continue
            sub.snapshot = snapshot
            sub.onChange(next)
        }
    }

    /**
     * Watch some keys. The handler runs after any commit that changes one of
     * their values, until the returned subscription is cancelled (or closed:
     * Kotlin has no deinit, so a scope-bound watch uses `use { }`).
     */
    public fun subscribe(watches: List<String>, onChange: (StoreState) -> Unit): Subscription {
        val id = nextId
        nextId += 1
        val merged = state.merged
        subscribers[id] = Subscriber(watches, watches.map { StatePath.lookup(merged, it) }, onChange)
        return Subscription { subscribers.remove(id) }
    }

    public val subscriberCount: Int get() = subscribers.size

    /** Stops its watch when cancelled or closed; cancelling twice is harmless. */
    public class Subscription internal constructor(cancel: () -> Unit) : AutoCloseable {
        private var cancelAction: (() -> Unit)? = cancel

        public fun cancel() {
            cancelAction?.invoke()
            cancelAction = null
        }

        override fun close(): Unit = cancel()
    }
}

// MARK: - Serializers

internal object StoreStateSerializer : JsonTreeSerializer<StoreState>("com.orcagateway.core.state.StoreState") {
    override fun fromTree(tree: JsonValue): StoreState {
        val f = Fields.of(tree, "StoreState")
        return StoreState(f.obj("page"), f.obj("app"))
    }

    override fun toTree(value: StoreState): JsonValue =
        JsonValue.Object(linkedMapOf("page" to JsonValue.Object(value.page), "app" to JsonValue.Object(value.app)))
}

internal object ActionEffectSerializer : JsonTreeSerializer<ActionEffect>("com.orcagateway.core.state.ActionEffect") {
    override fun fromTree(tree: JsonValue): ActionEffect = ActionEffect.fromJson(tree)

    override fun toTree(value: ActionEffect): JsonValue = value.json
}
