import '../types/context.dart';
import '../types/widget.dart' show flatten;
import 'cache.dart';
import 'capability_filter.dart';
import 'fallback_policy.dart';
import 'flow.dart';
import 'monitor.dart';
import 'page.dart';
import 'value_resolver.dart';

/// Run the 4-stage page pipeline.
Future<PageResponse> runPipeline(
  Page page,
  PageContext context, {
  RouteHooks? hooks,
  CacheProvider? cache,
  ResolvedCacheConfig? cacheConfig,
  MonitorEmitter? monitor,
  FallbackPolicyResolver? fallbackResolver,
  CapabilityVector? clientCapabilities,
}) async {
  // Stage 0: onEnter hook
  if (hooks?.onEnter != null) {
    await hooks!.onEnter!(context);
  }

  // Stage 1: getInfoData
  final infoData = await page.getInfoData(context);

  // Stage 2: getState
  final state = page.getState(context);

  // Stage 3: render + flatten + resolve
  final widgetTree = page.render(context, infoData);
  var components = flatten(widgetTree);

  // Capability filtering
  if (clientCapabilities != null && fallbackResolver != null) {
    final filtered =
        filterByCapabilities(components, clientCapabilities, fallbackResolver);
    components = filtered.components;
  }

  // Value resolution
  final resolverCtx = ValueResolverContext(
    pageState: context.pageState,
    appState: context.appState,
    infoData: infoData,
    requestInfo: context.requestInfo.toResolverMap(),
  );
  final resolver = ValueResolver(resolverCtx);
  components = components.map((node) {
    final resolvedProps = resolver.resolveProps(node.props);
    return node.copyWith(props: resolvedProps);
  }).toList();

  final response = PageResponse(
    pageId: page.id,
    title: page.title,
    state: state,
    components: components,
  );

  // Stage 4: postRender (never cached)
  page.postRender(context, response);

  return response;
}
