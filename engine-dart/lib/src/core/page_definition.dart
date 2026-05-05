import '../types/context.dart';
import '../types/state.dart';
import '../types/widget.dart' as w;
import 'page.dart';

/// Config for building an inline page without class inheritance.
class PageDefinitionConfig {
  final String id;
  final String title;
  final List<String> appState;
  final CachePolicy cachePolicy;
  final int cacheTtl;
  final List<StateDefinition> Function(PageContext)? state;
  final Future<dynamic> Function(PageContext)? getInfoData;
  final w.Widget Function(PageContext, dynamic) render;
  final void Function(PageContext, PageResponse)? postRender;

  const PageDefinitionConfig({
    required this.id,
    required this.title,
    this.appState = const [],
    this.cachePolicy = 'none',
    this.cacheTtl = 60,
    this.state,
    this.getInfoData,
    required this.render,
    this.postRender,
  });
}

/// Factory for creating pages from closures.
class PageDefinition {
  static Page create(PageDefinitionConfig config) => _InlinePage(config);
}

class _InlinePage extends Page {
  final PageDefinitionConfig _config;

  _InlinePage(this._config);

  @override
  String get id => _config.id;
  @override
  String get title => _config.title;
  @override
  CachePolicy get cachePolicy => _config.cachePolicy;
  @override
  int get cacheTtl => _config.cacheTtl;

  @override
  List<String> requiredAppState() => _config.appState;

  @override
  Future<dynamic> getInfoData(PageContext context) async {
    if (_config.getInfoData != null) return _config.getInfoData!(context);
    return null;
  }

  @override
  List<StateDefinition> getState(PageContext context) {
    if (_config.state != null) return _config.state!(context);
    return [];
  }

  @override
  w.Widget render(PageContext context, dynamic infoData) =>
      _config.render(context, infoData);

  @override
  void postRender(PageContext context, PageResponse response) {
    _config.postRender?.call(context, response);
  }
}
