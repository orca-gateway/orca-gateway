import type { CacheProvider } from "./cache";

// ── Redis Cache Implementation ────────────────────────────
// Works with any Redis-compatible server via raw TCP commands.
// No external dependencies — uses Bun's built-in TCP socket.

export class RedisCache implements CacheProvider {
  private socket: ReturnType<typeof Bun.connect> extends Promise<infer T> ? T : never;
  private ready: Promise<void>;
  private responseQueue: Array<{
    resolve: (value: string | null) => void;
    reject: (error: Error) => void;
  }> = [];
  private buffer = "";

  constructor(private url: string) {
    this.ready = this.connect();
  }

  private async connect(): Promise<void> {
    const parsed = new URL(this.url);
    const host = parsed.hostname || "127.0.0.1";
    const port = Number(parsed.port) || 6379;
    const password = parsed.password || undefined;

    this.socket = await Bun.connect({
      hostname: host,
      port,
      socket: {
        data: (_socket, data) => {
          this.buffer += new TextDecoder().decode(data);
          this.processBuffer();
        },
        error: (_socket, error) => {
          const pending = this.responseQueue.shift();
          pending?.reject(error);
        },
        close: () => {},
        open: () => {},
      },
    });

    if (password) {
      await this.command("AUTH", password);
    }

    const db = parsed.pathname?.replace("/", "");
    if (db && db !== "0") {
      await this.command("SELECT", db);
    }
  }

  private processBuffer(): void {
    while (this.responseQueue.length > 0 && this.buffer.length > 0) {
      const result = this.parseResponse();
      if (result === undefined) break; // incomplete data
      const pending = this.responseQueue.shift();
      pending?.resolve(result);
    }
  }

  private parseResponse(): string | null | undefined {
    const nlIdx = this.buffer.indexOf("\r\n");
    if (nlIdx === -1) return undefined;

    const prefix = this.buffer[0];
    const line = this.buffer.substring(1, nlIdx);

    if (prefix === "+" || prefix === ":") {
      this.buffer = this.buffer.substring(nlIdx + 2);
      return line;
    }

    if (prefix === "-") {
      this.buffer = this.buffer.substring(nlIdx + 2);
      return null;
    }

    if (prefix === "$") {
      const len = parseInt(line, 10);
      if (len === -1) {
        this.buffer = this.buffer.substring(nlIdx + 2);
        return null;
      }
      const dataStart = nlIdx + 2;
      const dataEnd = dataStart + len;
      if (this.buffer.length < dataEnd + 2) return undefined; // incomplete
      const value = this.buffer.substring(dataStart, dataEnd);
      this.buffer = this.buffer.substring(dataEnd + 2);
      return value;
    }

    // Skip unknown types
    this.buffer = this.buffer.substring(nlIdx + 2);
    return null;
  }

  private command(...args: string[]): Promise<string | null> {
    return new Promise((resolve, reject) => {
      const cmd = `*${args.length}\r\n${args.map((a) => `$${Buffer.byteLength(a)}\r\n${a}\r\n`).join("")}`;
      this.responseQueue.push({ resolve, reject });
      this.socket.write(cmd);
    });
  }

  async get(key: string): Promise<string | null> {
    await this.ready;
    return this.command("GET", key);
  }

  async set(key: string, value: string, ttl?: number): Promise<void> {
    await this.ready;
    if (ttl) {
      await this.command("SET", key, value, "EX", String(ttl));
    } else {
      await this.command("SET", key, value);
    }
  }

  async del(key: string): Promise<void> {
    await this.ready;
    await this.command("DEL", key);
  }

  async flush(): Promise<void> {
    await this.ready;
    await this.command("FLUSHDB");
  }

  async close(): Promise<void> {
    await this.ready;
    this.socket.end();
  }
}
