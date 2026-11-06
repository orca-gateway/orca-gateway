# 08 · Tasks · native-sdk-s1

## Front page

### In one breath
S1 is PR 2: six rows, 23b.9 to 23b.14, reused from native-sdk 08. It adds a Swift package with a
pure core (models, resolver, store, caps), a caps generator and an ubuntu CI job. No UI, no
executor. Done means the T1 tests pass under `swift test` here and on CI. Approving unlocks code.

### New for you
Nothing new.

### Trade-offs
1 needs you: caps widgets, all 85 ios targets vs ios targets the Swift build draws; default draws.
2 needs you: models, hand-written Codable vs generated from the JSON schemas; default hand-written.
3 needs you: property tests, seeded generator in the tests vs SwiftCheck; default seeded, no deps.
4 needs you: Swift floor, tools 5.9 (Xcode 15+) vs 6.0 strict concurrency; default 5.9.

### Questions for you
1. Branch and merge? (default: feat/native-sdk-s1 off main, PR 2 squash-merged per gate 12)
2. First VERSION? (default: 0.1.0-alpha.1, the planned alpha; release.sh learns sdk-swift in S5)
3. Prop-name constants now? (default: no, they land with the views in S2; S1 emits caps and hash)
4. Unknown or custom action kinds on decode? (default: kept as raw JSON, never a decode error)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Rows, reused from `.pipeline/native-sdk/08-tasks.md` lines 46-51
| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 23b.9 | `sdk-swift/` package skeleton | `Package.swift` (iOS 16; targets `OrcaGatewayCore` pure Swift, `OrcaGateway` UI), `VERSION`, README with the experimental banner |
| 23b.10 | Models and Codable: ComponentNode, Value, Action, PageResponse | T1.1 round trip on all 24 render fixtures; property test decode(encode(n)) == n |
| 23b.11 | ValueResolver, 31 transforms, 13 BoolExpr ops | T1.2 to T1.4 green, including the Dart null semantics |
| 23b.12 | ElmStore with page and app scopes and watches | T1.5 |
| 23b.13 | `gen-native-capabilities.ts` emits the Swift caps file and hash | T1.6; `schema.yml` diffs the generated file |
| 23b.14 | Taskfile `sdk-swift:test`; CI job on ubuntu with the Swift toolchain | `t sdk-swift:test` passes; job runs on PRs touching `sdk-swift/` or `schema/` |

### Trade-off 1 in detail: what the Swift caps vector advertises
The manifest gives 85 widgets an `ios` target: the widgets iOS is meant to draw eventually. The Dart
caps vector lists every widget because the Flutter SDK draws every widget. The server degrades any
widget missing from a client's vector (render fixtures 12 to 14), and stage 06 relies on that: "the
server degrades it". If the Swift vector listed all 85 while S2 draws 15, the server would stop
degrading and the client would render 70 blank nodes. Default: the generator reads
`sdk-swift/capabilities.json`, a list of widgets and action kinds the Swift build implements. It
fails when a listed widget lacks the `ios` target, then emits ios-targets ∩ list. The list starts with
the 15 widgets S2 draws and the 12 alpha action kinds; S4 adds the six extras. Value kinds,
transforms and ops are scraped like the Dart generator does (all 9, 31, 13). T1.6 then reads: every
advertised widget has the `ios` target, the vector equals the list, and Swift canonicalisation hashes
to the value the generator computed with the engine's own `canonicalizeVector`.

### Trade-off 2: models
Stage 06 decided "caps vector and prop names first; decoders later". The wire types are small sum
types: Value (9 kinds), Action (28 kinds plus `custom:*`), ComponentNode, PageResponse. Props are
free-form JSON with Values embedded, as in Dart, so a generic `JSONValue` keeps int and double apart
and round-trips byte-equal content. Generated per-widget prop decoders stay a later step.

### Package shape
```
sdk-swift/
  Package.swift            swift-tools-version 5.9; .iOS(.v16), .macOS(.v13)
  VERSION                  0.1.0-alpha.1
  README.md                experimental banner
  capabilities.json        widgets and action kinds the Swift build implements
  Sources/OrcaGatewayCore/ JSONValue, Value, Action, ComponentNode, PageResponse,
                           ValueResolver (+ Transforms, BoolExpr), ElmStore, ActionEffect,
                           Capabilities/Generated.swift (generated), SHA256
  Sources/OrcaGateway/     placeholder SwiftUI module behind #if canImport(SwiftUI)
  Tests/OrcaGatewayCoreTests/  T1.1 to T1.6; fixtures read from ../schema at run time
```
`OrcaGatewayCore` imports Foundation only. The UI target compiles to an empty module on Linux so
`swift test` builds the whole package there.

### Store and effects (what S2's executor needs)
`ElmStore`: page and app scopes as `JSONValue` maps, dotted-key read and write (`lookupStatePath`),
`subscribe(keys:)` returning a token, `commit(_:)` that diffs old and new state and notifies only
subscribers whose watched key changed (a parent or child path of a changed key counts as changed).
`ActionEffect` mirrors the Dart enum as data (`type` plus payload) so fixtures compare effects as JSON.
Reducers stay pure functions `(State, Action) -> (State, [ActionEffect])`; S3 fills them in.

### CI
`.github/workflows/sdk-swift.yml`: ubuntu-latest in the official `swift` container, on PRs and pushes
touching `sdk-swift/**` or `schema/**`; runs `swift test` in `sdk-swift/`. `schema.yml` regenerates
`Generated.swift` and fails on drift; its path filter gains `sdk-swift/VERSION` and
`sdk-swift/capabilities.json`. Taskfile: `sdk-swift:test`, `sdk-swift:gen`.

### Commits on feat/native-sdk-s1 (conventional, squashed at merge)
1 chore(pipeline): native-sdk-s1 stages 01-08 · 2 feat(sdk-swift): package skeleton (23b.9) ·
3 feat(sdk-swift): wire models and Codable (23b.10) · 4 feat(sdk-swift): ValueResolver (23b.11) ·
5 feat(sdk-swift): ElmStore and effects (23b.12) · 6 feat(schema): gen-native-capabilities (23b.13) ·
7 ci(sdk-swift): Taskfile task and ubuntu job (23b.14) · 8 chore(pipeline): stage 09 onward.

### Verify
`cd sdk-swift && swift test` · `bun run schema/gen-native-capabilities.ts && git diff --exit-code
sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift` · `bun run
schema/gen-widget-registry.ts && git diff --exit-code schema/widget-registry.json` · the Linux build
once locally in `docker run swift` before pushing.

### Not in S1
OrcaClient and the 412 handshake, renderer, views, executor bodies (S2, S3), release.sh mirror (S5),
the Dart `generated.dart` drift check (found while reading `schema.yml`; a follow-up, not this PR).
