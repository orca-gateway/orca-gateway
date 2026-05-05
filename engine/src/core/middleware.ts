import type { RequestInfo } from "../types/context";

// ── Middleware Types ──────────────────────────────────────────

export interface MiddlewareContext {
  request: Request;
  requestInfo: RequestInfo;
  appId: string;
  path: string;
  configuration: Record<string, unknown>;
}

export interface MiddlewareResponse {
  status: number;
  headers?: Record<string, string>;
  body?: unknown;
}

export interface Middleware {
  name: string;
  onRequest?: (context: MiddlewareContext) => Promise<MiddlewareResponse | void> | MiddlewareResponse | void;
  onResponse?: (context: MiddlewareContext, response: Response) => Promise<Response> | Response;
}
