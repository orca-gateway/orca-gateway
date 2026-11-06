# 11 · Release · native-sdk-s2

## Front page

### In one breath
A plan for you to run; I never publish. From the main checkout, after `git pull`, run
`./scripts/release.sh`, pick engine then sdk: engine 0.3.2 → 0.3.3 (npmjs), sdk 0.3.1 → 0.3.2.
The sdk release also ships June work never released: analytics batching, a device id per request.

### New for you
Nothing new.

### Trade-offs
1 needs you: sdk patch 0.3.2 (plugins' ^0.3.0 still fits) or minor 0.4.0 (new features, but all four
  plugins then need constraint bumps and releases)? Default: patch.
2 needs you: June's sdk work ships too: OrcaAnalytics and the x-orca-device-id header
  (identifierForVendor or ANDROID_ID, always on). Ship it, or hold the sdk? Default: ship.
3 auto-decided: plugins stay unreleased; their web stubs need this sdk first (outside your call).

### Questions for you
1. CHANGELOGs are stale (engine still says "0.3.2 - Unreleased"). I open a small PR with entries
   for engine 0.3.3 and sdk 0.3.2, you merge it, then release? (default: yes)
2. Tell me when release.sh is done; stage 12 then checks npmjs, pub.dev, tags and main CI.
   (default: yes; "later" means 12 records main green and notes the release as pending)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### Why this stage runs
`config.json` skips 11 by default. At gate 10 you approved trade-off 2 with "A", which picked a
release now that PR #4 is in. That overrides the default skip, as native-sdk 10's earlier call
"publish after S2" intended.

### What is unreleased (since each package's last tag, up to main at 022b45f)
| Package | Last tag | Published now | Unreleased |
|---|---|---|---|
| engine | engine-v0.3.2 | npmjs 0.3.2 | 5153c3f S0 contract: widget `targets`, `target-check.ts` (off-target warnings), platform types, the action schema sync test; 17 files |
| sdk | sdk-v0.3.1 | pub.dev 0.3.1 | bb95c01 formatDate registered (#3); 8a4a94a onReorder lint; 5153c3f S0 (effect sink, fixtures); and from June, never released: 0632b06 OrcaAnalytics + device id (Epics 47.4, 48), 90b1d35 `OrcaWebStub` (Epic 38.5) |
| orca_google_map, orca_video_player, orca_voice_recorder | *-v0.2.1 | pub.dev 0.2.1 | 90b1d35 branded web stubs, which use `OrcaWebStub` from the sdk |
| orca_push_notification | *-v0.2.1 | pub.dev 0.2.1 | a lockfile refresh only |
| cli, devtools | cli-v0.2.0, devtools-v0.2.1+1 | | nothing |

sdk-v0.3.1 was a hotfix cut from the 0.3.0 tag (9836839 merged it back), so the June commits on
main skipped it. That is why the sdk carries more than this epic.

### Trade-off 1: patch or minor
In 0.x, the project has bumped patch so far, and the plugins pin `orca_gateway: ^0.3.0`. A patch
(0.3.2) keeps every plugin resolvable. A minor (0.4.0) is the stricter semver reading of new
features, but CLAUDE.md requires each plugin's constraint to be bumped and the plugins released
after the sdk, or consumers hit unresolvable versions.

### Trade-off 2: what June's sdk work does
- `OrcaAnalytics` is a batched, best-effort emitter. `OrcaClient.sendEvents` POSTs batches to
  the cloud `/events` endpoint.
- `OrcaApp` resolves an anonymous per-install id at boot, even without session tracking
  (`sdk/lib/src/widgets/orca_app.dart:278-283`, `:339-346`), and it rides on every request as
  `x-orca-device-id`. App developers see a new header reach their server. It is the MAU signal
  for the cloud.
- To hold the sdk instead: release only the engine now, and decide on the sdk when the cloud
  side is ready.

### Trade-off 3: plugins
The three web-stub plugins call `OrcaWebStub`, which first ships in this sdk. Releasing them
later needs `orca_gateway: ^0.3.2` (not `^0.3.0`) in their pubspecs, and the sdk listed before
them at the release prompt. They were not part of your call, so I leave them.

### Pre-flight (checked here, 2026-11-06)
- `~/.npmrc` has no `@orca-gateway:registry` mapping, and `engine/package.json` `publishConfig`
  is npmjs with `access: public`. npmjs lists 0.3.0, 0.3.1 and 0.3.2.
- release.sh regenerates `sdk/lib/src/capabilities/generated.dart` (kSdkSemver) on an sdk bump,
  so Schema CI stays green. Nothing in the engine embeds its version.
- release.sh requires a clean tree and warns off main. Run it from
  `/Users/amrebada/workspace/orca-gateway/open-source` on `main`, not from this worktree.
- At the prompt: select engine and sdk (`1,2`), press Enter for patch on both, then `y`.
- Logins: `npm login` against registry.npmjs.org, and `dart pub login`.

### Local state
This worktree's branch `feat/native-sdk-s2` is merged. The pipeline-only commits from gate 10
rounds 2-4 and this stage move to the S3 branch, which is cut from main.

### Not in this release
The Swift SDK is not releasable until S5's mirror exists, and its `VERSION` stays
0.1.0-alpha.1.
