import '../types/context.dart';
import '../types/node.dart';
import '../types/state.dart';
import '../types/widget.dart' as w;

/// Cache policy for page rendering.
typedef CachePolicy = String; // "none" | "static" | CachePolicyConfig JSON

/// Response shape for GET /api/v1/app/:appId/page/:path.
class PageResponse {
  final String pageId;
  // `title` is mutable so `postRender` can rewrite it based on infoData
  // (e.g., show the product name for a dynamic `/catalog/:id` route).
  String title;
  final List<StateDefinition> state;
  final List<ComponentNode> components;
  final Map<String, dynamic> extra;

  PageResponse({
    required this.pageId,
    required this.title,
    this.state = const [],
    this.components = const [],
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'pageId': pageId,
        'title': title,
        'state': state.map((s) => s.toJson()).toList(),
        'components': components.map((c) => c.toJson()).toList(),
        ...extra,
      };
}

/// Abstract Page — the developer's contract for each screen.
abstract class Page {
  String get id;
  String get title;
  CachePolicy get cachePolicy => 'none';
  int get cacheTtl => 60;

  /// Declare which app-state keys this page needs.
  List<String> requiredAppState() => [];

  /// Stage 1: Fetch async/external data.
  Future<dynamic> getInfoData(PageContext context) async => null;

  /// Stage 2: Declare initial page state.
  List<StateDefinition> getState(PageContext context) => [];

  /// Stage 3: Build the widget tree.
  w.Widget render(PageContext context, dynamic infoData);

  /// Stage 4 (post-render, never cached): mutate the response.
  void postRender(PageContext context, PageResponse response) {}
}
