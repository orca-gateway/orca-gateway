// The /voice page of the custom example app (examples/server/custom.ts), case
// C17.3/page of native-parity-s17-voice. A VoiceRecorder with a recorderId and
// three buttons built from the classes `orca plugin generate` writes for
// plugins/orca_voice_recorder/orca_plugin.yaml (examples/server/
// orca_voice_recorder.ts): Start, Stop (the path and the duration into page
// state) and Play (the saved path), and two Texts on those two state keys.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";

type Page = { components: ComponentNode[]; state: { key: string; scope: string; initial: unknown }[] };

let engine: Engine;
let base: string;

beforeAll(async () => {
  const { customApp } = await import("../../examples/server/custom");
  engine = new Engine();
  engine.registerApp(customApp);
  const server = await engine.start({ port: 0 });
  base = `http://localhost:${server.port}`;
});

afterAll(() => {
  engine?.stop();
});

async function page(location: string): Promise<Page> {
  const res = await fetch(`${base}/api/v1/app/custom/page/${location}`);
  expect(res.status).toBe(200);
  return (await res.json()) as Page;
}

const byId = (p: Page) => new Map(p.components.map((n) => [n.id, n]));
const tap = (p: Page, id: string) => byId(p).get(id)!.actions!.onTap as Record<string, unknown>;

describe("voice demo", () => {
  test("C17.3/page /voice declares the page state for the path and the duration", async () => {
    const voice = await page("voice");
    expect(voice.state).toEqual([
      { key: "voicePath", scope: "page", initial: "" },
      { key: "voiceDuration", scope: "page", initial: 0 },
    ]);
  });

  test("C17.3/page /voice has one VoiceRecorder with its recorderId", async () => {
    const voice = await page("voice");
    const recorders = voice.components.filter((n) => n.type === "VoiceRecorder");
    expect(recorders.length).toBe(1);
    expect(recorders[0]).toMatchObject({ id: "recorder", kind: "primitive", childMode: "none" });
    // The encoder writes a static prop value as the bare value.
    expect(recorders[0]!.props).toEqual({ recorderId: "demo" });
  });

  test("C17.3/page Start, Stop and Play send the recorder's actions with their params", async () => {
    const voice = await page("voice");
    expect(tap(voice, "start")).toEqual({ type: "startRecording", recorderId: "demo" });
    expect(tap(voice, "stop")).toEqual({
      type: "stopRecording",
      recorderId: "demo",
      pathKey: "voicePath",
      durationKey: "voiceDuration",
    });
    expect(tap(voice, "play")).toEqual({
      type: "playRecording",
      path: { type: "state", key: "voicePath", scope: "page" },
    });
  });

  test("C17.3/page the Texts show the saved path and the duration from page state", async () => {
    const voice = await page("voice");
    const nodes = byId(voice);
    expect(nodes.get("voice-path")!.type).toBe("Text");
    expect(nodes.get("voice-path")!.watches).toEqual(["voicePath"]);
    expect(nodes.get("voice-path")!.props.data).toMatchObject({
      type: "transform",
      input: { type: "state", key: "voicePath", scope: "page" },
    });
    expect(nodes.get("voice-duration")!.type).toBe("Text");
    expect(nodes.get("voice-duration")!.watches).toEqual(["voiceDuration"]);
    expect(nodes.get("voice-duration")!.props.data).toMatchObject({
      type: "transform",
      input: { type: "state", key: "voiceDuration", scope: "page" },
    });
  });

  test("C17.3/page /home has a button that navigates to /voice, as the map's does", async () => {
    const home = await page("home");
    const targets = home.components
      .map((n) => n.actions?.onTap as Record<string, unknown> | undefined)
      .filter((a) => a?.type === "navigate")
      .map((a) => a!.path as string);
    // The flat node list is not in screen order.
    expect(targets.sort()).toEqual(["/map", "/video", "/voice"]);
  });
});
