# 08 · Tasks · native-sdk

## Front page

### In one breath
27 tasks in 7 PRs, one per slice, written as Epic 23b rows in the plan's own format. The first PR
touches only schema, codegen and fixtures, no Swift: action schema re-sync to 28 kinds, targets on
92 widgets, 15 action fixtures, resolved maps. Approving this card unlocks code; S0 starts.

### New for you
Nothing new.

### Trade-offs
1 needs you: first PR, S0 alone (schema, targets, fixtures) vs S0 plus S1; default S0 alone.
2 needs you: PR shape, one PR per slice (7, tasks as rows) vs one per task (27); default per slice.
3 needs you: plan docs, Epic 23b rows and User_Actions stub in PR 1 vs at publish; default PR 1.
4 needs you: iOS example, an examples/app-ios project vs previews inside sdk-swift; default app-ios.

### Questions for you
1. Branches? (default: feat/native-sdk-s0 to s6 off main, one PR each, conventional commits)
2. Swift version source? (default: sdk-swift/VERSION, bumped by release.sh, emitted as a constant)
3. Review of PR 1? (default: you, via /code-review; schema drift and fixture jobs must be green)
4. Stop or go point? (default: after S2, when the counter page runs on a simulator; S3 only on go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Epic 23b: Native SDKs (SwiftUI + Compose)
**Goal**: iOS and Android teams that will not adopt Flutter run the same Orca backend with identical
state and behaviour; the look follows per-widget targets.
**Deliverable**: `orca-gateway-swift` 0.1.0-alpha.1 resolves via SPM and runs counter, basic-actions,
server-actions and capability-demo against an unchanged Bun server; Compose repeats it from the same
fixtures. Decisions and rationale: `open-source/.pipeline/native-sdk/` stages 01-07.

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 23b.1 | Re-sync `action.schema.json` with `engine/src/types/action.ts` | 28 kinds on both sides; a bun test fails when either gains a kind the other lacks (T0.1) |
| 23b.2 | `static readonly targets` on widget classes, read by `gen-widget-registry.ts` | Manifest has `targets` on all 92; default `["flutter","web","android","ios"]`; the eight iOS orphans omit `ios`; `isSupportedOnWeb` derived from targets; `schema.yml` diff green (T0.2) |
| 23b.3 | `tools/gen-go-registry.ts` carries `targets` | Go registry gains the field, nothing else changes; cloud build untouched |
| 23b.4 | `schema/fixtures/actions/` format, 12 per-kind cases, 3 scenarios | JSON schema for action fixtures; files `NN_<kind>.json`; documented in `schema/` README (T0.3) |
| 23b.5 | Flutter SDK runner for action fixtures | `flutter test` loads `../schema/fixtures/actions` and passes all 15 unchanged |
| 23b.6 | `resolved` map in render fixtures that carry state Values | Fixtures with state Values gain `resolved`; Flutter resolver asserts them (T0.4) |
| 23b.7 | Page `targets` and encoder off-target warning | `PageDefinition.create({ targets })` accepted; encoder logs once per page in dev; devtools error screen lists it |
| 23b.8 | Epic 23b rows in the plan; `User_Actions.md` stub for Maven Central | Rows present; entry titled with Sonatype and GPG steps marked "complete at S6" |
| 23b.9 | `sdk-swift/` package skeleton | `Package.swift` (iOS 16; targets `OrcaGatewayCore` pure Swift, `OrcaGateway` UI), `VERSION`, README with the experimental banner |
| 23b.10 | Models and Codable: ComponentNode, Value, Action, PageResponse | T1.1 round trip on all 24 render fixtures; property test decode(encode(n)) == n |
| 23b.11 | ValueResolver, 31 transforms, 13 BoolExpr ops | T1.2 to T1.4 green, including the Dart null semantics |
| 23b.12 | ElmStore with page and app scopes and watches | T1.5 |
| 23b.13 | `gen-native-capabilities.ts` emits the Swift caps file and hash | T1.6; `schema.yml` diffs the generated file |
| 23b.14 | Taskfile `sdk-swift:test`; CI job on ubuntu with the Swift toolchain | `t sdk-swift:test` passes; job runs on PRs touching `sdk-swift/` or `schema/` |
| 23b.15 | `OrcaClient`: headers and the 412 caps handshake | T2.1, T2.2 against a fixture-backed stub |
| 23b.16 | Renderer, Registry, the 15 core widgets, safe degrade | T2.3, T2.5 |
| 23b.17 | `OrcaApp` root view, one NavigationStack, toast presentation | Counter page on a simulator; T2.4 golden |
| 23b.18 | `examples/app-ios` Xcode project on a path dependency | Opens and runs counter against `t example:dev:server` |
| 23b.19 | macOS CI job, nightly and on release tags | T2 green on macOS |
| 23b.20 | ActionExecutor, 12 kinds, effects out | T3.1: all action fixtures pass in Swift |
| 23b.21 | Effect adapters: navigation, system (openUrl, clipboard, share), serverAction POST | T3.2, T3.3 |
| 23b.22 | basic-actions and server-actions on a simulator | T3.4 |
| 23b.23 | FallbackPrompt, the three policies, 426, debug placeholder | T4.1 to T4.3; capability-demo runs |
| 23b.24 | Six extra widgets: Icon, Image, Container, Expanded, Spacer, TextField | Their `targets` gain `ios`; all four examples still green |
| 23b.25 | `release.sh` `mirror` publisher and subtree-split CI job | Tag `0.1.0-alpha.1` on `orca-gateway-swift`; T5.1 from a clean machine |
| 23b.26 | Docs: docs-site page "iOS SDK (alpha)", README banner, Epic row ticked | T5.2 |
| 23b.27 | `sdk-kotlin/`: repeat 23b.9 to 23b.24 with Gradle, kotlinx.serialization, Compose M3; Maven Central publisher; Sonatype steps in `User_Actions.md` | T6 green; `com.orcagateway:sdk:0.1.0-alpha.1` resolves |

### PR map
PR 1 = 23b.1-8 (S0) · PR 2 = 23b.9-14 (S1) · PR 3 = 23b.15-19 (S2) · PR 4 = 23b.20-22 (S3) ·
PR 5 = 23b.23-24 (S4) · PR 6 = 23b.25-26 (S5) · PR 7+ = 23b.27 (S6, likely split per layer).

### Not in this epic
Offline and static flows, plugins, devtools WebSocket, telemetry, animations, design tokens, SF Symbols
map, TS types per target, the 16 deferred action kinds. Each degrades via targets until it lands.
