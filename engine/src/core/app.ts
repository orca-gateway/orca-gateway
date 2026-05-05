import type { Flow, RouteMatch, RouteInfo } from "./flow";
import type { ServerActionDefinition } from "./server-action";
import type { RequestInfo, PageContext } from "../types/context";
import type { Widget } from "../types/widget";
import { flatten } from "../types/widget";
import type { ComponentNode } from "../types/node";
import type { Middleware, MiddlewareContext } from "./middleware";
import type { PageResponse } from "./page";
import { runPipeline } from "./pipeline";

// ── Navigation Config ─────────────────────────────────────

export interface TabDefinition {
  id: string;
  label: string;
  icon: string;
  initialRoute: string;
}

export interface DrawerItemDefinition {
  id: string;
  label: string;
  icon?: string;
  route: string;
}

export type ShellWidget = Widget | ((requestInfo: RequestInfo) => Widget);

export interface NavigationConfig {
  initialRoute: string;
  tabs?: TabDefinition[];
  drawerItems?: DrawerItemDefinition[];
  initialAppState?: Record<string, unknown>;
  tabBar?: ShellWidget;
  drawer?: ShellWidget;
}

// ── App Class ──────────────────────────────────────────────

export type GlobalErrorHandler = (error: unknown, context: MiddlewareContext) => void;

export interface AppConfig {
  id: string;
  name: string;
  flows: Flow[];
  actions?: ServerActionDefinition[];
  navigation?: NavigationConfig;
  configuration?: Record<string, unknown>;
  globalErrorHandler?: GlobalErrorHandler;
  forceUpdate?: boolean;
}

export interface AppNavConfig {
  appId: string;
  appName: string;
  initialRoute: string;
  tabs?: TabDefinition[];
  drawerItems?: DrawerItemDefinition[];
  tabBarComponents?: ComponentNode[];
  drawerComponents?: ComponentNode[];
  flows: {
    name: string;
    routes: RouteInfo[];
    version?: number;
    isStatic?: boolean;
    pages?: Record<string, PageResponse>;
  }[];
}

export class App {
  readonly id: string;
  readonly name: string;
  readonly configuration: Record<string, unknown>;
  readonly forceUpdate: boolean;
  private flows: Flow[];
  private actions = new Map<string, ServerActionDefinition>();
  private middlewares: Middleware[] = [];
  private navigation?: NavigationConfig;
  private _globalErrorHandler?: GlobalErrorHandler;

  private constructor(config: AppConfig) {
    this.id = config.id;
    this.name = config.name;
    this.flows = config.flows;
    this.navigation = config.navigation;
    this.configuration = config.configuration ?? {};
    this.forceUpdate = config.forceUpdate ?? false;
    this._globalErrorHandler = config.globalErrorHandler;
    for (const action of config.actions ?? []) {
      this.actions.set(action.id, action);
    }
  }

  static create(config: AppConfig): App {
    return new App(config);
  }

  /** Register a middleware to the app's pipeline. Executes in registration order. */
  registerMiddleware(middleware: Middleware): this {
    this.middlewares.push(middleware);
    return this;
  }

  /** Get all registered middlewares. */
  getMiddlewares(): Middleware[] {
    return this.middlewares;
  }

  /** Get the global error handler, if registered. */
  get globalErrorHandler(): GlobalErrorHandler | undefined {
    return this._globalErrorHandler;
  }

  /** Resolve a page path across all flows. */
  resolve(path: string): RouteMatch | undefined {
    for (const flow of this.flows) {
      const match = flow.resolve(path);
      if (match) return match;
    }
    return undefined;
  }

  /** Look up a registered server action by id. */
  getAction(id: string): ServerActionDefinition | undefined {
    return this.actions.get(id);
  }

  /** Resolve a ShellWidget (Widget or function) to a Widget. */
  private resolveShell(shell: ShellWidget, requestInfo?: RequestInfo): Widget {
    return typeof shell === "function" ? shell(requestInfo!) : shell;
  }

  /** Get version info for all flows. */
  getVersionInfo(): { flows: Record<string, number>; forceUpdate?: boolean } {
    const flows: Record<string, number> = {};
    for (const f of this.flows) {
      flows[f.name] = f.version;
    }
    return {
      flows,
      ...(this.forceUpdate && { forceUpdate: true }),
    };
  }

  // Cached pre-rendered static pages, keyed by flow name.
  // Invalidated when flow version changes.
  private staticPagesCache = new Map<string, { version: number; pages: Record<string, PageResponse> }>();

  /** Pre-render a single static flow's pages (with cache). */
  private async preRenderStaticFlow(flow: Flow): Promise<Record<string, PageResponse>> {
    const cached = this.staticPagesCache.get(flow.name);
    if (cached && cached.version === flow.version) {
      return cached.pages;
    }

    // Render all pages in parallel
    const pageEntries = flow.getPages();
    const rendered = await Promise.all(
      pageEntries.map(async ({ path, page }) => {
        const context: PageContext = {
          requestInfo: {} as RequestInfo,
          pageId: page.id,
          routePath: `/${path}`,
          routeParams: {},
          pageState: {},
          appState: {},
        };
        return { path, response: await runPipeline(page, context) };
      }),
    );

    const pages: Record<string, PageResponse> = {};
    for (const { path, response } of rendered) {
      pages[path] = response;
    }

    this.staticPagesCache.set(flow.name, { version: flow.version, pages });
    return pages;
  }

  /** Get navigation config (route structure). */
  async getNavConfig(requestInfo?: RequestInfo): Promise<AppNavConfig> {
    // Build all flows in parallel
    const flowsData = await Promise.all(
      this.flows.map(async (f) => {
        const entry: AppNavConfig["flows"][number] = {
          name: f.name,
          routes: f.getRouteInfo(),
        };

        if (f.version !== 0) entry.version = f.version;

        if (f.isStatic) {
          entry.isStatic = true;
          entry.pages = await this.preRenderStaticFlow(f);
        }

        return entry;
      }),
    );

    return {
      appId: this.id,
      appName: this.name,
      initialRoute: this.navigation?.initialRoute ?? "/",
      ...(this.navigation?.tabs && { tabs: this.navigation.tabs }),
      ...(this.navigation?.drawerItems && { drawerItems: this.navigation.drawerItems }),
      ...(this.navigation?.initialAppState && { initialAppState: this.navigation.initialAppState }),
      ...(this.navigation?.tabBar && { tabBarComponents: flatten(this.resolveShell(this.navigation.tabBar, requestInfo)) }),
      ...(this.navigation?.drawer && { drawerComponents: flatten(this.resolveShell(this.navigation.drawer, requestInfo)) }),
      flows: flowsData,
    };
  }
}
