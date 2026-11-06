# 09 · Implementation · native-sdk

## Front page

### In one breath
S0 sits on branch feat/native-sdk-s0, uncommitted: 7 of 8 tasks done; 23b.7 is half (warning in,
devtools listing deferred to S2). Engine 684 pass, SDK 205 pass incl. 15 action fixtures, 6 resolved
maps, Go builds. Day one, the fixtures found two client gaps: dotted state keys (fixed), stale caps.

### New for you
Nothing new.

### Trade-offs
1 needs you: commit now on the branch (no push) vs leave uncommitted; default commit on approve.
2 needs you: .pipeline/ in git (the plan's Epic 23b points at it) vs .gitignore; default commit it.
3 needs you: cloud widgets_gen.go, own chore commit in cloud vs leave uncommitted; default commit.
4 needs you: 23b.7 devtools listing, defer to S2 (SDK side) vs a _debug field now; default defer.

### Questions for you
1. Push and open PR 1 now? (default: no; stage 10 opens the PR, nothing leaves this machine yet)
2. Keep the dotted-key watch fix and test in PR 1? (default: yes; the fixture found it, it is small)
3. Pre-existing nits, tsconfig ignoreDeprecations and the missing lint script? (default: skip them)
4. Stale generated.dart semver (0.2.0 vs 0.3.1): regen it from release.sh? (default: later, 23b.14)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Tasks 23b.1-8, status and evidence
| # | Status | Evidence |
|---|---|---|
| 23b.1 | done | `schema/action.schema.json` +5 definitions (closeDialog, refetchPage, debugLog, once, always), wired into `oneOf`; `engine/test/action-schema-sync.test.ts` went red (23 vs 28) then green |
| 23b.2 | done | `static readonly targets` on Checkbox, Drawer, FloatingActionButton, InkWell, Radio, SnackBar, Tooltip; `gen-widget-registry.ts` scrapes and validates it, derives `isSupportedOnWeb`; manifest and TS registry carry `targets` on 92/92; `engine/test/widget-targets.test.ts` |
| 23b.3 | done | `tools/gen-go-registry.ts` emits `Targets []string`; `cloud/services/app-server/internal/render/widgets_gen.go` regenerated; `go build ./...` passes |
| 23b.4 | done | `schema/action-fixture.schema.json`; `schema/fixtures/actions/01..15` (12 per kind, 3 scenarios: counter, both conditional branches, server round trip with error) |
| 23b.5 | done | `ActionExecutor.onEffect` + `ActionEffect` (8 emit points, before the platform call); `sdk/test/conformance/action_fixtures_test.dart` with a stub client; 15/15 pass on unchanged fixtures |
| 23b.6 | done | `resolved` maps on fixtures 03, 05, 06, 09, 18, 22; `sdk/test/conformance/render_resolved_test.dart`; fixture 06 failed, fixed by `lookupStatePath` in the resolver and the watch snapshot; `sdk/test/watch_builder_dotted_key_test.dart` |
| 23b.7 | partial | `Platform` type, `Page.targets`, `PageDefinition.create({ targets })`, `engine/src/core/target-check.ts`, pipeline warns once per page outside production; `engine/test/target-check.test.ts`. Devtools listing needs an SDK or response transport that does not exist yet: S2 |
| 23b.8 | done | Epic 23b block with 27 rows in `.claude/plans/orcagateway-epics.md`; `docs/User_Actions.md` entry for Maven Central (Sonatype namespace, GPG key, token, four GitHub secrets) |

### Test results
engine: `bun test` 684 pass, 1 fail: the unnamed caps-412 test binds port 8080, which Docker holds on
this machine (environmental, untouched by this change). `tsc -p tsconfig.build.json --noEmit` clean.
sdk: `flutter test` 205 pass (22 conformance, 2 dotted-key); `flutter analyze` only the pre-existing
onReorder deprecation. cloud: `go build ./...` in services/app-server passes.

### Findings worth remembering
F1 The action schema lagged the TS types by five kinds; the drift test now fails on either side.
F2 The client ignored dotted state keys in both the resolver and the watch snapshot while the engine
   supports them (`getByDotPath`); render fixture 06 caught it in the first run.
F3 `sdk/lib/src/capabilities/generated.dart` said 0.2.0 while pubspec is 0.3.1; regenerated.
F4 Pre-existing: `engine/tsconfig.json` `ignoreDeprecations` rejects TS 5.6; Taskfile `engine:lint`
   calls a script that does not exist.

### Repos touched
open-source (branch feat/native-sdk-s0): 26 modified files, 10 new paths, plus `.pipeline/`; nothing
committed. cloud (main): `widgets_gen.go` modified; nothing committed. Workspace, not a repo:
`.claude/plans/orcagateway-epics.md` and `docs/User_Actions.md`.

### Verify
cd open-source/engine && bun test · cd open-source/sdk && flutter test && flutter analyze ·
bun run schema/gen-widget-registry.ts && git diff --exit-code schema/widget-registry.json
