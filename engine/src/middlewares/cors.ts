import type { Middleware } from "../core/middleware";

export interface CorsConfig {
  /** Allowed origins. Use ["*"] for any origin. */
  origins: string[];
  /** Allowed HTTP methods. Defaults to common methods. */
  methods?: string[];
  /** Allowed headers. Defaults to common headers. */
  allowedHeaders?: string[];
  /** Headers exposed to the browser. */
  exposedHeaders?: string[];
  /** Whether to allow credentials. Defaults to false. */
  credentials?: boolean;
  /** Preflight max age in seconds. Defaults to 86400 (24h). */
  maxAge?: number;
}

export function corsMiddleware(config: CorsConfig): Middleware {
  const methods = config.methods ?? ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"];
  const allowedHeaders = config.allowedHeaders ?? ["Content-Type", "Authorization", "X-API-Key"];
  const maxAge = config.maxAge ?? 86400;
  const originSet = new Set(config.origins);
  const allowAny = originSet.has("*");

  function getOrigin(requestOrigin: string | null): string | null {
    if (!requestOrigin) return null;
    if (allowAny) return "*";
    if (originSet.has(requestOrigin)) return requestOrigin;
    return null;
  }

  return {
    name: "cors",
    onRequest(ctx) {
      const origin = ctx.request.headers.get("origin");

      // Handle preflight OPTIONS
      if (ctx.request.method === "OPTIONS") {
        const allowedOrigin = getOrigin(origin);
        const headers: Record<string, string> = {
          "Access-Control-Allow-Methods": methods.join(", "),
          "Access-Control-Allow-Headers": allowedHeaders.join(", "),
          "Access-Control-Max-Age": String(maxAge),
        };
        if (allowedOrigin) {
          headers["Access-Control-Allow-Origin"] = allowedOrigin;
        }
        if (config.credentials) {
          headers["Access-Control-Allow-Credentials"] = "true";
        }
        return { status: 204, headers };
      }
    },

    onResponse(ctx, response) {
      const origin = ctx.request.headers.get("origin");
      const allowedOrigin = getOrigin(origin);

      if (allowedOrigin) {
        const newHeaders = new Headers(response.headers);
        newHeaders.set("Access-Control-Allow-Origin", allowedOrigin);
        if (config.credentials) {
          newHeaders.set("Access-Control-Allow-Credentials", "true");
        }
        if (config.exposedHeaders?.length) {
          newHeaders.set("Access-Control-Expose-Headers", config.exposedHeaders.join(", "));
        }
        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: newHeaders,
        });
      }
      return response;
    },
  };
}
