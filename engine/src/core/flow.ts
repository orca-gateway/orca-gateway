import type { Page } from "./page";
import type { PageContext } from "../types/context";
import type { CachePolicy } from "./cache";

// ── Route Hooks ───────────────────────────────────────────

export interface RouteHooks {
  onEnter?: (context: PageContext) => Promise<void> | void;
  onExit?: (context: PageContext) => Promise<void> | void;
}

// ── Route Transition ──────────────────────────────────────

export interface RouteTransition {
  type: "slide" | "fade" | "scale" | "slideUp" | "slideRight" | "none";
  duration?: number;
  curve?: string;
}

// ── Route Redirect ────────────────────────────────────────

export interface RedirectRule {
  when: string;
  equals: unknown;
  to: string;
}

// ── Route Definition ───────────────────────────────────────

export interface RouteDefinition {
  path: string;
  page?: Page;
  children?: RouteDefinition[];
  hooks?: RouteHooks;
  redirect?: RedirectRule;
  transition?: RouteTransition;
  /** When true, this route always fetches fresh even in a static flow. */
  isDynamic?: boolean;
}

// ── Route Match Result ─────────────────────────────────────

export interface RouteMatch {
  page: Page;
  params: Record<string, string>;
  fullPath: string;
  hooks?: RouteHooks;
  flowCachePolicy?: CachePolicy;
  flowCacheTtl?: number;
  flowName?: string;
}

// ── Route Info (for config endpoint) ───────────────────────

export interface RouteInfo {
  path: string;
  requiredAppState: string[];
  children?: RouteInfo[];
  redirect?: RedirectRule;
  transition?: RouteTransition;
  isDynamic?: boolean;
}

// ── Flow Class ─────────────────────────────────────────────

export interface FlowConfig {
  name: string;
  routes: RouteDefinition[];
  cachePolicy?: CachePolicy;
  cacheTtl?: number;
  isStatic?: boolean;
  version?: number;
}

export class Flow {
  readonly name: string;
  readonly cachePolicy?: CachePolicy;
  readonly cacheTtl?: number;
  readonly isStatic: boolean;
  readonly version: number;
  private routes: RouteDefinition[];

  private constructor(config: FlowConfig) {
    this.name = config.name;
    this.routes = config.routes;
    this.cachePolicy = config.cachePolicy;
    this.cacheTtl = config.cacheTtl;
    this.isStatic = config.isStatic ?? false;
    this.version = config.version ?? 0;
  }

  static create(config: FlowConfig): Flow {
    return new Flow(config);
  }

  /** Resolve a path like "/product/42" against this flow's routes. */
  resolve(path: string): RouteMatch | undefined {
    const segments = splitPath(path);
    const match = matchRoutes(this.routes, segments, {}, "");
    if (match) {
      match.flowCachePolicy = this.cachePolicy;
      match.flowCacheTtl = this.cacheTtl;
      match.flowName = this.name;
    }
    return match;
  }

  /** Get all route info in this flow (for config endpoint). */
  getRouteInfo(): RouteInfo[] {
    return collectRouteInfo(this.routes, "");
  }

  /** Collect all leaf pages in this flow (for static pre-rendering). */
  getPages(): { path: string; page: Page }[] {
    return collectPages(this.routes, "");
  }
}

// ── Route Matching ─────────────────────────────────────────

function splitPath(path: string): string[] {
  return path.split("/").filter(Boolean);
}

function matchRoutes(
  routes: RouteDefinition[],
  segments: string[],
  params: Record<string, string>,
  prefix: string,
): RouteMatch | undefined {
  for (const route of routes) {
    const routeSegments = splitPath(route.path);
    const result = matchSegments(routeSegments, segments, { ...params });

    if (!result) continue;

    const matchedPath = prefix ? `${prefix}/${route.path}` : route.path;
    const remaining = segments.slice(routeSegments.length);

    // Exact match — use this route's page
    if (remaining.length === 0 && route.page) {
      return {
        page: route.page,
        params: result.params,
        fullPath: matchedPath,
        hooks: route.hooks,
      };
    }

    // Has remaining segments — try nested children
    if (remaining.length > 0 && route.children) {
      const childMatch = matchRoutes(
        route.children,
        remaining,
        result.params,
        matchedPath,
      );
      if (childMatch) return childMatch;
    }
  }

  return undefined;
}

function matchSegments(
  routeSegments: string[],
  pathSegments: string[],
  params: Record<string, string>,
): { params: Record<string, string> } | undefined {
  if (routeSegments.length > pathSegments.length) return undefined;

  for (let i = 0; i < routeSegments.length; i++) {
    const routeSeg = routeSegments[i];
    const pathSeg = pathSegments[i];

    if (routeSeg.startsWith(":")) {
      // Dynamic parameter
      params[routeSeg.slice(1)] = pathSeg;
    } else if (routeSeg !== pathSeg) {
      return undefined;
    }
  }

  return { params };
}

function collectPages(
  routes: RouteDefinition[],
  prefix: string,
): { path: string; page: Page }[] {
  const result: { path: string; page: Page }[] = [];
  for (const route of routes) {
    const full = prefix ? `${prefix}/${route.path}` : route.path;
    // Skip dynamic routes — they always fetch fresh, even in static flows
    if (route.page && !route.isDynamic) {
      result.push({ path: full, page: route.page });
    }
    if (route.children) {
      result.push(...collectPages(route.children, full));
    }
  }
  return result;
}

function collectRouteInfo(routes: RouteDefinition[], prefix: string): RouteInfo[] {
  const info: RouteInfo[] = [];
  for (const route of routes) {
    const full = prefix ? `${prefix}/${route.path}` : route.path;
    const entry: RouteInfo = {
      path: full,
      requiredAppState: route.page?.requiredAppState() ?? [],
    };
    if (route.isDynamic) {
      entry.isDynamic = true;
    }
    if (route.redirect) {
      entry.redirect = route.redirect;
    }
    if (route.transition) {
      entry.transition = route.transition;
    }
    if (route.children) {
      entry.children = collectRouteInfo(route.children, full);
    }
    info.push(entry);
  }
  return info;
}
