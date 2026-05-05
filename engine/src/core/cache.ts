import { getByDotPath } from "./value-resolver";

// ── Cache Provider Interface ──────────────────────────────

export interface CacheProvider {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, ttl?: number): Promise<void>;
  del(key: string): Promise<void>;
  flush(): Promise<void>;
}

// ── Cache Policy ──────────────────────────────────────────

export interface CachePolicyConfig {
  /** RequestInfo fields to include in cache key (e.g. "locale", "screenSize.width") */
  requestInfo?: string[];
  /** Page state keys to include in cache key */
  pageState?: string[];
  /** App state keys to include in cache key */
  appState?: string[];
  /** TTL override in seconds */
  ttl?: number;
}

export type CachePolicy = "none" | "static" | CachePolicyConfig;

// ── Resolved Cache Config ─────────────────────────────────

export interface ResolvedCacheConfig {
  policy: CachePolicy;
  ttl: number;
}

/**
 * Merge flow-level and page-level cache policies.
 * Page wins if it sets anything other than "none".
 * If page is "none", fall back to flow's policy.
 */
export function resolveCacheConfig(
  flowPolicy: CachePolicy | undefined,
  flowTtl: number | undefined,
  pagePolicy: CachePolicy,
  pageTtl: number,
): ResolvedCacheConfig {
  // Page explicitly sets a policy → use it
  if (pagePolicy !== "none") {
    const ttl = typeof pagePolicy === "object" && pagePolicy.ttl != null
      ? pagePolicy.ttl
      : pageTtl;
    return { policy: pagePolicy, ttl };
  }

  // Fall back to flow policy
  if (flowPolicy && flowPolicy !== "none") {
    const ttl = typeof flowPolicy === "object" && flowPolicy.ttl != null
      ? flowPolicy.ttl
      : (flowTtl ?? 60);
    return { policy: flowPolicy, ttl };
  }

  return { policy: "none", ttl: 60 };
}

// ── Cache Key Builder ─────────────────────────────────────

export function buildCacheKey(
  pageId: string,
  policy: CachePolicy,
  sources: {
    requestInfo?: Record<string, unknown>;
    pageState?: Record<string, unknown>;
    appState?: Record<string, unknown>;
    /**
     * Client capability hash (Epic 25b slice 2). When present, it's appended
     * as a suffix to the cache key so two SDK versions with different
     * capability vectors hit different cache entries — preventing a client
     * that supports a feature from seeing a filtered response that was
     * rendered for an older client (or vice versa).
     *
     * When absent (unversioned client or no negotiation), the cache key
     * omits the suffix entirely so pre-25b fixtures and non-negotiating
     * clients remain byte-stable with existing cache entries.
     */
    capsHash?: string;
  },
): string {
  if (policy === "none") return "";

  const capsSuffix = sources.capsHash ? `:caps:${sources.capsHash}` : "";
  if (policy === "static") return `page:${pageId}${capsSuffix}`;

  const parts: string[] = [`page:${pageId}`];

  if (policy.requestInfo?.length) {
    const vals = pickFields(sources.requestInfo ?? {}, policy.requestInfo);
    parts.push(`ri:${stableHash(vals)}`);
  }

  if (policy.pageState?.length) {
    const vals = pickFields(sources.pageState ?? {}, policy.pageState);
    parts.push(`ps:${stableHash(vals)}`);
  }

  if (policy.appState?.length) {
    const vals = pickFields(sources.appState ?? {}, policy.appState);
    parts.push(`as:${stableHash(vals)}`);
  }

  // If config object but no fields specified → same as static
  return parts.join(":") + capsSuffix;
}

function pickFields(
  source: Record<string, unknown>,
  keys: string[],
): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const key of keys) {
    result[key] = getByDotPath(source, key);
  }
  return result;
}

function stableHash(obj: Record<string, unknown>): string {
  const sorted = Object.keys(obj)
    .sort()
    .map((k) => `${k}=${JSON.stringify(obj[k])}`)
    .join("&");
  if (!sorted) return "_empty_";
  const hasher = new Bun.CryptoHasher("md5");
  hasher.update(sorted);
  return hasher.digest("hex");
}

// ── ETag Helpers ──────────────────────────────────────────

export function generateETag(body: string): string {
  const hasher = new Bun.CryptoHasher("md5");
  hasher.update(body);
  return `"${hasher.digest("hex")}"`;
}

// ── Cache Factory ─────────────────────────────────────────

export async function createCacheProvider(
  sqlitePath = ":memory:",
): Promise<CacheProvider> {
  const redisUrl = process.env.REDIS_URL;
  if (redisUrl) {
    const { RedisCache } = await import("./redis-cache");
    return new RedisCache(redisUrl);
  }
  const { SQLiteCache } = await import("./sqlite-cache");
  return new SQLiteCache(sqlitePath);
}

// ── No-Op Cache (for policy: "none") ──────────────────────

export class NoOpCache implements CacheProvider {
  async get(): Promise<null> { return null; }
  async set(): Promise<void> {}
  async del(): Promise<void> {}
  async flush(): Promise<void> {}
}
