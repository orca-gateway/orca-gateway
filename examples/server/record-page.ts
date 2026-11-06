#!/usr/bin/env bun
/**
 * Records a page exactly as the Swift SDK receives it, for the Swift tests
 * (Epic 23b, T2.3). Starts the example apps on a free port, then requests the
 * page the way OrcaClient does: caps headers first, then on 412
 * caps_vector_unknown one POST retry with `_orcaCapsVector`. A recording
 * therefore also proves the Swift caps hash is accepted by a real engine.
 *
 *   bun run examples/server/record-page.ts <appId> <path> <out.json>
 *
 * Used by `t sdk-swift:record`. Writes the page JSON with a 2-space indent
 * (to a file, because the engine logs its start line to stdout).
 */
import { writeFileSync } from "fs";
import { Engine } from "../../engine/src/core";
import { swiftCapabilityVector } from "../../schema/gen-native-capabilities";
import { counterApp } from "./counter";
import { basicActionsApp } from "./basic-actions";
import { serverActionsApp } from "./server-actions";
import { capabilityDemoApp } from "./capability-demo";

const [appId, path, out] = process.argv.slice(2);
if (!appId || !path || !out) {
  console.error("usage: bun run examples/server/record-page.ts <appId> <path> <out.json>");
  process.exit(2);
}

const engine = new Engine();
for (const app of [counterApp, basicActionsApp, serverActionsApp, capabilityDemoApp]) {
  engine.registerApp(app);
}
// Same policy as examples/server/index.ts, so recordings match the dev server.
engine.setFallbackPolicy({ default: "graceful", features: { "widget.Divider": "warn" } });
const server = await engine.start({ port: 0, cache: false });

try {
  const { vector, capsHash } = swiftCapabilityVector();
  const url = `http://localhost:${server.port}/api/v1/app/${appId}/page/${path}`;
  const headers = {
    "x-orca-platform": "iOS",
    "x-orca-sdk-version": vector.sdkSemver,
    "x-orca-caps-hash": capsHash,
  };

  let res = await fetch(url, { headers });
  if (res.status === 412) {
    const body = (await res.json()) as { error?: string };
    if (body.error !== "caps_vector_unknown") throw new Error(`unexpected 412: ${JSON.stringify(body)}`);
    res = await fetch(url, {
      method: "POST",
      headers: { ...headers, "content-type": "application/json" },
      body: JSON.stringify({ _orcaCapsVector: vector }),
    });
  }
  if (res.status !== 200) throw new Error(`${url} answered ${res.status}: ${await res.text()}`);

  writeFileSync(out, JSON.stringify(await res.json(), null, 2) + "\n");
  console.error(`recorded ${appId}/${path} -> ${out}`);
} finally {
  engine.stop();
}
