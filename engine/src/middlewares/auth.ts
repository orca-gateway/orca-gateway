import { createHash, timingSafeEqual } from "node:crypto";
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
  // Compare SHA-256 digests with timingSafeEqual instead of raw string
  // equality — string/Set comparison short-circuits on the first differing
  // byte, leaking key prefixes through response timing.
  const sha256 = (s: string) => createHash("sha256").update(s).digest();
  const keyDigests = config.apiKeys.map(sha256);
  const isValidKey = (candidate: string): boolean => {
    const digest = sha256(candidate);
    // Check every key (no early exit) so timing doesn't depend on which
    // key matched.
    let valid = false;
    for (const kd of keyDigests) {
      if (timingSafeEqual(digest, kd)) valid = true;
    }
    return valid;
  };
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
      if (!isValidKey(key)) {
        return { status: 401, body: { error: "Invalid API key" } };
      }
    },
  };
}
