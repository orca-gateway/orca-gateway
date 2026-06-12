import { Database } from "bun:sqlite";
import type { CacheProvider } from "./cache";

// ── SQLite Cache Implementation ───────────────────────────

export class SQLiteCache implements CacheProvider {
  private db: Database;
  private stmtGet: ReturnType<Database["prepare"]>;
  private stmtSet: ReturnType<Database["prepare"]>;
  private stmtDel: ReturnType<Database["prepare"]>;
  private stmtFlush: ReturnType<Database["prepare"]>;
  private stmtCleanup: ReturnType<Database["prepare"]>;
  private cleanupTimer: ReturnType<typeof setInterval>;

  constructor(path = ":memory:") {
    this.db = new Database(path);

    // WAL mode + PRAGMA optimizations for performance
    this.db.exec("PRAGMA journal_mode = WAL");
    this.db.exec("PRAGMA synchronous = NORMAL");
    this.db.exec("PRAGMA cache_size = -64000"); // 64MB
    this.db.exec("PRAGMA temp_store = MEMORY");

    // Create cache table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS cache (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        expires_at INTEGER
      )
    `);

    // Index for TTL cleanup
    this.db.exec(`
      CREATE INDEX IF NOT EXISTS idx_cache_expires
      ON cache(expires_at) WHERE expires_at IS NOT NULL
    `);

    // Prepared statements for performance
    this.stmtGet = this.db.prepare(
      "SELECT value FROM cache WHERE key = ? AND (expires_at IS NULL OR expires_at > ?)",
    );
    this.stmtSet = this.db.prepare(
      "INSERT OR REPLACE INTO cache (key, value, expires_at) VALUES (?, ?, ?)",
    );
    this.stmtDel = this.db.prepare("DELETE FROM cache WHERE key = ?");
    this.stmtFlush = this.db.prepare("DELETE FROM cache");
    this.stmtCleanup = this.db.prepare(
      "DELETE FROM cache WHERE expires_at IS NOT NULL AND expires_at <= ?",
    );

    // Sweep expired rows periodically so the cache file doesn't grow
    // unbounded. unref'd so the timer never keeps the process alive.
    this.cleanupTimer = setInterval(() => this.cleanup(), 60_000);
    this.cleanupTimer.unref?.();
  }

  async get(key: string): Promise<string | null> {
    const now = Date.now();
    const row = this.stmtGet.get(key, now) as { value: string } | null;
    return row?.value ?? null;
  }

  async set(key: string, value: string, ttl?: number): Promise<void> {
    const expiresAt = ttl ? Date.now() + ttl * 1000 : null;
    this.stmtSet.run(key, value, expiresAt);
  }

  async del(key: string): Promise<void> {
    this.stmtDel.run(key);
  }

  async flush(): Promise<void> {
    this.stmtFlush.run();
  }

  /** Remove expired entries. Call periodically if desired. */
  cleanup(): void {
    this.stmtCleanup.run(Date.now());
  }

  close(): void {
    clearInterval(this.cleanupTimer);
    this.db.close();
  }
}
