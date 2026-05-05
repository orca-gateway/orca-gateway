import '../models/component_node.dart';
import '../state/action_executor.dart';
import '../state/elm_store.dart';
import '../state/value_resolver.dart';
import 'component_registry.dart';

/// Context passed to component builders during rendering.
class OrcaComponentContext {
  /// The node being rendered.
  final ComponentNode node;

  /// Lookup map of all nodes by ID.
  final Map<String, ComponentNode> nodeMap;

  /// Function to recursively render a child node by ID.
  final OrcaWidgetBuilder renderChild;

  /// Current state values (merged page + app state).
  final Map<String, dynamic> state;

  /// Action executor for dispatching actions from event handlers.
  final ActionExecutor? actionExecutor;

  /// Animation progress (0.0–1.0) for tween value resolution.
  /// Non-null only when this context is inside an AnimatedBuilder subtree.
  final double? animationProgress;

  /// Reference to the component registry for nested rendering (e.g. AnimatedBuilder).
  final ComponentRegistry? registry;

  /// Page store for reactive WatchBuilder wrapping inside AnimatedBuilder.
  final ElmStore? store;

  /// When true, prop resolutions are traced for debugging.
  final bool captureTraces;

  late final ValueResolver _resolver = ValueResolver(
    state: state,
    animationProgress: animationProgress,
    animationRegistry: actionExecutor?.animationRegistry,
  );

  /// Per-prop transform traces captured during rendering.
  final Map<String, List<Map<String, dynamic>>> propTraces = {};

  OrcaComponentContext({
    required this.node,
    required this.nodeMap,
    required this.renderChild,
    this.state = const {},
    this.actionExecutor,
    this.animationProgress,
    this.registry,
    this.store,
    this.captureTraces = false,
  });

  /// Get a prop value, resolving any Value objects (state refs, transforms)
  /// first — including ones nested inside maps / lists. Deep resolution is
  /// required so that e.g. `style: { color: V.when(...) }` produces a plain
  /// String by the time `parseTextStyle` casts it. `resolveDeep` already
  /// short-circuits to `resolve` when the top-level IS a Value, so this is
  /// strictly more correct, never slower for plain props.
  T? prop<T>(String key) {
    final raw = node.props[key];
    if (raw == null) return null;
    if (captureTraces && raw is Map) {
      final (value, trace) = _resolver.resolveWithTrace(raw);
      if (trace.isNotEmpty) {
        propTraces[key] = trace.map((t) => t.toJson()).toList();
      }
      return value as T?;
    }
    return _resolver.resolveDeep(raw) as T?;
  }

  /// Get a prop value with a default, resolving Value objects first.
  T propOr<T>(String key, T defaultValue) {
    final raw = node.props[key];
    if (raw == null) return defaultValue;
    if (captureTraces && raw is Map) {
      final (value, trace) = _resolver.resolveWithTrace(raw);
      if (trace.isNotEmpty) {
        propTraces[key] = trace.map((t) => t.toJson()).toList();
      }
      return (value as T?) ?? defaultValue;
    }
    final resolved = _resolver.resolveDeep(raw);
    return (resolved as T?) ?? defaultValue;
  }

  /// Get the list of child node IDs.
  List<String> get childIds => node.children;

  /// Read a state value by key.
  dynamic stateGet(String key) => state[key];

  /// Execute the action(s) bound to the given event name (e.g. "onTap").
  ///
  /// Pass [eventData] to make event values available to the action
  /// (e.g. `{'value': newText}` for onChange on a TextField).
  ///
  /// The node id + event name are threaded to the executor as the "source"
  /// so `Once(...)` wrappers can dedupe by (widgetId, trigger).
  void fireAction(String eventName, {Map<String, dynamic>? eventData}) {
    if (actionExecutor == null || node.actions == null) return;
    final action = node.actions![eventName];
    if (action == null) return;
    final source = ActionSource(widgetId: node.id, trigger: eventName);
    if (action is List) {
      actionExecutor!.executeAll(action, eventData: eventData, source: source);
    } else if (action is Map<String, dynamic>) {
      actionExecutor!.execute(action, eventData: eventData, source: source);
    }
  }
}

/// Signature for building a Flutter widget from a component context.
typedef OrcaWidgetBuilder = dynamic Function(String nodeId);
