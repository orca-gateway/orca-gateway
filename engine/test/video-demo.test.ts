// The /video page of the custom example app (examples/server/custom.ts), case
// C17.2/page of native-parity-s17-video. A VideoPlayer with a playerId on a
// public https MP4, whose onProgress keeps the position in page state, and five
// buttons built from the classes `orca plugin generate` writes for
// plugins/orca_video_player/orca_plugin.yaml (examples/server/
// orca_video_player.ts): Play, Pause, Seek 0, Volume 0.5 and Speed 1.5.

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

describe("video demo", () => {
  test("C17.2/page /video declares the page state for the position and the end", async () => {
    const video = await page("video");
    expect(video.state).toEqual([
      { key: "videoPosition", scope: "page", initial: 0 },
      { key: "videoDone", scope: "page", initial: false },
    ]);
  });

  test("C17.2/page /video has one VideoPlayer on an https MP4 with its playerId and controls", async () => {
    const video = await page("video");
    const players = video.components.filter((n) => n.type === "VideoPlayer");
    expect(players.length).toBe(1);
    expect(players[0]).toMatchObject({ id: "player", kind: "primitive", childMode: "none" });
    // The encoder writes a static prop value as the bare value.
    expect(players[0]!.props).toEqual({
      url: "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4",
      playerId: "demo",
      showControls: true,
    });
  });

  test("C17.2/page the player's onProgress keeps the event's position, onComplete the end", async () => {
    const video = await page("video");
    const actions = byId(video).get("player")!.actions!;
    expect(Object.keys(actions).sort()).toEqual(["onComplete", "onProgress"]);
    expect(actions.onProgress).toEqual({
      type: "setState",
      scope: "page",
      key: "videoPosition",
      value: { type: "event", key: "position" },
    });
    // A static value is written bare in an action's value too.
    expect(actions.onComplete).toEqual({ type: "setState", scope: "page", key: "videoDone", value: true });
  });

  test("C17.2/page the five buttons send the player's actions with their params", async () => {
    const video = await page("video");
    expect(tap(video, "play")).toEqual({ type: "playVideo", playerId: "demo" });
    expect(tap(video, "pause")).toEqual({ type: "pauseVideo", playerId: "demo" });
    expect(tap(video, "seek")).toEqual({ type: "seekVideo", playerId: "demo", position: 0 });
    expect(tap(video, "volume")).toEqual({ type: "setVolume", playerId: "demo", volume: 0.5 });
    expect(tap(video, "speed")).toEqual({ type: "setPlaybackSpeed", playerId: "demo", speed: 1.5 });
  });

  test("C17.2/page the Texts show the position and the end from page state", async () => {
    const video = await page("video");
    const nodes = byId(video);
    expect(nodes.get("video-position")!.type).toBe("Text");
    expect(nodes.get("video-position")!.watches).toEqual(["videoPosition"]);
    expect(nodes.get("video-position")!.props.data).toMatchObject({
      type: "transform",
      input: { type: "state", key: "videoPosition", scope: "page" },
      by: [{ type: "template", template: "Position: {{value}} ms" }],
    });
    expect(nodes.get("video-done")!.type).toBe("Text");
    expect(nodes.get("video-done")!.watches).toEqual(["videoDone"]);
    expect(nodes.get("video-done")!.props.data).toMatchObject({
      type: "transform",
      input: { type: "state", key: "videoDone", scope: "page" },
    });
  });

  test("C17.2/page /home has a button that navigates to /video, as the map's and the voice's do", async () => {
    const home = await page("home");
    const targets = home.components
      .map((n) => n.actions?.onTap as Record<string, unknown> | undefined)
      .filter((a) => a?.type === "navigate")
      .map((a) => a!.path as string);
    // The flat node list is not in screen order.
    expect(targets.sort()).toEqual(["/map", "/video", "/voice"]);
  });
});
