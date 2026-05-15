import 'package:flutter/widgets.dart';
import 'elm_store.dart';

/// A widget that subscribes to specific state keys across the app- and
/// page-scoped [ElmStore]s and only rebuilds when one of those watched
/// keys changes.
///
/// This enables efficient re-rendering: a page may have 100 widgets
/// but if only one watches "count", only that widget rebuilds when
/// "count" changes.
///
/// The wire-format `watches` array is a flat list of key names and carries
/// no scope tag, so a watched key may live in either store. WatchBuilder
/// subscribes to both and resolves each key against whichever store holds
/// it — this is what makes an `app`-scoped `SetState` rebuild only its
/// watchers instead of the whole page.
class WatchBuilder extends StatefulWidget {
  /// The page-scoped store. Null when the page has no page store.
  final ElmStore? pageStore;

  /// The app-scoped store, shared across pages. Null in scopes that have
  /// no app store (e.g. unit tests exercising page state only).
  final ElmStore? appStore;

  /// The set of state keys this widget depends on.
  final Set<String> watches;

  /// Builder that receives the current merged (app + page) state snapshot.
  final Widget Function(BuildContext context, Map<String, dynamic> state)
      builder;

  const WatchBuilder({
    super.key,
    this.pageStore,
    this.appStore,
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
    widget.pageStore?.addListener(_onStoreChanged);
    widget.appStore?.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(WatchBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageStore != widget.pageStore ||
        oldWidget.appStore != widget.appStore) {
      oldWidget.pageStore?.removeListener(_onStoreChanged);
      oldWidget.appStore?.removeListener(_onStoreChanged);
      widget.pageStore?.addListener(_onStoreChanged);
      widget.appStore?.addListener(_onStoreChanged);
      _lastWatchedValues = _snapshotWatched();
    }
  }

  @override
  void dispose() {
    widget.pageStore?.removeListener(_onStoreChanged);
    widget.appStore?.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// Merge app + page state. Page state wins on a key conflict, matching
  /// the resolution order used everywhere else in the SDK.
  Map<String, dynamic> _mergedState() {
    return <String, dynamic>{
      ...?widget.appStore?.state,
      ...?widget.pageStore?.state,
    };
  }

  /// Take a snapshot of only the watched keys.
  Map<String, dynamic> _snapshotWatched() {
    final state = _mergedState();
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
    return widget.builder(context, _mergedState());
  }
}
