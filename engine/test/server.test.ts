import { describe, expect, it, afterAll, beforeAll } from "bun:test";
import { engine, ready } from "../src/server";

let server: Awaited<typeof ready>;

beforeAll(async () => {
  server = await ready;
});

afterAll(() => {
  engine.stop();
});

describe("GET /health", () => {
  it("returns 200 with engine name", async () => {
    const res = await fetch(`http://localhost:${server.port}/health`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { status: string; name: string };
    expect(body.status).toBe("ok");
    expect(body.name).toBe("Orca Gateway Engine");
  });
});

describe("unknown route", () => {
  it("returns 404", async () => {
    const res = await fetch(`http://localhost:${server.port}/unknown`);
    expect(res.status).toBe(404);
  });
});
