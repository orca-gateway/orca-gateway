// Fallback policy resolver (Epic 25b slice 2, task 25b.4 OSS side).
//
// When the capability filter encounters a feature a client can't render, it
// needs to decide what to do: strip it silently (graceful), wrap the tree in
// a warn banner (warn), or replace the whole page with a blocking prompt
// (require). The *decision* is a tenant-configurable policy. This file
// defines the interface the filter calls, plus a minimal static-config
// implementation suitable for OSS self-hosters.
//
// Cloud slice 3 will ship a Postgres-backed implementation that satisfies
// the same `FallbackPolicyResolver` interface, so no capability-filter code
// needs to change when cloud lands.
//
// Feature key convention:
//
//   "widget.<Type>"       e.g. "widget.FancyCalendar"
//   "value.<kind>"        e.g. "value.liveRegion"
//   "action.<kind>"       e.g. "action.biometricAuth"
//   "transform.<kind>"    e.g. "transform.localDateFormat"
//   "boolExpr.<op>"       e.g. "boolExpr.regex"
//
// Exact match only — there is no wildcard or prefix logic in the OSS
// resolver. Matching is simple map lookup, with fall-through to `default`.
// Cloud's impl can add pattern matching if tenants ask for it; the filter
// never calls anything beyond `resolve(featureKey)` so that's a purely
// resolver-internal change.

export type FallbackMode = "graceful" | "warn" | "require";

export type FeatureKey = string;

/** Declarative policy config. Intentionally small: two fields, both optional.
 *  Missing `default` defaults to `"graceful"` — the least hostile option. */
export interface FallbackPolicyConfig {
  default?: FallbackMode;
  features?: Record<FeatureKey, FallbackMode>;
}

export interface FallbackPolicyResolver {
  /** Return the mode to apply when `featureKey` is unsupported by the
   *  calling client. Implementations MUST be synchronous and pure — the
   *  filter calls this in a tight loop across potentially many nodes per
   *  page, and async/side-effecting resolvers would require a full pipeline
   *  refactor to thread promises through. Cloud slice 3's Postgres impl
   *  satisfies this by pre-loading the policy table into an in-memory map
   *  once per request. */
  resolve(featureKey: FeatureKey): FallbackMode;
}

const DEFAULT_MODE: FallbackMode = "graceful";

export function createStaticPolicyResolver(
  config: FallbackPolicyConfig = {},
): FallbackPolicyResolver {
  const fallback = config.default ?? DEFAULT_MODE;
  const features = config.features ?? {};
  return {
    resolve(featureKey: FeatureKey): FallbackMode {
      return features[featureKey] ?? fallback;
    },
  };
}

/** Precedence used by the filter when a single node has multiple
 *  unsupported features with different modes. `require` wins (hardest
 *  failure mode must surface), then `warn`, then `graceful`. */
export function highestSeverity(modes: FallbackMode[]): FallbackMode {
  if (modes.length === 0) return DEFAULT_MODE;
  if (modes.includes("require")) return "require";
  if (modes.includes("warn")) return "warn";
  return "graceful";
}
