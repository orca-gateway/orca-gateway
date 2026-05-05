import type { Middleware } from "../core/middleware";

let requestCounter = 0;

function generateRequestId(): string {
  requestCounter = (requestCounter + 1) % Number.MAX_SAFE_INTEGER;
  return `${Date.now()}-${requestCounter.toString(36)}`;
}

export function loggingMiddleware(): Middleware {
  const pending = new WeakMap<Request, { requestId: string; start: number }>();

  return {
    name: "logging",
    onRequest(ctx) {
      const requestId = generateRequestId();
      pending.set(ctx.request, { requestId, start: performance.now() });

      console.log(
        JSON.stringify({
          level: "info",
          event: "request_start",
          requestId,
          method: ctx.request.method,
          path: ctx.path,
          appId: ctx.appId,
          ip: ctx.requestInfo.ipAddress,
          timestamp: new Date().toISOString(),
        }),
      );
    },

    onResponse(ctx, response) {
      const meta = pending.get(ctx.request);
      const requestId = meta?.requestId ?? "unknown";
      const duration = meta ? Math.round(performance.now() - meta.start) : -1;

      console.log(
        JSON.stringify({
          level: "info",
          event: "request_end",
          requestId,
          method: ctx.request.method,
          path: ctx.path,
          appId: ctx.appId,
          status: response.status,
          durationMs: duration,
          timestamp: new Date().toISOString(),
        }),
      );

      // Add request ID header to response
      const newHeaders = new Headers(response.headers);
      newHeaders.set("X-Request-Id", requestId);
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: newHeaders,
      });
    },
  };
}
