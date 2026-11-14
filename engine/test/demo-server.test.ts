// The demo server entry (examples/server/index.ts), cases I1-I4 of the
// launch-builds pipeline. Each test spawns the server as its own process on a
// free port (never 8080: Engine.start falls back to it when PORT is 0), waits
// for its startup line (once more on a fresh port if another process took the
// first one), and kills whatever is still running in afterEach.

import { describe, expect, test, afterEach } from "bun:test";
import type { Subprocess } from "bun";
import { mkdtempSync, rmSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";
import enginePackage from "../package.json";

const OSS_ROOT = join(import.meta.dir, "..", "..");
const ENTRY = join(OSS_ROOT, "examples", "server", "index.ts");
const VERSION = enginePackage.version;
const EMPTY = "Nothing to do yet";
const TODO_ROUTE = "/api/v1/app/todo/page/home";
const KEY = { "x-api-key": "demo-key" };
const STARTUP_MS = 15_000;
const EXIT_MS = 5_000;

interface Running {
  proc: Subprocess<"ignore", "pipe", "pipe">;
  port: number;
  base: string;
  stdout: () => string;
  stderr: () => string;
}

const running: Running[] = [];

afterEach(async () => {
  for (const r of running.splice(0)) {
    if (r.proc.exitCode === null && r.proc.signalCode === null) {
      r.proc.kill("SIGKILL");
      await r.proc.exited;
    }
  }
});

// ── Helpers ────────────────────────────────────────────────

function freePort(): number {
  const probe = Bun.serve({ port: 0, fetch: () => new Response("") });
  const port = probe.port!;
  probe.stop(true);
  return port;
}

function collect(stream: ReadableStream<Uint8Array>): () => string {
  let text = "";
  const decoder = new TextDecoder();
  void (async () => {
    for await (const chunk of stream) text += decoder.decode(chunk, { stream: true });
  })();
  return () => text;
}

function serverEnv(port: number): Record<string, string> {
  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) if (v !== undefined) env[k] = v;
  delete env.REDIS_URL;
  delete env.ORCA_FALLBACK_POLICY;
  delete env.ORCA_MIN_SDK_VERSION;
  env.PORT = String(port);
  return env;
}

function spawnServer(cmd: string[], cwd: string): Running {
  const port = freePort();
  const proc = Bun.spawn(cmd, { cwd, env: serverEnv(port), stdin: "ignore", stdout: "pipe", stderr: "pipe" });
  const r: Running = {
    proc,
    port,
    base: `http://localhost:${port}`,
    stdout: collect(proc.stdout),
    stderr: collect(proc.stderr),
  };
  running.push(r);
  return r;
}

function startupLine(port: number): string {
  return `Orca demo server ${VERSION} on http://localhost:${port}`;
}

function hasLine(text: string, line: string): boolean {
  return text.split("\n").some((l) => l.trimEnd() === line);
}

/** Waits until stdout satisfies `ok`, the process dies, or the deadline passes. */
async function waitForOutput(r: Running, what: string, ok: (out: string) => boolean): Promise<void> {
  const deadline = Date.now() + STARTUP_MS;
  while (!ok(r.stdout())) {
    if (r.proc.exitCode !== null || r.proc.signalCode !== null || Date.now() > deadline) {
      throw new Error(
        `no ${what} (exit ${r.proc.exitCode}, signal ${r.proc.signalCode})\n` +
          `stdout:\n${r.stdout()}\nstderr:\n${r.stderr()}`,
      );
    }
    await Bun.sleep(25);
  }
}

async function waitForStartup(r: Running): Promise<void> {
  const line = startupLine(r.port);
  await waitForOutput(r, `startup line "${line}"`, (out) => hasLine(out, line));
}

/**
 * Spawns the server and waits for its startup line. Another process can take
 * the probed port before the server binds it: then one retry on a fresh port.
 */
async function startServer(cmd: string[], cwd: string): Promise<Running> {
  const r = spawnServer(cmd, cwd);
  try {
    await waitForStartup(r);
    return r;
  } catch (err) {
    if (!/EADDRINUSE|in use/.test(r.stderr())) throw err;
    const retry = spawnServer(cmd, cwd);
    await waitForStartup(retry);
    return retry;
  }
}

