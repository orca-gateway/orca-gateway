// ── Capability Negotiation (Epic 25b slice 2) ────────────────
//
// A client-advertised snapshot of what the calling SDK build can render. The
// server uses this to filter the rendered tree via capability-aware policy
// resolution before resolving Values — see capability-filter.ts.
//
// Canonical form (shared bit-for-bit with the Flutter SDK's
// SdkCapabilities.toVector()): all arrays are lexicographically sorted, all
// keys are the ones enumerated below in this exact order. Any deviation
// from this shape will desync the client/server hash and break the 412
// retry protocol.

export interface CapabilityVector {
  protocolVersion: string;
  sdkSemver: string;
  widgets: string[];
  valueKinds: string[];
  actionKinds: string[];
  transformKinds: string[];
  boolExprOps: string[];
}

/**
 * What the server knows about the current request's client capabilities.
 *
 * - `sdkVersion` / `hash` are populated from HTTP headers for every request
 *   that carries them. An unversioned client (no headers) yields `undefined`
 *   for this whole object — the filter stage treats that as "no negotiation,
 *   render everything", matching pre-25b behavior.
 *
 * - `vector` is populated by the engine AFTER header extraction, by looking
 *   the hash up in the per-instance vector cache. If the hash is unknown and
 *   no `_orcaCapsVector` is present in the request body, the engine returns
 *   HTTP 412 before the pipeline runs, so downstream code never sees a
 *   half-populated ClientCapabilitiesRef with a hash but no vector.
 */
export interface ClientCapabilitiesRef {
  sdkVersion?: string;
  hash?: string;
  vector?: CapabilityVector;
}

// ── Request Info ─────────────────────────────────────────────

export interface RequestInfo {
  // Device
  platform: "iOS" | "Android";
  osVersion: string;
  deviceModel: string;
  appVersion: string;
  buildNumber: string;

  // Screen
  screenSize: { width: number; height: number };
  pixelDensity: number;
  safeAreaInsets: { top: number; bottom: number; left: number; right: number };

  // Localization
  locale: string;
  timezone: string;
  language: string;

  // Network
  networkType: "wifi" | "cellular" | "offline";
  ipAddress: string;

  // Route
  routePath: string;
  routeParams: Record<string, string>;
  queryParams: Record<string, string>;

  // Auth
  authToken?: string;
  userId?: string;

  // Capability negotiation (Epic 25b slice 2). Populated by the engine from
  // `x-orca-sdk-version` + `x-orca-caps-hash` headers, then hydrated with a
  // resolved vector from the capability-vector cache before the pipeline
  // runs. Absent for clients that don't advertise capabilities.
  clientCapabilities?: ClientCapabilitiesRef;

  // Custom
  [custom: string]: unknown;
}

// ── Page Context (Request → Render) ─────────────────────────

export interface PageContext {
  requestInfo: RequestInfo;
  pageId: string;
  routePath: string;
  routeParams: Record<string, string>;
  pageState: Record<string, unknown>;
  appState: Record<string, unknown>;
}

// ── Render Context (Server-side rendering) ──────────────────

export interface RenderContext {
  requestInfo: RequestInfo;
  pageId: string;
  infoData: unknown;
  pageState: Record<string, unknown>;
  appState: Record<string, unknown>;
}

// ── Action Context (Server action execution) ────────────────

export interface ActionContext {
  requestInfo: RequestInfo;
  pageState: Record<string, unknown>;
  appState: Record<string, unknown>;
  actionParams: Record<string, unknown>;
}
