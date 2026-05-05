// Minimum SDK version enforcement (Epic 25b task 25b.6).
//
// The capability filter from slice 2 handles "this client can't render a
// specific feature" at per-feature granularity. This file handles a
// coarser, harder check: "this client is below the minimum SDK version
// this app supports at all, so block it before the pipeline runs."
//
// The epic's invariant: when a request comes in below the minimum, the
// server returns HTTP 426 Upgrade Required with a body that IS a
// PageResponse containing a single blocking FallbackPrompt. 426 is the
// *only* response shape guaranteed to work for every SDK version ever
// shipped — older SDKs that don't know how to handle 426 will throw at
// status-check time (safe, shows an error to the user), and future SDKs
// can intercept 426 specifically and render the embedded blocking prompt
// as the upgrade screen. The body shape is forward-compatible regardless.
//
// Why a separate file from fallback-policy.ts? Fallback policy is
// per-feature ("what do I do about this Widget/Action/Value?"). Min-SDK
// is per-app ("is this client even allowed to talk to me?"). Different
// granularity, different enforcement point in the pipeline. Mixing them
// would conflate concerns that have different lifecycles and different
// cloud-side storage.

import type { CapabilityVector } from "../types/context";
import type { PageResponse } from "./page";

/**
 * Parse a semver string into a numeric tuple for comparison.
 *
 * Orca Gateway's SDK versions are always major.minor.patch with no pre-release
 * tags, build metadata, or "v" prefix — the SDK's pubspec.yaml has always
 * shipped a clean `version: 0.1.0` style. So we don't need a full semver
 * parser; a three-segment numeric split is enough and keeps the engine
 * dependency-free.
 *
 * Any malformed input (non-numeric, wrong segment count, empty) returns
 * null rather than throwing, so callers can fall back to "allow" when the
 * client's version header is garbage — that's the safer failure mode than
 * 426-ing a legitimate client because it emitted a dev-mode version string.
 */
export function parseSemver(version: string): [number, number, number] | null {
  if (!version) return null;
  const parts = version.split(".");
  if (parts.length !== 3) return null;
  const nums: number[] = [];
  for (const p of parts) {
    if (!/^\d+$/.test(p)) return null;
    nums.push(parseInt(p, 10));
  }
  return [nums[0], nums[1], nums[2]];
}

/**
 * Compare two semver strings. Returns negative if `a < b`, zero if equal,
 * positive if `a > b`. Malformed inputs sort as zero (not below) so a
 * bad client version doesn't accidentally trip the min-SDK gate.
 */
export function compareSemver(a: string, b: string): number {
  const pa = parseSemver(a);
  const pb = parseSemver(b);
  if (!pa || !pb) return 0;
  for (let i = 0; i < 3; i++) {
    if (pa[i] !== pb[i]) return pa[i] - pb[i];
  }
  return 0;
}

/**
 * Per-app minimum SDK version configuration. The epic specs two levels:
 * `apps.min_sdk_version` is the base, `app_environments.min_sdk_override`
 * lets a specific env (staging, dev) relax or tighten the cutoff.
 *
 * OSS self-hosters configure this once per Engine via
 * `engine.setMinSdkVersion(config)`. Cloud slice 4 will offer the same
 * configuration via dashboard UI backed by Postgres. Both paths satisfy
 * the `MinSdkVersionResolver` interface below.
 */
export interface MinSdkVersionConfig {
  /** App-level default. Empty string disables the check for that app. */
  appDefault?: string;
  /** Per-environment overrides, keyed by env name. Non-empty override
   *  wins over appDefault. Empty string override means "no min". */
  envOverrides?: Record<string, string>;
}

export interface MinSdkVersionResolver {
  /**
   * Return the effective minimum SDK version for the given environment.
   * Empty string means "no minimum" — requests from any SDK are allowed.
   */
  minFor(env: string | undefined): string;
}

export function createStaticMinSdkResolver(
  config: MinSdkVersionConfig = {},
): MinSdkVersionResolver {
  const appDefault = config.appDefault ?? "";
  const overrides = { ...(config.envOverrides ?? {}) };
  return {
    minFor(env: string | undefined): string {
      if (env !== undefined && env in overrides) return overrides[env];
      return appDefault;
    },
  };
}

/**
 * Determine whether a request should be upgraded (426) given the client's
 * advertised SDK version and the configured minimum. Returns the minimum
 * that was enforced (for logging / response body) or `null` if the request
 * is allowed to proceed.
 *
 * Logic:
 *   - No min configured (empty string) → always allowed.
 *   - Client sent no `X-Orca-Sdk-Version` header → allowed (unversioned
 *     clients bypass the gate; they also bypass the capability filter).
 *   - Client version parse fails → allowed (don't punish garbage headers).
 *   - Client version < min → BLOCK, return the min.
 *   - Client version ≥ min → allowed, return null.
 */
export function checkMinSdkVersion(
  clientVersion: string | undefined,
  min: string,
): string | null {
  if (!min) return null;
  if (!clientVersion) return null;
  if (parseSemver(clientVersion) === null) return null;
  if (compareSemver(clientVersion, min) < 0) {
    return min;
  }
  return null;
}

/**
 * Build the HTTP 426 response body. The body IS a PageResponse envelope
 * containing a single blocking FallbackPrompt node — future SDKs can
 * render it directly as the upgrade screen, and current SDKs (which throw
 * on any non-200 today) still see a structured error payload they can
 * surface via OrcaClientException.
 *
 * The top-level shape has extra diagnostic fields alongside the page:
 *
 *   {
 *     "error": "sdk_version_too_old",
 *     "minSdkVersion": "1.2.0",
 *     "clientSdkVersion": "1.1.5",
 *     "page": <PageResponse>
 *   }
 *
 * A future-smart SDK checks for status 426, parses body, uses `page` as
 * the render target. The legacy throw path still works because `error`
 * and the HTTP status are both inspectable on the exception.
 */
export function buildUpgradeRequiredBody(
  pageId: string,
  clientVersion: string | undefined,
  minVersion: string,
): {
  error: string;
  minSdkVersion: string;
  clientSdkVersion: string;
  page: PageResponse;
} {
  const page: PageResponse = {
    pageId,
    title: "Update required",
    state: [],
    components: [
      {
        id: "__min_sdk_block_root__",
        type: "FallbackPrompt",
        kind: "primitive",
        childMode: "none",
        props: {
          title: "Update required",
          body:
            `This app needs version ${minVersion} or later to continue. ` +
            `Please update from your app store.`,
          severity: "blocking",
        },
        children: [],
        watches: [],
      },
    ],
  };
  return {
    error: "sdk_version_too_old",
    minSdkVersion: minVersion,
    clientSdkVersion: clientVersion ?? "",
    page,
  };
}

// Unused but exported for a cloud slice 4 forward reference — keeps the
// module's public API footprint for capability negotiation stable even
// as internal wiring changes.
export type { CapabilityVector };