function startDemo(): Promise<Running> {
  return startServer([process.execPath, ENTRY], OSS_ROOT);
}

/** Sends `signal` and expects a clean exit (code 0, not killed) within 5 s. */
async function stopWith(r: Running, signal: "SIGINT" | "SIGTERM"): Promise<void> {
  r.proc.kill(signal);
  const outcome = await Promise.race([r.proc.exited.then(() => "exited"), Bun.sleep(EXIT_MS).then(() => "timeout")]);
  expect(outcome).toBe("exited");
  expect(r.proc.signalCode).toBeNull();
  expect(r.proc.exitCode).toBe(0);
}

async function getTodoPage(r: Running, headers?: Record<string, string>): Promise<Response> {
  return fetch(`${r.base}${TODO_ROUTE}`, { headers });
}

// ── Cases ──────────────────────────────────────────────────

describe("demo server (examples/server/index.ts)", () => {
  test("I1 prints the versioned startup line and the app list with todo; todo needs demo-key; counter answers", async () => {
    const r = await startDemo();
    await waitForOutput(r, "todo route line", (out) => out.includes(TODO_ROUTE));

    const out = r.stdout();
    expect(hasLine(out, startupLine(r.port))).toBe(true);
    expect(out).toContain("API Key: demo-key");
    expect(out).toMatch(/- todo: +\/api\/v1\/app\/todo\/page\/home/);

    const withKey = await getTodoPage(r, KEY);
    expect(withKey.status).toBe(200);
    expect(await withKey.text()).toContain(EMPTY);

    const withoutKey = await getTodoPage(r);
    expect(withoutKey.status).toBe(401);
    await withoutKey.body?.cancel();

    const counter = await fetch(`${r.base}/api/v1/app/counter/page/home`, { headers: KEY });
    expect(counter.status).toBe(200);
    await counter.body?.cancel();
  }, 30_000);

  test("I2 SIGINT and SIGTERM each stop the server with exit code 0 within 5 s", async () => {
    const first = await startDemo();
    await stopWith(first, "SIGINT");

    const second = await startDemo();
    await stopWith(second, "SIGTERM");
  }, 30_000);

  test("I3 a todo added before a restart is gone after it", async () => {
    const first = await startDemo();

    const add = await fetch(`${first.base}/api/v1/app/todo/action`, {
      method: "POST",
      headers: { ...KEY, "content-type": "application/json" },
      body: JSON.stringify({ action: "addTodo", params: { text: "Buy milk" } }),
    });
    expect(add.status).toBe(200);
    await add.body?.cancel();

    const before = await getTodoPage(first, KEY);
    expect(before.status).toBe(200);
    const beforeText = await before.text();
    expect(beforeText).toContain("Buy milk");
    expect(beforeText).not.toContain(EMPTY);

    await stopWith(first, "SIGTERM");

    const second = await startDemo();
    const after = await getTodoPage(second, KEY);
    expect(after.status).toBe(200);
    const afterText = await after.text();
    expect(afterText).toContain(EMPTY);
    expect(afterText).not.toContain("Buy milk");
  }, 30_000);

  test("I4 the compiled binary, run outside the repo, prints the startup line, serves todo and stops on SIGTERM", async () => {
    const dir = mkdtempSync(join(tmpdir(), "orca-demo-server-"));
    try {
      const binary = join(dir, "demo-server");
      const build = Bun.spawnSync(
        [process.execPath, "build", "--compile", ENTRY, "--outfile", binary],
        { cwd: dir, env: serverEnv(0), stdout: "pipe", stderr: "pipe" },
      );
      if (build.exitCode !== 0) {
        throw new Error(`bun build --compile failed (${build.exitCode})\n${build.stdout}\n${build.stderr}`);
      }

      const r = await startServer([binary], dir);

      const page = await getTodoPage(r, KEY);
      expect(page.status).toBe(200);
      expect(await page.text()).toContain(EMPTY);

      await stopWith(r, "SIGTERM");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }, 180_000);
});
