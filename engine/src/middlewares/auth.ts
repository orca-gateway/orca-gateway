import type { Middleware } from "../core/middleware";

export interface AuthMiddlewareConfig {
  /** Valid API keys. Requests with missing or invalid keys get 401. */
  apiKeys: string[];
  /** Header name to read the API key from. Defaults to "authorization". Falls back to "x-api-key" if the primary header is absent. */
  header?: string;
  /** Paths to exclude from auth (e.g. "/config"). */
  exclude?: string[];
}

export function authMiddleware(config: AuthMiddlewareConfig): Middleware {
  const header = config.header ?? "authorization";
  const keySet = new Set(config.apiKeys);
  const exclude = new Set(config.exclude ?? []);

  return {
    name: "auth",
    onRequest(ctx) {
      if (exclude.has(ctx.path)) return;

      // Support both "Authorization: Bearer <key>" and legacy "x-api-key: <key>".
      const raw = ctx.request.headers.get(header)
        ?? ctx.request.headers.get("x-api-key");
      const key = raw?.startsWith("Bearer ") ? raw.slice(7) : raw;
      if (!key) {
        return { status: 401, body: { error: "Missing API key" } };
      }
      if (!keySet.has(key)) {
        return { status: 401, body: { error: "Invalid API key" } };
      }
    },
  };
}
