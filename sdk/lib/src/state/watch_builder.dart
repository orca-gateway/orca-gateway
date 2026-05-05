import 'package:flutter/widgets.dart';
import 'elm_store.dart';

/// A widget that subscribes to specific state keys in an [ElmStore]
/// and only rebuilds when those watched keys change.
///
/// This enables efficient re-rendering: a page may have 100 widgets
/// but if only one watches "count", only that widget rebuilds when
/// "count" changes.
class WatchBuilder extends StatefulWidget {
  /// The store to watch.
  final ElmStore store;

  /// The set of state keys this widget depends on.
  final Set<String> watches;

  /// Builder that receives the current state snapshot.
  final Widget Function(BuildContext context, Map<String, dynamic> state)
      builder;

  const WatchBuilder({
    super.key,
    required this.store,
    required this.watches,
    required this.builder,
  });

  @override
  State<WatchBuilder> createState() => _WatchBuilderState();
}

class _WatchBuilderState extends State<WatchBuilder> {
  late Map<String, dynamic> _lastWatchedValues;

  @override
  void initState() {
    super.initState();
    _lastWatchedValues = _snapshotWatched();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(WatchBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStoreChanged);
      widget.store.addListener(_onStoreChanged);
      _lastWatchedValues = _snapshotWatched();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// Take a snapshot of only the watched keys.
  Map<String, dynamic> _snapshotWatched() {
    final state = widget.store.state;
    return {
      for (final key in widget.watches)
        if (state.containsKey(key)) key: state[key],
    };
  }

  void _onStoreChanged() {
    final current = _snapshotWatched();
    if (_hasChanged(current)) {
      _lastWatchedValues = current;
      if (mounted) setState(() {});
    }
  }

  bool _hasChanged(Map<String, dynamic> current) {
    if (current.length != _lastWatchedValues.length) return true;
    for (final key in current.keys) {
      if (current[key] != _lastWatchedValues[key]) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.store.state);
  }
}
