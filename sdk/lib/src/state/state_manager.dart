import '../models/page_response.dart';
import 'elm_store.dart';

/// Manages per-page and global (app) ElmStores.
class StateManager {
  /// Global app-level store that persists across pages.
  final ElmStore appStore = ElmStore(pageId: 'app', scope: 'app');

  /// Page-scoped stores keyed by pageId.
  final Map<String, ElmStore> _pageStores = {};

  /// Initialize state for a page from its [StateDefinition] list.
  ///
  /// Page-scoped definitions go into a per-page store.
  /// App-scoped definitions go into the global [appStore].
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
    _pageStores[pageId] = ElmStore(initial: pageInitial, pageId: pageId);
  }

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
