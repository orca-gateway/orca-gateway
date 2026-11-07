#!/usr/bin/env bun
/**
 * Records a page exactly as a native SDK receives it, for the Swift and Kotlin
 * tests (Epic 23b, T2.3 and T6.3). Starts the example apps on a free port,
 * then requests the page the way OrcaClient does: caps headers first, then on
 * 412 caps_vector_unknown one POST retry with `_orcaCapsVector`. A recording
 * therefore also proves the SDK's caps hash is accepted by a real engine.
 *
 *   bun run examples/server/record-page.ts <appId> <path> <out.json>
 *       [--policy graceful|warn|require] [--min-sdk <version>] [--sdk-version <version>]
 *       [--sdk swift|kotlin]
 *
 * `--sdk` picks the caps vector and `x-orca-platform` (swift and iOS when left
 * out; kotlin sends Android). `--policy` sets the default fallback policy
 * (graceful when left out), and `--min-sdk` the app's minimum SDK version.
 * Below it the engine answers 426; the recording is then the whole 426 body,
 * `{error, minSdkVersion, clientSdkVersion, page}`. `--sdk-version` replaces
 * the `x-orca-sdk-version` header (the SDK's own version when left out).
 *
 * Used by `t sdk-swift:record` and `t sdk-kotlin:record`. Writes the page JSON
 * with a 2-space indent (to a file, because the engine logs its start line to
 * stdout).
 */
import { writeFileSync } from "fs";
import { Engine } from "../../engine/src/core";
import { kotlinCapabilityVector, swiftCapabilityVector } from "../../schema/gen-native-capabilities";
import { counterApp } from "./counter";
import { basicActionsApp } from "./basic-actions";
import { serverActionsApp } from "./server-actions";
import { capabilityDemoApp } from "./capability-demo";
import { nativeWidgetsApp } from "./native-widgets";

const args = process.argv.slice(2);
function option(name: string): string | undefined {
  const i = args.indexOf(name);
  if (i < 0) return undefined;
  const value = args[i + 1];
  args.splice(i, 2);
  return value;
}
const policy = option("--policy") ?? "graceful";
const minSdk = option("--min-sdk");
const sdkVersion = option("--sdk-version");
const sdk = option("--sdk") ?? "swift";
const [appId, path, out] = args;
if (!appId || !path || !out || !["graceful", "warn", "require"].includes(policy) || !["swift", "kotlin"].includes(sdk)) {
  console.error(
    "usage: bun run examples/server/record-page.ts <appId> <path> <out.json> " +
      "[--policy graceful|warn|require] [--min-sdk <version>] [--sdk-version <version>] [--sdk swift|kotlin]",
  );
  process.exit(2);
}

const engine = new Engine();
for (const app of [counterApp, basicActionsApp, serverActionsApp, capabilityDemoApp, nativeWidgetsApp]) {
  engine.registerApp(app);
}
// Same policy as examples/server/index.ts, so recordings match the dev server.
engine.setFallbackPolicy({
  default: policy as "graceful" | "warn" | "require",
  features: { "widget.Divider": "warn" },
});
if (minSdk) engine.setMinSdkVersion({ appDefault: minSdk });
const server = await engine.start({ port: 0, cache: false });

try {
  // The caps vector and platform of the SDK whose tests load the page.
  const { vector, capsHash } = sdk === "kotlin" ? kotlinCapabilityVector() : swiftCapabilityVector();
  const url = `http://localhost:${server.port}/api/v1/app/${appId}/page/${path}`;
  const headers = {
    "x-orca-platform": sdk === "kotlin" ? "Android" : "iOS",
    "x-orca-sdk-version": sdkVersion ?? vector.sdkSemver,
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
  const expected = minSdk ? 426 : 200;
  if (res.status !== expected) throw new Error(`${url} answered ${res.status}: ${await res.text()}`);

  writeFileSync(out, JSON.stringify(await res.json(), null, 2) + "\n");
  console.error(`recorded ${appId}/${path} -> ${out}`);
} finally {
  engine.stop();
}
