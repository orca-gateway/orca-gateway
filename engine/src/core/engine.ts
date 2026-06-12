type BunServer = import("bun").Server<undefined>;
import { brotliCompressSync, constants } from "node:zlib";
import type { PageContext, ActionContext } from "../types/context";
import type { App } from "./app";
import { extractRequestInfo } from "./request-info";
import { runPipeline } from "./pipeline";
import { validateParams, resolveResponseActions } from "./server-action";
import type { CacheProvider } from "./cache";
import { createCacheProvider, generateETag, resolveCacheConfig } from "./cache";
import type { Middleware, MiddlewareContext } from "./middleware";
import type { Monitor } from "./monitor";
import { MonitorEmitter, ConsoleMonitor } from "./monitor";
import { TimingCollector } from "./timing";
import { DebugStore } from "./debug-store";
import type { FallbackPolicyConfig, FallbackPolicyResolver } from "./fallback-policy";
import { createStaticPolicyResolver } from "./fallback-policy";
import type { CapabilityVectorCache } from "./capability-vector-cache";
import { createInMemoryVectorCache, isCapabilityVector } from "./capability-vector-cache";
import type { MinSdkVersionConfig, MinSdkVersionResolver } from "./min-sdk-version";
import { createStaticMinSdkResolver, checkMinSdkVersion, buildUpgradeRequiredBody } from "./min-sdk-version";

// ── Engine Class ───────────────────────────────────────────

export interface EngineConfig {
  port?: number;
  cache?: CacheProvider | boolean;
  cacheSqlitePath?: string;
  /** Register a console monitor that logs all events in dev mode. Default: false. */
  devMonitor?: boolean;
  /** Enable the GET /api/v1/debug/last-requests endpoint. Default: false. */
  enableDebugEndpoint?: boolean;
  /** Maximum request body size in bytes. Default: 1 MB (1048576). */
  maxRequestBodySize?: number;
  /**
   * Honor `X-Forwarded-For` when resolving the client IP. Only enable when
   * the engine runs behind a reverse proxy you control — the header is
   * client-forgeable, and the resolved IP keys rate-limit buckets.
   * Default: false (use the socket peer address).
   */
  trustProxy?: boolean;
}

export class Engine {
  private apps = new Map<string, App>();
  private server?: BunServer;
  private cache?: CacheProvider;
  private readonly monitorEmitter = new MonitorEmitter();
  private debugStore?: DebugStore;
  private enableDebugEndpoint = false;
  private trustProxy = false;

  // Epic 25b slice 2: capability negotiation state.
  private fallbackResolver: FallbackPolicyResolver = createStaticPolicyResolver({});
  private readonly vectorCache: CapabilityVectorCache = createInMemoryVectorCache();
  // Epic 25b slice 3 / task 25b.6: min SDK version gate. Empty default =
  // no minimum configured, every SDK version is allowed.
  private minSdkResolver: MinSdkVersionResolver = createStaticMinSdkResolver({});

  registerApp(app: App): this {
    this.apps.set(app.id, app);
    return this;
  }

  registerMonitor(monitor: Monitor): this {
    this.monitorEmitter.register(monitor);
    return this;
  }

  /**
   * Configure capability-fallback policy for this engine instance (Epic 25b).
   *
   * When the capability filter encounters a feature a client can't render,
   * it consults this policy. The OSS path takes a plain config object
   * (`{default, features}`); cloud slice 3 will offer the same configuration
   * via dashboard UI backed by Postgres, using the same internal
   * `FallbackPolicyResolver` interface. Calling this method replaces any
   * previously configured policy.
   */
  setFallbackPolicy(config: FallbackPolicyConfig): this {
    this.fallbackResolver = createStaticPolicyResolver(config);
    return this;
  }

  /**
   * Configure the minimum SDK version this engine will accept (Epic 25b.6).
   *
   * When a request advertises an SDK version below the configured minimum,
   * the engine returns HTTP 426 Upgrade Required with a body that is a
   * PageResponse containing a single blocking FallbackPrompt — the one
   * response shape guaranteed to work for every SDK version ever shipped.
   *
   * Unversioned clients (no `X-Orca-Sdk-Version` header) bypass the gate,
   * matching how they bypass the capability filter. The default config is
   * an empty string, meaning "no minimum, every SDK is welcome".
   *
   * Cloud slice 4 will replace this static setter with a Postgres-backed
   * resolver that reads `apps.min_sdk_version` + `app_environments.min_sdk_override`
   * per request, satisfying the same MinSdkVersionResolver interface so the
   * engine-side enforcement code doesn't change.
   */
  setMinSdkVersion(config: MinSdkVersionConfig): this {
    this.minSdkResolver = createStaticMinSdkResolver(config);
    return this;
  }

