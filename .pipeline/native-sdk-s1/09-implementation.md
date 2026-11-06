# 09 · Implementation · native-sdk-s1

## Front page

### In one breath
S1 is built and committed on feat/native-sdk-s1: 6 commits, one per task, nothing pushed. The T1
group passes 49/49 under swift test on macOS and on Linux with Swift 5.10 and 6.2. The schema drift
checks are clean, and generated.dart comes out byte-identical after the shared-scraper refactor.

### New for you
Nothing new.

### Trade-offs
1 auto-decided: commit on the slice branch, no push (your call, 2026-11-06, native-sdk 09).
2 needs you: CI toolchains, Swift 5.10 plus 6.2 vs 6.2 only; default both (5.10 guards the floor).
3 needs you: formatDate, follow the Dart engine vs skip it like the Dart SDK; default engine.
4 needs you: Swift where Dart throws, yield null vs trap; default null (a trap kills the app).

### Questions for you
1. Push and open PR 2 at stage 10? (default: yes, as for PR 1; nothing merged or published)
2. The Dart SDK skips formatDate but advertises it: file a follow-up? (default: yes, a card)
3. Add the Dart generated.dart drift check to schema.yml? (default: follow-up, not in PR 2)
4. Tick Epic 23b rows in the plan? (default: no; the plan has no status column, S5 ticks it)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Tasks 23b.9-14, status and evidence
| # | Status | Evidence |
|---|---|---|
| 23b.9 | done | `sdk-swift/Package.swift` (tools 5.9, `.iOS(.v16)`, `.macOS(.v13)`), `OrcaGatewayCore` (Foundation only) and `OrcaGateway` (SwiftUI behind `#if canImport(SwiftUI)`, re-exports the core); `VERSION` = 0.1.0-alpha.1; README with the experimental banner; commit edeb720 |
| 23b.10 | done | `JSONValue` (int/double kept apart, Dart number equality); hand-written Codable for `Value` + `Transform` + `BoolExpr`, `Action` (28 kinds, `custom:*` and unknown kept verbatim), `ComponentNode`, `StateDefinition`, `PageResponse` (extra members kept). T1.1: 24 render and 15 action fixtures round-trip JSON-equal; property tests over 4 seeds × 150 for node, page, value, action, JSON; commit 3deeefa |
| 23b.11 | done | `ValueResolver` ported line by line from the Dart resolver, plus `DartFormat` (Dart `'$x'`, `toStringAsFixed`). T1.2: resolved maps of 03/05/06/09/18/22 match; T1.3: 110 table rows covering all 31 advertised transforms plus `toggle`, and the add/subtract, split/join and trim properties; T1.4: the 13 ops including Dart's null semantics, and the Dart 11.7/11.9 cases; commit 1db8e48 |
| 23b.12 | done | `StoreState` (pure `setting`/`merging`), `ElmStore` (merged view, watches on dotted paths, notify only on change, `seed` as `initPage`), `ActionEffect` as `{type, ...payload}`, `Reducer` seam for S3. T1.5: 7 tests; commit 6a0db59 |
| 23b.13 | done | `schema/gen-native-capabilities.ts` → `Generated.swift` (15 widgets from `sdk-swift/capabilities.json`, each checked for the ios target; 12 action kinds; 9/31/13 scraped) plus `capsHash` from the engine's `canonicalizeVector`. Scraping moved to `schema/caps-sources.ts`, which `gen-sdk-capabilities.ts` now also uses; generated.dart is byte-identical. `codegen.ts` step 3; `schema.yml` diffs `Generated.swift`. T1.6: 8 tests incl. the engine's pinned hash c71ebd59…; commit 03f86d3 |
| 23b.14 | done | `t sdk-swift:test`, `t sdk-swift:gen`; `.github/workflows/sdk-swift.yml`: ubuntu, `swift:5.10-jammy` and `swift:6.2-noble` containers, on `sdk-swift/**` and `schema/**`; commit ab9a3c8 |

### Test results
macOS (Swift 6.4.2): `swift test` 49 pass, 0 fail. Linux, docker `swift:5.10-jammy` and
`swift:6.2-noble`: `swift build --build-tests` without warnings, 49 pass. A mutation check (a wrong
modulo row) makes the transform table fail with the row named, then restored. Schema job steps
run locally: widget registry no drift, `Generated.swift` no drift, generated.dart unchanged; engine
`capability-vector-cache.test.ts` 14 pass; the three generator scripts type-check under `tsc --strict`.

### Findings worth remembering
F1 The Dart SDK registers `toggle` (not in the engine) and lacks `formatDate` while its caps vector,
   scraped from the engine, advertises it; a `TV.formatDate` silently no-ops on Flutter today.
F2 Dart's `filter` transform evaluates its expression without binding the item, so it keeps all
   items or none. Swift mirrors it for parity; the engine's intent is probably per-item.
F3 JSONDecoder reads `3.0` as an int. Harmless on real traffic, since the engine (JavaScript) never
   emits `3.0`; fixtures compare with number equality.
F4 First port draft could trap where Dart throws (`Int(1e300)`, `Int.min % -1`, NaN colour);
   caught in review, now clamped, with a hostile-input test.
F5 `schema.yml` never diffed the Dart `generated.dart`; the Swift file is now diffed, Dart is not.

### Repos touched
open-source only, branch feat/native-sdk-s1 (from main at f09451c): 32 files, +4420/−97, plus
`.pipeline/native-sdk-s1/`. Nothing pushed. No `cloud/` change: the Go registry reads the manifest,
which is unchanged.

### Verify
cd sdk-swift && swift test · bun run schema/codegen.ts && git diff --exit-code ·
docker run --rm -v "$PWD":/src:ro swift:5.10-jammy … swift test (see sdk-swift.yml)
