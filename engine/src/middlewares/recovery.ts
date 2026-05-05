import type { Middleware, MiddlewareContext } from "../core/middleware";

export interface RecoveryConfig {
  /** Optional handler called when an error is caught. */
  onError?: (error: unknown, ctx: MiddlewareContext) => void;
}

/**
 * Recovery middleware placeholder for custom error handling integration.
 *
 * Currently a pass-through: the Engine's own try/catch already handles
 * unhandled errors with safe 500 responses. This middleware exists as a
 * registration point for the `onError` callback, which allows users to
 * plug in custom error reporting (e.g. Sentry, logging services).
 *
 * Register as the FIRST middleware so its onResponse runs last.
 */
export function recoveryMiddleware(config: RecoveryConfig = {}): Middleware {
  return {
    name: "recovery",
    onRequest(ctx) {
      // No-op on request — the Engine's try/catch handles onRequest errors.
      // This middleware's value is in its onError callback integration.
    },
    onResponse(ctx, response) {
      // Pass through — if this throws, Engine's outer catch handles it.
      return response;
    },
  };
}
