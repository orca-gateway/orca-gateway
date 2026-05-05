import type { Middleware } from "../core/middleware";

export interface RateLimitConfig {
  /** Maximum requests per second per IP. Defaults to 100. */
  maxPerSecond?: number;
  /** Bucket capacity (burst size). Defaults to maxPerSecond. */
  burst?: number;
  /** Maximum number of tracked IPs. Oldest entries evicted when exceeded. Defaults to 10000. */
  maxBuckets?: number;
}

interface TokenBucket {
  tokens: number;
  lastRefill: number;
}

export function rateLimitMiddleware(config: RateLimitConfig = {}): Middleware {
  const rate = config.maxPerSecond ?? 100;
  const burst = config.burst ?? rate;
  const maxBuckets = config.maxBuckets ?? 10_000;
  const buckets = new Map<string, TokenBucket>();

  // Periodically clean up stale buckets (every 60s)
  const cleanup = setInterval(() => {
    const now = Date.now();
    for (const [ip, bucket] of buckets) {
      if (now - bucket.lastRefill > 60_000) {
        buckets.delete(ip);
      }
    }
  }, 60_000);
  // Don't hold the process open
  if (cleanup.unref) cleanup.unref();

  return {
    name: "rate-limit",
    onRequest(ctx) {
      const ip = ctx.requestInfo.ipAddress || "unknown";
      const now = Date.now();

      let bucket = buckets.get(ip);
      if (!bucket) {
        // Evict oldest entry if at capacity
        if (buckets.size >= maxBuckets) {
          const oldest = buckets.keys().next().value!;
          buckets.delete(oldest);
        }
        bucket = { tokens: burst, lastRefill: now };
        buckets.set(ip, bucket);
      }

      // Refill tokens based on elapsed time
      const elapsed = (now - bucket.lastRefill) / 1000;
      bucket.tokens = Math.min(burst, bucket.tokens + elapsed * rate);
      bucket.lastRefill = now;

      if (bucket.tokens < 1) {
        return {
          status: 429,
          headers: { "Retry-After": "1" },
          body: { error: "Too many requests" },
        };
      }

      bucket.tokens -= 1;
    },
  };
}
