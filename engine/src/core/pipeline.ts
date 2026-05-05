import type { PageContext } from "../types/context";
import { flatten } from "../types/widget";
import type { Page, PageResponse } from "./page";
import type { RouteHooks } from "./flow";
import { ValueResolver } from "./value-resolver";
import type { CacheProvider, ResolvedCacheConfig } from "./cache";
import { buildCacheKey } from "./cache";
import type { MonitorEmitter } from "./monitor";
import type { TimingCollector } from "./timing";
import type { FallbackPolicyResolver } from "./fallback-policy";
import { createStaticPolicyResolver } from "./fallback-policy";
import { filterByCapabilities } from "./capability-filter";

/** Default resolver used when a caller (test or internal) doesn't pass one.
 *  Production code path in engine.ts always passes the engine's configured
 *  resolver, so this default only fires from tests that don't exercise
 *  capability negotiation — those see the pre-25b behavior (no filter). */
const DEFAULT_TEST_RESOLVER: FallbackPolicyResolver = createStaticPolicyResolver({});

// ── Cached payload shape (stages 1-3 combined) ───────────

interface CachedPayload {
  state: import("../types/state").StateDefinition[];
  components: import("../types/node").ComponentNode[];
}

// ── Pipeline: runs the 4-stage Page contract ───────────────

export async function runPipeline(
  page: Page,
  context: PageContext,
  hooks?: RouteHooks,
  cache?: CacheProvider,
  cacheConfig?: ResolvedCacheConfig,
  monitor?: MonitorEmitter,
  timing?: TimingCollector,
  fallbackResolver: FallbackPolicyResolver = DEFAULT_TEST_RESOLVER,
): Promise<PageResponse> {
  const policy = cacheConfig?.policy ?? "none";
  const ttl = cacheConfig?.ttl ?? 60;
  const useCache = cache && policy !== "none";

  // Stage 0 (optional): onEnter hook
  if (hooks?.onEnter) {
    await hooks.onEnter(context);
  }

  // Try unified cache for stages 1-3
  if (useCache) {
    const key = buildCacheKey(page.id, policy, {
      requestInfo: context.requestInfo as unknown as Record<string, unknown>,
      pageState: context.pageState,
      appState: context.appState,
      capsHash: context.requestInfo.clientCapabilities?.hash,
    });

    const cached = await cache.get(key);
    if (cached !== null) {
      if (timing) timing.cacheStatus = "hit";
      monitor?.emit("onCacheHit", {
        timestamp: Date.now(),
        pageId: page.id,
        cacheKey: key,
      });

      const payload: CachedPayload = JSON.parse(cached);

      // Restore pageState from cached state definitions
      for (const def of payload.state) {
        if (def.scope === "page") {
          context.pageState[def.key] = def.initial;
        }
      }

      const response: PageResponse = {
        pageId: page.id,
        title: page.title,
        state: payload.state,
        components: payload.components,
      };

      // Stage 4: postRender always runs fresh
      timing?.mark("postRenderStart");
      page.postRender(context, response);
      timing?.mark("postRenderEnd");
      return response;
    }

    // Cache miss
    if (timing) timing.cacheStatus = "miss";
    monitor?.emit("onCacheMiss", {
      timestamp: Date.now(),
      pageId: page.id,
      cacheKey: key,
    });

    // Run stages 1-3, then cache
    const { state, components } = await runStages1to3(page, context, fallbackResolver, timing);

    const payload: CachedPayload = { state, components };
    await cache.set(key, JSON.stringify(payload), ttl);

    const response: PageResponse = {
      pageId: page.id,
      title: page.title,
      state,
      components,
    };

    // Stage 4: postRender (never cached)
    timing?.mark("postRenderStart");
    page.postRender(context, response);
    timing?.mark("postRenderEnd");
    return response;
  }

  // No cache — run all stages normally
  const { state, components } = await runStages1to3(page, context, fallbackResolver, timing);

  const response: PageResponse = {
    pageId: page.id,
    title: page.title,
    state,
    components,
  };

  // Stage 4: postRender (mutates response — never cached)
  timing?.mark("postRenderStart");
  page.postRender(context, response);
  timing?.mark("postRenderEnd");

  return response;
}

// ── Stages 1-3 ───────────────────────────────────────────

async function runStages1to3(
  page: Page,
  context: PageContext,
  fallbackResolver: FallbackPolicyResolver,
  timing?: TimingCollector,
): Promise<CachedPayload> {
  // Stage 1: getInfoData
  timing?.mark("getInfoStart");
  const infoData = await page.getInfoData(context);
  timing?.mark("getInfoEnd");

  // Stage 2: getState
  timing?.mark("getStateStart");
  const state = page.getState(context);
  for (const def of state) {
    if (def.scope === "page") {
      context.pageState[def.key] = def.initial;
    }
  }
  timing?.mark("getStateEnd");

  // Stage 3: render + resolve
  timing?.mark("renderStart");
  const widgetTree = page.render(context, infoData);
  timing?.mark("renderEnd");

  timing?.mark("flattenStart");
  const flatComponents = flatten(widgetTree, { ctx: context, info: infoData });
  timing?.mark("flattenEnd");

  // Stage 3.5 (Epic 25b slice 2): capability-aware filtering. Inserted
  // between flatten() and prop resolution so the filter operates on the
  // unresolved ComponentNode[] — simpler reasoning (everything is static
  // metadata, no Value objects need evaluating to detect unsupported
  // features) and the filter's output feeds resolve() unchanged.
  timing?.mark("capabilityFilterStart");
  const filterResult = filterByCapabilities(
    flatComponents,
    context.requestInfo.clientCapabilities?.vector,
    fallbackResolver,
  );
  const components = filterResult.components;
  timing?.mark("capabilityFilterEnd");

  const resolver = new ValueResolver({
    pageState: context.pageState,
    appState: context.appState,
    infoData,
    requestInfo: context.requestInfo,
  });

  for (const node of components) {
    node.props = resolver.resolveProps(node.props);
    if (node.actions) {
      node.actions = resolver.resolveProps(node.actions as Record<string, unknown>) as typeof node.actions;
    }
  }

  return { state, components };
}