  /** Test/internal access to the capability vector cache. */
  getVectorCache(): CapabilityVectorCache {
    return this.vectorCache;
  }

  getMonitorEmitter(): MonitorEmitter {
    return this.monitorEmitter;
  }

  async start(config: EngineConfig = {}): Promise<BunServer> {
    // Initialize cache
    if (config.cache === false) {
      this.cache = undefined;
    } else if (config.cache && typeof config.cache !== "boolean") {
      this.cache = config.cache;
    } else {
      this.cache = await createCacheProvider(config.cacheSqlitePath);
    }

    // Debug endpoint
    this.enableDebugEndpoint = config.enableDebugEndpoint ?? false;
    this.trustProxy = config.trustProxy ?? false;

    // Dev monitor
    if (config.devMonitor) {
      this.registerMonitor(new ConsoleMonitor());
    }

    const envPort = Number(process.env.PORT) || 8080;
    const port = config.port ?? envPort;

    this.server = Bun.serve({
      port,
      maxRequestBodySize: config.maxRequestBodySize ?? 1024 * 1024, // 1 MB
      fetch: (req) => this.handleRequest(req),
    });

    console.log(`Orca Gateway Engine running on http://localhost:${this.server.port}`);
    return this.server;
  }

  stop(): void {
    this.server?.stop();
  }

  /** Stop the server and close the cache provider (SQLite/Redis). */
  async close(): Promise<void> {
    this.stop();
    if (this.cache && "close" in this.cache && typeof (this.cache as { close: () => void }).close === "function") {
      await (this.cache as { close: () => void | Promise<void> }).close();
    }
  }

  getServer(): BunServer | undefined {
    return this.server;
  }

  getCache(): CacheProvider | undefined {
    return this.cache;
  }

  /**
   * Build RequestInfo with the engine's IP-resolution settings: the socket
   * peer address from Bun, and X-Forwarded-For only when `trustProxy` is on.
   */
  private requestInfo(req: Request, routeParams: Record<string, string>) {
    return extractRequestInfo(req, routeParams, {
      socketAddress: this.server?.requestIP(req)?.address,
      trustProxy: this.trustProxy,
    });
  }

  /**
   * Parse a page request's JSON body exactly once (Request bodies can only
   * be consumed once). Returns the raw object so caller can extract any
   * fields they need — appState for state rehydration, _orcaCapsVector for
   * the 412 retry protocol, etc. Returns null when the body isn't JSON or
   * doesn't parse — callers should treat missing fields as "not sent".
   */
  private async parsePageRequestBody(req: Request): Promise<Record<string, unknown> | null> {
    const contentType = req.headers.get("content-type") ?? "";
    if (!contentType.includes("application/json")) return null;
    try {
      return (await req.json()) as Record<string, unknown>;
    } catch {
      return null;
    }
  }

  private extractAppStateFromBody(
    body: Record<string, unknown> | null,
    allowedKeys: string[],
  ): Record<string, unknown> {
    if (allowedKeys.length === 0 || !body) return {};
    const sent = body.appState;
    if (!sent || typeof sent !== "object") return {};
    const filtered: Record<string, unknown> = {};
    for (const key of allowedKeys) {
      if (key in (sent as Record<string, unknown>)) {
        filtered[key] = (sent as Record<string, unknown>)[key];
      }
    }
    return filtered;
  }

