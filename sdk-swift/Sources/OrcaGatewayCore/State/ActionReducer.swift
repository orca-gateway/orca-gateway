import Foundation

/// The pure part of the action executor: state and one action in, the next
/// state and the effects to perform out. Ports the matching handlers of
/// `sdk/lib/src/state/action_executor.dart`.
///
/// S2 carries the four kinds the counter page needs (decided at native-sdk-s2
/// gate 08): `setState`, `actionGroup`, `showSnackbar` and `showToast`. Every
/// other kind leaves the state alone and emits nothing until S3 adds it, the
/// same as an unregistered handler in Dart.
public struct ActionReducer: Sendable {
    /// The kinds this reducer implements.
    public static let kinds: Set<String> = ["setState", "actionGroup", "showSnackbar", "showToast"]

    public init() {}

    /// Run one action. `eventData` feeds `V.event(...)` values, as Dart's
    /// `execute(action, eventData:)` does.
    public func reduce(
        _ state: StoreState, _ action: Action, eventData: [String: JSONValue]? = nil
    ) -> (StoreState, [ActionEffect]) {
        switch action {
        case .setState(let a):
            return (setState(state, a, eventData: eventData).state, [])

        case .actionGroup(let group):
            // Sequential: each action sees the state the previous one wrote.
            // Dart's parallel mode starts every handler at once, but these
            // handlers finish synchronously in list order, so the result is
            // the same.
            var current = state
            var effects: [ActionEffect] = []
            for inner in group.actions {
                let (next, more) = reduce(current, inner, eventData: eventData)
                current = next
                effects += more
            }
            return (current, effects)

        case .showSnackbar(let a):
            let message = state.resolver(eventData: eventData).resolveToString(a.message ?? .null)
            return (state, [ActionEffect("showSnackbar", [
                "message": .string(message), "duration": .int(a.duration ?? 4000),
            ])])

        case .showToast(let a):
            let message = state.resolver(eventData: eventData).resolveToString(a.message ?? .null)
            return (state, [ActionEffect("showToast", [
                "message": .string(message), "duration": .int(a.duration ?? 2000),
            ])])

        default:
            return (state, [])
        }
    }

    /// A setState's next state. `traced` (DevTools on) resolves a transform
    /// value once with its trace, which comes back with the state, as
    /// Flutter's setState handler does under OrcaDebug; any other value, or
    /// `traced` false, resolves as `reduce` does and traces nothing.
    func setState(
        _ state: StoreState, _ a: Action.SetState, eventData: [String: JSONValue]?, traced: Bool = false
    ) -> (state: StoreState, trace: [TraceStep]) {
        let resolver = state.resolver(eventData: eventData)
        let scope = a.scope ?? .page
        guard traced, case .object(let map) = a.value, map["type"]?.stringValue == "transform" else {
            return (state.setting(a.key, resolver.resolve(a.value), in: scope), [])
        }
        let (value, trace) = resolver.resolveWithTrace(a.value)
        return (state.setting(a.key, value, in: scope), trace)
    }

    /// This reducer as the store's `Reducer` (no event data).
    public var reducer: Reducer {
        { state, action in reduce(state, action) }
    }

    /// True when the action and everything nested in it is implemented here.
    public static func implements(_ action: Action) -> Bool {
        if case .actionGroup(let group) = action {
            return group.actions.allSatisfy(implements)
        }
        return kinds.contains(action.kind)
    }
}
