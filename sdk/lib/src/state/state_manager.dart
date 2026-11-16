import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/page_response.dart';
import 'elm_store.dart';

/// Saved copies of state keys, written by `persistState` and removed by
/// `clearState`, read back when a scope is set up.
///
/// One entry per scope: app state under [appEntry], a page's state under
/// [pageEntry] (its pageId), each a JSON object {key: value}. `local` is
/// SharedPreferencesAsync (survives a restart); `session` is a process-wide
/// map of the same entries (outlives pages and OrcaApp rebuilds, not the
/// process). A key is saved in one storage at a time. Reads are synchronous
/// from an in-memory mirror that [load] fills once at boot; local writes go
/// through to the store, and a store failure is swallowed.
class SavedState {
  /// [prefs] replaces the platform store (tests); without it one is made on
  /// first use.
  SavedState({SharedPreferencesAsync? prefs}) : _injected = prefs;

  /// The entry name of the app scope.
  static const appEntry = 'orca_saved_app';

  /// The entry name of the page [pageId].
  static String pageEntry(String pageId) => 'orca_saved_page_$pageId';

  static const _prefix = 'orca_saved_';

  static final Map<String, Map<String, dynamic>> _session = {};

  /// Forget the session storage, as a new process would.
  @visibleForTesting
  static void resetSession() => _session.clear();

  final SharedPreferencesAsync? _injected;
  SharedPreferencesAsync? _made;
  SharedPreferencesAsync get _prefs =>
      _injected ?? (_made ??= SharedPreferencesAsync());

  final Map<String, Map<String, dynamic>> _local = {};

  Map<String, Map<String, dynamic>> _of(String storage) =>
      storage == 'session' ? _session : _local;

  /// A copy of the entry [name] in [storage] (`local` or `session`); empty
  /// when nothing is saved there.
  Map<String, dynamic> entryOf(String storage, String name) => {
    ...?_of(storage)[name],
  };

  /// Read every local entry from the store into the mirror.
  Future<void> load() async {
    try {
      final prefs = _prefs;
      final names = await prefs.getKeys();
      for (final name in names.where((n) => n.startsWith(_prefix))) {
        try {
          final raw = await prefs.getString(name);
          final entry = raw == null ? null : jsonDecode(raw);
          if (entry is Map) _local[name] = Map<String, dynamic>.from(entry);
        } catch (_) {
          // An unreadable entry is skipped; the others still load.
        }
      }
    } catch (_) {
      // No store: nothing saved locally is restored.
    }
  }

  /// Save [key] = [value] in the entry [name] of [storage], and drop the key
  /// from the other storage's entry.
  Future<void> save(
    String name,
    String key,
    dynamic value,
    String storage,
  ) async {
    final local = storage != 'session';
    (_of(local ? 'local' : 'session')[name] ??= {})[key] = value;
    final dropped = _drop(local ? 'session' : 'local', name, key);
    if (local || dropped) await _write(name);
  }

  /// Every saved key of the entry [name], both storages.
  Map<String, dynamic> _restored(String name) => {
    ...?_local[name],
    ...?_session[name],
  };

  /// Remove [key] from the entry [name] in both storages.
  Future<void> _remove(String name, String key) async {
    _drop('session', name, key);
    if (_drop('local', name, key)) await _write(name);
  }

  bool _drop(String storage, String name, String key) {
    final entries = _of(storage);
    final entry = entries[name];
    if (entry == null || !entry.containsKey(key)) return false;
    entry.remove(key);
    if (entry.isEmpty) entries.remove(name);
    return true;
  }

  Future<void> _write(String name) async {
    try {
      final entry = _local[name];
      if (entry == null) {
        await _prefs.remove(name);
      } else {
        await _prefs.setString(name, jsonEncode(entry));
      }
    } catch (_) {
      // The mirror keeps the value for this process.
    }
  }
}

/// Manages per-page and global (app) ElmStores.
class StateManager {
  StateManager({SavedState? saved}) : saved = saved ?? SavedState();

  /// Saved copies of keys (persistState / clearState).
  final SavedState saved;

  /// Global app-level store that persists across pages.
  final ElmStore appStore = ElmStore(pageId: 'app', scope: 'app');

  /// Page-scoped stores keyed by pageId.
  final Map<String, ElmStore> _pageStores = {};

  /// Load the locally saved entries; the boot awaits it before the first page.
  Future<void> loadSaved() => saved.load();

  /// Lay the saved app entry over the app state (at boot, after the config's
  /// initialAppState).
  void restoreApp() {
    final entry = saved._restored(SavedState.appEntry);
    if (entry.isNotEmpty) appStore.dispatch(entry);
  }

  /// Initialize state for a page from its [StateDefinition] list.
  ///
  /// Page-scoped definitions go into a per-page store, under the page's saved
  /// entry. App-scoped definitions go into the global [appStore].
  void initPage(String pageId, List<StateDefinition> definitions) {
    final pageInitial = <String, dynamic>{};
    for (final def in definitions) {
      if (def.scope == 'app') {
        // Only set app state if the key hasn't been set yet (preserve across pages).
        if (appStore.get(def.key) == null) {
          appStore.dispatch({def.key: def.initial});
        }
      } else {
        pageInitial[def.key] = def.initial;
      }
    }
    _pageStores[pageId] = ElmStore(
      initial: {
        ...pageInitial,
        ...saved._restored(SavedState.pageEntry(pageId)),
      },
      pageId: pageId,
    );
  }

  /// Save the current value of [key] (app state, or the page [pageId]) in
  /// [storage]; a key the scope does not hold saves nothing.
  Future<void> persistState(
    String pageId,
    String key, {
    String scope = 'page',
    String storage = 'local',
  }) async {
    final store = scope == 'app' ? appStore : _pageStores[pageId];
    if (store == null || !store.state.containsKey(key)) return;
    await saved.save(_entryOf(scope, pageId), key, store.get(key), storage);
  }

  /// Set [key] to null and remove every saved copy of it.
  Future<void> clearState(
    String pageId,
    String key, {
    String scope = 'page',
  }) async {
    if (scope == 'app') {
      setAppState(key, null);
    } else {
      setPageState(pageId, key, null);
    }
    await saved._remove(_entryOf(scope, pageId), key);
  }

  String _entryOf(String scope, String pageId) =>
      scope == 'app' ? SavedState.appEntry : SavedState.pageEntry(pageId);

  /// Get the page-scoped store. Returns null if page not initialized.
  ElmStore? getPageStore(String pageId) => _pageStores[pageId];

  /// Set a single key in the page store.
  void setPageState(String pageId, String key, dynamic value) {
    _pageStores[pageId]?.dispatch({key: value});
  }

  /// Get a single key from the page store.
  dynamic getPageState(String pageId, String key) {
    return _pageStores[pageId]?.get(key);
  }

  /// Set a single key in the app store.
  void setAppState(String key, dynamic value) {
    appStore.dispatch({key: value});
  }

  /// Get a single key from the app store.
  dynamic getAppState(String key) => appStore.get(key);

  /// Dispose a page store (called on page pop).
  void disposePage(String pageId) {
    _pageStores[pageId]?.dispose();
    _pageStores.remove(pageId);
  }
}
