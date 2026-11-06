package com.orcagateway.core.state

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.StateScope

/**
 * The pure part of the action executor: state and one action in, the next
 * state and the effects to perform out. Ports the matching handlers of
 * `sdk/lib/src/state/action_executor.dart`.
 *
 * It carries the four kinds the counter page needs: `setState`,
 * `actionGroup`, `showSnackbar` and `showToast`. Every other kind leaves the
 * state alone and emits nothing, the same as an unregistered handler in Dart.
 */
public class ActionReducer {
    /**
     * Run one action. [eventData] feeds `V.event(...)` values, as Dart's
     * `execute(action, eventData:)` does.
     */
    public fun reduce(
        state: StoreState,
        action: Action,
        eventData: Map<String, JsonValue>? = null,
    ): Pair<StoreState, List<ActionEffect>> = when (action) {
        is Action.SetState -> {
            val value = state.resolver(eventData).resolve(action.value)
            state.setting(action.key, value, action.scope ?: StateScope.Page) to emptyList()
        }

        is Action.ActionGroup -> {
            // Sequential: each action sees the state the previous one wrote.
            // Dart's parallel mode starts every handler at once, but these
            // handlers finish synchronously in list order, so the result is
            // the same.
            var current = state
            val effects = ArrayList<ActionEffect>()
            for (inner in action.actions) {
                val (next, more) = reduce(current, inner, eventData)
                current = next
                effects += more
            }
            current to effects
        }

        is Action.ShowSnackbar -> {
            val message = state.resolver(eventData).resolveToString(action.message ?: JsonValue.Null)
            state to listOf(
                ActionEffect(
                    "showSnackbar",
                    mapOf("message" to JsonValue.String(message), "duration" to JsonValue.Int(action.duration ?: 4000)),
                ),
            )
        }

        is Action.ShowToast -> {
            val message = state.resolver(eventData).resolveToString(action.message ?: JsonValue.Null)
            state to listOf(
                ActionEffect(
                    "showToast",
                    mapOf("message" to JsonValue.String(message), "duration" to JsonValue.Int(action.duration ?: 2000)),
                ),
            )
        }

        else -> state to emptyList()
    }

    /** This reducer as the store's [Reducer] (no event data). */
    public val reducer: Reducer get() = { state, action -> reduce(state, action) }

    public companion object {
        /** The kinds this reducer implements. */
        public val kinds: Set<String> = setOf("setState", "actionGroup", "showSnackbar", "showToast")

        /** True when the action and everything nested in it is implemented here. */
        public fun implements(action: Action): Boolean {
            if (action is Action.ActionGroup) return action.actions.all(::implements)
            return action.kind in kinds
        }
    }
}
