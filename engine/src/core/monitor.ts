import type { RequestInfo, PageContext, ActionContext } from "../types/context";
import type { PageResponse } from "./page";

// ── Monitor Event Types ──────────────────────────────────

export interface MonitorEvent {
  timestamp: number;
}

export interface FlowStartEvent extends MonitorEvent {
  flowName: string;
  path: string;
}

export interface FlowEndEvent extends MonitorEvent {
  flowName: string;
  path: string;
  durationMs: number;
}

export interface PageRenderEvent extends MonitorEvent {
  pageId: string;
  path: string;
  context: PageContext;
  response: PageResponse;
  durationMs: number;
}

export interface PageUpdateEvent extends MonitorEvent {
  pageId: string;
  path: string;
  context: PageContext;
}

export interface MonitorErrorEvent extends MonitorEvent {
  error: unknown;
  pageId?: string;
  path?: string;
  stage?: string;
}

export interface CacheHitEvent extends MonitorEvent {
  pageId: string;
  cacheKey: string;
}

export interface CacheMissEvent extends MonitorEvent {
  pageId: string;
  cacheKey: string;
}

export interface ServerActionCallEvent extends MonitorEvent {
  actionId: string;
  context: ActionContext;
  durationMs: number;
  success: boolean;
  error?: unknown;
}

export interface SessionStartEvent extends MonitorEvent {
  deviceId?: string;
  requestInfo: RequestInfo;
}

export interface SessionEndEvent extends MonitorEvent {
  deviceId?: string;
  requestInfo: RequestInfo;
}

export interface OfflineSession {
  type: "start" | "end";
  timestamp: number;
}

export interface RegisterOfflineSessionsEvent extends MonitorEvent {
  deviceId: string;
  sessions: OfflineSession[];
  requestInfo: RequestInfo;
}

// ── Monitor Interface ────────────────────────────────────

export interface Monitor {
  onFlowStart?(event: FlowStartEvent): void;
  onFlowEnd?(event: FlowEndEvent): void;
  onPageRender?(event: PageRenderEvent): void;
  onPageUpdate?(event: PageUpdateEvent): void;
  onError?(event: MonitorErrorEvent): void;
  onCacheHit?(event: CacheHitEvent): void;
  onCacheMiss?(event: CacheMissEvent): void;
  onServerActionCall?(event: ServerActionCallEvent): void;
  onSessionStart?(event: SessionStartEvent): void;
  onSessionEnd?(event: SessionEndEvent): void;
  onRegisterOfflineSessions?(event: RegisterOfflineSessionsEvent): void;
}

// ── Monitor Emitter ──────────────────────────────────────

export class MonitorEmitter {
  private monitors: Monitor[] = [];

  register(monitor: Monitor): void {
    this.monitors.push(monitor);
  }

  emit<K extends keyof Monitor>(
    hook: K,
    event: Parameters<NonNullable<Monitor[K]>>[0],
  ): void {
    for (const monitor of this.monitors) {
      const fn = monitor[hook];
      if (fn) {
        try {
          (fn as (e: typeof event) => void).call(monitor, event);
        } catch {
          // Monitor errors must not break the engine
        }
      }
    }
  }

  get count(): number {
    return this.monitors.length;
  }
}

// ── Console Monitor (built-in) ───────────────────────────

export class ConsoleMonitor implements Monitor {
  onFlowStart(event: FlowStartEvent): void {
    console.log(`[Orca Gateway] Flow started: ${event.flowName} path=${event.path}`);
  }

  onFlowEnd(event: FlowEndEvent): void {
    console.log(`[Orca Gateway] Flow ended: ${event.flowName} path=${event.path} (${event.durationMs.toFixed(1)}ms)`);
  }

  onPageRender(event: PageRenderEvent): void {
    console.log(`[Orca Gateway] Page rendered: ${event.pageId} path=${event.path} (${event.durationMs.toFixed(1)}ms)`);
  }

  onPageUpdate(event: PageUpdateEvent): void {
    console.log(`[Orca Gateway] Page updated: ${event.pageId} path=${event.path}`);
  }

  onError(event: MonitorErrorEvent): void {
    const msg = event.error instanceof Error ? event.error.message : String(event.error);
    const where = event.pageId ? ` page=${event.pageId}` : "";
    const stage = event.stage ? ` stage=${event.stage}` : "";
    console.error(`[Orca Gateway] Error:${where}${stage} ${msg}`);
  }

  onCacheHit(event: CacheHitEvent): void {
    console.log(`[Orca Gateway] Cache HIT: ${event.pageId} key=${event.cacheKey}`);
  }

  onCacheMiss(event: CacheMissEvent): void {
    console.log(`[Orca Gateway] Cache MISS: ${event.pageId} key=${event.cacheKey}`);
  }

  onServerActionCall(event: ServerActionCallEvent): void {
    const status = event.success ? "OK" : "FAILED";
    console.log(`[Orca Gateway] Action: ${event.actionId} ${status} (${event.durationMs.toFixed(1)}ms)`);
  }

  onSessionStart(event: SessionStartEvent): void {
    console.log(`[Orca Gateway] Session started${event.deviceId ? ` device=${event.deviceId}` : ""}`);
  }

  onSessionEnd(event: SessionEndEvent): void {
    console.log(`[Orca Gateway] Session ended${event.deviceId ? ` device=${event.deviceId}` : ""}`);
  }

  onRegisterOfflineSessions(event: RegisterOfflineSessionsEvent): void {
    console.log(`[Orca Gateway] Offline sessions registered: device=${event.deviceId} count=${event.sessions.length}`);
  }
}
