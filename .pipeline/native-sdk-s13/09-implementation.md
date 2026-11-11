# 09 · Implementation · native-sdk-s13

## Front page

### In one breath
group 2 of 2 · tasks: 2 green, 0 blocked · cases: 3 of 3 green (W1, W2, W3) · every suite green
T2 tree encoder: a typed 4.0 in Value, BoolExpr, Transform, Action and DevTools' payload stays 4.0.
One quality rework: T2's tests copied T1's 4-vs-4.0 check; both now share it in Fixtures.swift.
Tests: Swift 147 (+10), iOS UI 54 + core 147, engine 701, Flutter 239, Kotlin 130 + 128, lint 0.
Not run here: Swift on Linux (Docker is not running on this Mac); the PR's CI runs it.

### New for you
nothing new

### Trade-offs
1 fixed: T2's copied test helpers (one rework, a minor widening to two test files, your rule).
5 auto-decided: NaN's error; key order; no encoder fast path; superEncoder path; `wireText` name.

### Questions for you
1. `A` approves stage 09; then 10: push, open the PR, read its CI once. (default: yes)

## Appendix

### Group 1
Commit: T1 f084f57. Nothing pushed.

#### Task T1 · encoded() writes doubles as Dart does
Files: `sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValue.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/JSONWriteTests.swift` (new)
Cases: W1, W3 → green (`swift test --filter JSONWriteTests`: 7 tests; `swift test` 137 = 130 + 7;
iOS UI 54 + core 137) · red first: all 7, 25 failures such as "4" vs "4.0" and "a\/b".
Changed: `encoded()` uses a new internal `JSONWriter` before the parser: compact text, doubles
through `DartFormat.double`, ints through `String(i)`, strings and keys through
`CapabilityVector.jsString`, members in sorted-key order; NaN and infinity throw
`EncodingError.invalidValue`. `init(encoding:)` untouched (T2's). Tests: 3 W1 (the number table
with each kind read back and NaN/inf throws; escaping and key order; a 4x150 `Gen.json` round trip
checking each number's kind) and 4 W3 (both page POST attempts, executeAction's params, pageState
and appState, the executor's serverAction, DevTools state_change and timing envelopes) on the exact
wire text. Values beyond the given table (control-character escapes, DEL raw, Int.min/max, 1e20,
5e-324, the largest double) printed by Dart 3.12.2.
Decisions: 1. NaN's error has an empty codingPath (JSONEncoder gave the path); type and message as
before · 2. members sorted by `$0.key < $1.key`, the order of `keys.sorted()` and Darwin's
`.sortedKeys` (checked on "10", "9", "B", "Z", "_x", "é") · 3. NaN/inf, key order and compact
output held at baseline, so they share tests with the failing assertions.
Review fit: pass
Review quality: pass

#### Group 1 test run
Once after the group (logs in the session scratchpad, `s13/g1-*.log`):
- `cd engine && bun test` · 701 pass, 0 fail.
- `cd sdk && flutter test` · +239: All tests passed! · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · Executed 137 tests, with 0 failures.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54, OrcaGatewayCoreTests 137, 0 failures,
  TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build --continue` · core 130, sdk 128, 0 failures · lint "No issues
  found".
Every changed file sits in T1's Files; no stray file (the untracked `sdk-kotlin/core/bin/` predates
S13 and is left as it is).

### Group 2
Commit: T2 ec1e057 (after one quality rework). Nothing pushed. Group 2 started on your standing rule
(2026-11-11): minor and patch questions approved without a stop, major ones wait for you; gate 09's
group 1 question was minor.

#### Task T2 · Tree encoder keeps a typed 4.0
Files: `sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValueEncoder.swift` (new) · `JSON/JSONValue.swift` ·
`sdk-swift/Tests/OrcaGatewayCoreTests/JSONValueEncoderTests.swift` (new); for the rework also
`JSONWriteTests.swift` (T1's) and `Support/Fixtures.swift` (a minor widening, your rule)
Cases: W2, W3 (the typed DevTools payload) → green (`swift test` 147 = 137 + 10; iOS UI 54 + core
147) · red first: 8 of 10 (the caps-shape and NaN → `.null` tests are guards, green on both paths).
Changed: an internal `JSONValueEncoder` (Encoder, single-value, keyed and unkeyed containers, a
`PathKey`) writes into a `Node` tree held by reference, so a second `container(keyedBy:)` adds to
the same object (Action's payload, then `type`). A Double becomes `.double`, an Int `.int`, an
integer too big for Int a `.double`; NaN and infinity throw `invalidValue`, as does a top-level
model that writes nothing. `init(encoding:)` returns `JSONValueEncoder.tree(of:)`; `encode(to:)`
unchanged. Tests: Value, BoolExpr, Transform, Action (payload plus `type`), the caps vector,
DevTools' payload, `resolve` + `toString` → "4.0", NaN, the containers against JSONEncoder, a
generator parity check, and the envelope text `"value":4.0`. No existing test changed.
Decisions: 1. no fast path in `JSONValue.encode(to:)`: the finite check sits in `encode(Double)`
only · 2. a nested `superEncoder` keeps the whole coding path, as `JSONValueDecoder.superDecoder()`
does (JSONEncoder's differs; error text only, no model calls it) · 3. the shared helper is
`wireText(_:)`: `text(_:)` already exists in TransformTests.swift:347.
Review fit: pass
Review quality: T2's tests copied T1's `text(_:)` and `sameKinds(_:_:)` (the 4-vs-4.0 oracle), fixed
(one rework: free functions in Support/Fixtures.swift, a pure move, 147 tests unchanged)

### Test run
Once after group 2 (logs `s13/g2-*.log`), Swift and iOS again after T2's rework (`s13/g2b-*.log`):
- `cd engine && bun test` · 701 pass, 0 fail.
- `cd sdk && flutter test` · +239: All tests passed! · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · Executed 147 tests, with 0 failures.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54, OrcaGatewayCoreTests 147, 0 failures,
  TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` (tests forced to rerun) · core 130, sdk 128, 0 failures · lint
  "No issues found".
Every changed file sits in T2's Files (with the rework's two); the untracked `sdk-kotlin/core/bin/`
predates S13.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Nothing deploys and nothing is published. Swift on Linux was not run locally (Docker's daemon is
off on this Mac; S13 does not start it): the PR's CI jobs Core tests (swift 5.10-jammy, 6.2-noble)
run it. The writer uses no Foundation formatting, so Linux should match. The Swift fix ships with
the next `sdk-swift-v*` release through release.sh.