  private async handleAction(req: Request, app: App): Promise<Response> {
    let body: Record<string, unknown>;
    try {
      body = (await req.json()) as Record<string, unknown>;
    } catch {
      return Response.json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const actionId = body.action as string | undefined;
    if (!actionId || typeof actionId !== "string") {
      return Response.json(
        { error: "Missing required field: \"action\"" },
        { status: 400 },
      );
    }

    const actionDef = app.getAction(actionId);
    if (!actionDef) {
      return Response.json(
        { error: `Server action "${actionId}" not found` },
        { status: 404 },
      );
    }

    const params = (body.params ?? {}) as Record<string, unknown>;

    // Schema validation
    if (actionDef.schema) {
      const validationError = validateParams(params, actionDef.schema);
      if (validationError) {
        return Response.json({ error: validationError }, { status: 400 });
      }
    }

    const requestInfo = this.requestInfo(req, {});
    const pageState = (body.pageState ?? {}) as Record<string, unknown>;
    const appState = (body.appState ?? {}) as Record<string, unknown>;

    const context: ActionContext = {
      requestInfo,
      pageState,
      appState,
      actionParams: params,
    };

    // Per-action authorization gate. Note: pageState/appState/params above
    // are echoed verbatim from the client body — only requestInfo carries
    // anything the client can't freely fabricate (and authToken still needs
    // server-side verification by the action author).
    if (actionDef.authorize) {
      try {
        if (!(await actionDef.authorize(context))) {
          return Response.json({ error: "Forbidden" }, { status: 403 });
        }
      } catch (err) {
        console.error(`Error in authorize() for server action "${actionId}":`, err);
        return Response.json({ error: "Forbidden" }, { status: 403 });
      }
    }

    const actionStart = performance.now();
    try {
      const responseActions = await actionDef.execute(context);
      const wireActions = resolveResponseActions(responseActions, context);
      this.monitorEmitter.emit("onServerActionCall", {
        timestamp: Date.now(),
        actionId,
        context,
        durationMs: performance.now() - actionStart,
        success: true,
      });
      return Response.json({ actions: wireActions });
    } catch (err) {
      console.error(`Error executing server action "${actionId}":`, err);
      this.monitorEmitter.emit("onServerActionCall", {
        timestamp: Date.now(),
        actionId,
        context,
        durationMs: performance.now() - actionStart,
        success: false,
        error: err,
      });
      this.monitorEmitter.emit("onError", {
        timestamp: Date.now(),
        error: err,
        stage: "serverAction",
      });
      return Response.json(
        {
          error: "Server action failed",
          actions: [
            {
              type: "showSnackbar",
              message: err instanceof Error ? err.message : "An error occurred",
            },
          ],
        },
        { status: 500 },
      );
    }
  }

  private async handleHook(req: Request, app: App): Promise<Response> {
    let body: Record<string, unknown>;
    try {
      body = (await req.json()) as Record<string, unknown>;
    } catch {
      return Response.json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const hookType = body.type as string | undefined;
    const path = body.path as string | undefined;

    if (!hookType || !path) {
      return Response.json(
        { error: "Missing required fields: \"type\" and \"path\"" },
        { status: 400 },
      );
    }

    if (hookType !== "enter" && hookType !== "exit") {
      return Response.json(
        { error: "Hook type must be \"enter\" or \"exit\"" },
        { status: 400 },
      );
    }

    const routeMatch = app.resolve(path);
    if (!routeMatch) {
      return Response.json({ ok: true }); // No route — silently succeed
    }

    const hook = hookType === "enter"
      ? routeMatch.hooks?.onEnter
      : routeMatch.hooks?.onExit;

    if (!hook) {
      return Response.json({ ok: true });
    }

    try {
      const requestInfo = this.requestInfo(req, routeMatch.params);
      const appState = (body.appState ?? {}) as Record<string, unknown>;
      const context: PageContext = {
        requestInfo,
        pageId: routeMatch.page.id,
        routePath: `/${path}`,
        routeParams: routeMatch.params,
        pageState: {},
        appState,
      };
      await hook(context);
      return Response.json({ ok: true });
    } catch (err) {
      console.error(`Error executing ${hookType} hook for "/${path}":`, err);
      this.monitorEmitter.emit("onError", {
        timestamp: Date.now(),
        error: err,
        path: `/${path}`,
        stage: "hook",
      });
      return Response.json({ error: "Hook execution failed" }, { status: 500 });
    }
  }

  private async handleSession(req: Request): Promise<Response> {
    let body: Record<string, unknown>;
    try {
      body = (await req.json()) as Record<string, unknown>;
    } catch {
      return Response.json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const type = body.type as string | undefined;
    if (type !== "start" && type !== "end") {
      return Response.json(
        { error: "Session type must be \"start\" or \"end\"" },
        { status: 400 },
      );
    }

    const deviceId = (body.deviceId as string) ?? undefined;
    const reqInfo = this.requestInfo(req, {});

    if (type === "start") {
      this.monitorEmitter.emit("onSessionStart", { timestamp: Date.now(), deviceId, requestInfo: reqInfo });
    } else {
      this.monitorEmitter.emit("onSessionEnd", { timestamp: Date.now(), deviceId, requestInfo: reqInfo });
    }

    return Response.json({ ok: true });
  }

  private async handleOfflineSessions(req: Request): Promise<Response> {
    let body: Record<string, unknown>;
    try {
      body = (await req.json()) as Record<string, unknown>;
    } catch {
      return Response.json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const deviceId = body.deviceId as string | undefined;
    const sessions = body.sessions as { type: string; timestamp: number }[] | undefined;

    if (!deviceId || !Array.isArray(sessions)) {
      return Response.json(
        { error: "Missing required fields: \"deviceId\" and \"sessions\"" },
        { status: 400 },
      );
    }

    const validSessions = sessions.filter(
      (s) => (s.type === "start" || s.type === "end") && typeof s.timestamp === "number",
    ) as { type: "start" | "end"; timestamp: number }[];

    if (validSessions.length > 0) {
      const reqInfo = this.requestInfo(req, {});
      this.monitorEmitter.emit("onRegisterOfflineSessions", {
        timestamp: Date.now(),
        deviceId,
        sessions: validSessions,
        requestInfo: reqInfo,
      });
    }

    return Response.json({ ok: true, registered: validSessions.length });
  }

  /** Run onRequest middlewares. Returns a Response to short-circuit, or void to continue. */
  private async runOnRequest(
    middlewares: Middleware[],
    ctx: MiddlewareContext,
  ): Promise<Response | void> {
    for (const mw of middlewares) {
      if (!mw.onRequest) continue;
      const result = await mw.onRequest(ctx);
      if (result) {
        return Response.json(result.body ?? null, {
          status: result.status,
          headers: result.headers,
        });
      }
    }
  }

  /** Run onResponse middlewares in reverse order. */
  private async runOnResponse(
    middlewares: Middleware[],
    ctx: MiddlewareContext,
    response: Response,
  ): Promise<Response> {
    for (let i = middlewares.length - 1; i >= 0; i--) {
      const mw = middlewares[i]!;
      if (!mw.onResponse) continue;
      response = await mw.onResponse(ctx, response);
    }
    return response;
  }

  private async handleRequest(req: Request): Promise<Response> {
    const url = new URL(req.url);
    const path = url.pathname;

    // Health check
    if (path === "/health") {
      return Response.json({ status: "ok", name: "Orca Gateway Engine" });
    }

    // Debug route: GET /api/v1/debug/last-requests
    if (path === "/api/v1/debug/last-requests" && req.method === "GET") {
      if (!this.enableDebugEndpoint) {
        return Response.json({ error: "Not Found" }, { status: 404 });
      }
      return Response.json((this.debugStore ?? new DebugStore()).getAll());
    }

    // API routes: /api/v1/app/:appId/...
    const apiMatch = path.match(/^\/api\/v1\/app\/([^/]+)\/(.+)$/);
    if (!apiMatch) {
      return Response.json({ error: "Not Found" }, { status: 404 });
    }

    const appId = apiMatch[1]!;
    const rest = apiMatch[2]!;
    const app = this.apps.get(appId);

    if (!app) {
      return Response.json({ error: `App "${appId}" not found` }, { status: 404 });
    }

    // Build middleware context
    const requestInfo = this.requestInfo(req, {});
    const middlewareCtx: MiddlewareContext = {
      request: req,
      requestInfo,
      appId,
      path: `/${rest}`,
      configuration: app.configuration,
    };

    // Check if debug timing is requested. The `x-orca-debug` header alone is
    // not enough — internal stage timings only leave the server when the
    // operator opted in via `enableDebugEndpoint`.
    const isDebug = this.enableDebugEndpoint && req.headers.get("x-orca-debug") === "true";

    // Run onRequest middleware chain
    const middlewares = app.getMiddlewares();

    // Create timing collector for page requests when debug is enabled
    const isPageRequest = rest.startsWith("page/");
    const timing = isDebug && isPageRequest ? new TimingCollector() : undefined;
    if (timing) {
      timing.mark("requestReceived");
      timing.mark("middlewareStart");
    }

    try {
      const earlyResponse = await this.runOnRequest(middlewares, middlewareCtx);
      if (timing) timing.mark("middlewareEnd");
      if (earlyResponse) {
        return this.runOnResponse(middlewares, middlewareCtx, earlyResponse);
      }
    } catch (err) {
      if (timing) timing.mark("middlewareEnd");
      this.monitorEmitter.emit("onError", {
        timestamp: Date.now(),
        error: err,
        path: `/${rest}`,
        stage: "middleware",
      });
      if (app.globalErrorHandler) {
        app.globalErrorHandler(err, middlewareCtx);
      }
      return Response.json({ error: "Internal Server Error" }, { status: 500 });
    }

    // Route to handler
    let response: Response = Response.json({ error: "Not Found" }, { status: 404 });

    // GET /api/v1/app/:appId/config
    if (rest === "config") {
      response = Response.json(await app.getNavConfig(requestInfo));
    }
    // GET /api/v1/app/:appId/version
    else if (rest === "version" && req.method === "GET") {
      response = Response.json(app.getVersionInfo());
    }
    // POST /api/v1/app/:appId/action
    else if (rest === "action" && req.method === "POST") {
      response = await this.handleAction(req, app);
    }
    // POST /api/v1/app/:appId/hook
    else if (rest === "hook" && req.method === "POST") {
      response = await this.handleHook(req, app);
    }
    // POST /api/v1/app/:appId/session
    else if (rest === "session" && req.method === "POST") {
      response = await this.handleSession(req);
    }
    // POST /api/v1/app/:appId/session/offline
    else if (rest === "session/offline" && req.method === "POST") {
      response = await this.handleOfflineSessions(req);
    }
    // [GET/POST] /api/v1/app/:appId/page/:path*
    else {
      const pageMatch = rest.match(/^page\/(.+)$/);
      if (!pageMatch) {
        response = Response.json({ error: "Not Found" }, { status: 404 });
      } else {
        const pagePath = pageMatch[1]!;
        const routeMatch = app.resolve(pagePath);

        if (!routeMatch) {
          response = Response.json(
            { error: `No page found for path "/${pagePath}"` },
            { status: 404 },
          );
        } else {
          const flowName = routeMatch.flowName ?? "unknown";
          const flowStart = performance.now();
          this.monitorEmitter.emit("onFlowStart", {
            timestamp: Date.now(),
            flowName,
            path: `/${pagePath}`,
          });

          pageBlock: try {
            const pageRequestInfo = this.requestInfo(req, routeMatch.params);

            // Parse the request body ONCE — Bun Request bodies can only be
            // consumed once. Downstream extractors read fields off the
            // already-parsed object rather than re-reading the request.
            const parsedBody = await this.parsePageRequestBody(req);

            // Epic 25b slice 2: capability-vector resolution + 412 protocol.
            // If the client advertised a caps hash, try the engine's vector
            // cache. On miss, look for the full vector in the body (retry
            // path). On total miss, respond with 412 so the client knows to
            // retry with the full vector. The 412 assignment sets `response`
            // and falls through to `runOnResponse` below so middlewares
            // (CORS, logging) still apply their response passes.
            let capsMiss = false;
            if (pageRequestInfo.clientCapabilities?.hash) {
              const hash = pageRequestInfo.clientCapabilities.hash;
              let vector = this.vectorCache.get(hash);
              if (!vector && parsedBody && parsedBody._orcaCapsVector) {
                const candidate = parsedBody._orcaCapsVector;
                if (isCapabilityVector(candidate)) {
                  // Verify the client's declared hash actually matches the
                  // vector they sent. A mismatch means the client is broken
                  // or malicious — refuse to poison the cache.
                  const computed = this.vectorCache.computeHash(candidate);
                  if (computed === hash) {
                    this.vectorCache.put(hash, candidate);
                    vector = candidate;
                  }
                }
              }
              if (!vector) {
                response = Response.json(
                  { error: "caps_vector_unknown", hash },
                  { status: 412 },
                );
                capsMiss = true;
              } else {
                pageRequestInfo.clientCapabilities.vector = vector;
              }
            }

            if (capsMiss) {
              // Skip the pipeline — the 412 response is ready. Break out of
              // `pageBlock` so onFlowEnd + runOnResponse still fire and
              // middleware-level response headers (CORS, etc.) still apply.
              break pageBlock;
            }

            // Epic 25b.6: minimum SDK version gate. If the client advertised
            // a version below this app's minimum (per-env override or
            // app-level default), short-circuit the pipeline with HTTP 426
            // Upgrade Required. The 426 body is a full PageResponse envelope
            // containing a single blocking FallbackPrompt so a
            // forward-compatible SDK can render it as the upgrade screen
            // immediately, and legacy SDKs still get a structured error
            // payload via OrcaClientException.
            const envHeader = req.headers.get("x-orca-env") ?? undefined;
            const effectiveMin = this.minSdkResolver.minFor(envHeader);
            const enforced = checkMinSdkVersion(
              pageRequestInfo.clientCapabilities?.sdkVersion,
              effectiveMin,
            );
            if (enforced !== null) {
              const body = buildUpgradeRequiredBody(
                routeMatch.page.id,
                pageRequestInfo.clientCapabilities?.sdkVersion,
                enforced,
              );
              response = Response.json(body, { status: 426 });
              break pageBlock;
            }

            // Read appState from the already-parsed body, filtered to
            // declared keys.
            const allowedKeys = routeMatch.page.requiredAppState();
            const appState = this.extractAppStateFromBody(parsedBody, allowedKeys);

            const context: PageContext = {
              requestInfo: pageRequestInfo,
              pageId: routeMatch.page.id,
              routePath: `/${pagePath}`,
              routeParams: routeMatch.params,
              pageState: {},
              appState,
            };

            // Merge flow-level + page-level cache policy
            const cacheConfig = resolveCacheConfig(
              routeMatch.flowCachePolicy,
              routeMatch.flowCacheTtl,
              routeMatch.page.cachePolicy,
              routeMatch.page.cacheTtl,
            );

            const renderStart = performance.now();
            const pageResponse = await runPipeline(routeMatch.page, context, routeMatch.hooks, this.cache, cacheConfig, this.monitorEmitter, timing, this.fallbackResolver);
            const renderDuration = performance.now() - renderStart;

            this.monitorEmitter.emit("onPageRender", {
              timestamp: Date.now(),
              pageId: routeMatch.page.id,
              path: `/${pagePath}`,
              context,
              response: pageResponse,
              durationMs: renderDuration,
            });

            // Serialize response
            const body = JSON.stringify(pageResponse);

            // Collect timing data
            if (timing) {
              timing.responseSizeBytes = body.length;
              timing.componentCount = pageResponse.components.length;
              timing.mark("responseSent");
            }

            // ETag support
            const etag = generateETag(body);
            const ifNoneMatch = req.headers.get("if-none-match");

            const headers: Record<string, string> = {};

            // Add timing header if debug is enabled (`timing` only exists
            // when enableDebugEndpoint is on — see `isDebug` above).
            if (timing) {
              const timingData = timing.toTimingData(`/${pagePath}`, req.method);
              if (!this.debugStore) this.debugStore = new DebugStore();
              this.debugStore.push(timingData);
              headers["X-Orca-Timing"] = JSON.stringify(timingData);
            }

            if (ifNoneMatch === etag) {
              response = new Response(null, {
                status: 304,
                headers: { ETag: etag, ...headers },
              });
            } else {
              const acceptsBr = req.headers.get("accept-encoding")?.includes("br") ?? false;
              let responseBody: string | Buffer = body;
              const resHeaders: Record<string, string> = {
                "Content-Type": "application/json",
                Vary: "Accept-Encoding",
                ETag: etag,
                ...headers,
              };
              if (acceptsBr) {
                responseBody = brotliCompressSync(Buffer.from(body), {
                  params: { [constants.BROTLI_PARAM_QUALITY]: 4 },
                });
                resHeaders["Content-Encoding"] = "br";
              }
              response = new Response(responseBody, {
                status: 200,
                headers: resHeaders,
              });
            }
          } catch (err) {
            console.error(`Error rendering page "/${pagePath}":`, err);
            this.monitorEmitter.emit("onError", {
              timestamp: Date.now(),
              error: err,
              pageId: routeMatch.page.id,
              path: `/${pagePath}`,
              stage: "pipeline",
            });
            if (app.globalErrorHandler) {
              app.globalErrorHandler(err, middlewareCtx);
            }
            response = Response.json(
              { error: "Internal Server Error" },
              { status: 500 },
            );
          }

          this.monitorEmitter.emit("onFlowEnd", {
            timestamp: Date.now(),
            flowName,
            path: `/${pagePath}`,
            durationMs: performance.now() - flowStart,
          });
        }
      }
    }

    // Run onResponse middleware chain
    try {
      return await this.runOnResponse(middlewares, middlewareCtx, response);
    } catch (err) {
      this.monitorEmitter.emit("onError", {
        timestamp: Date.now(),
        error: err,
        path: `/${rest}`,
        stage: "middleware",
      });
      if (app.globalErrorHandler) {
        app.globalErrorHandler(err, middlewareCtx);
      }
      return Response.json({ error: "Internal Server Error" }, { status: 500 });
    }
  }
}
