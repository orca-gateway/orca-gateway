# 09 · Implementation · native-sdk-s13

## Front page

### In one breath
group 1 of 2 · tasks: 1 green, 0 blocked · cases: 2 of 3 green (W1, W3) · every suite green
T1 `encoded()`: Swift now writes 4.0, 100.0, -0.0 as Dart does (it wrote 4, 100, -0), and "a/b".
The page POST body, executeAction's params and states, and the DevTools envelope carry 4.0.
Tests: Swift 137 (+7), iOS UI 54 + core 137, engine 701, Flutter 239, Kotlin 130 + 128, lint 0.
Not run here: Swift on Linux (Docker is not running on this Mac); the PR's CI runs it.

### New for you
nothing new

### Trade-offs
2 auto-decided: NaN's error keeps type and message, empty codingPath; keys sorted as before.

### Questions for you
1. Next: group 2, T2, an encoder that builds JSON trees directly, so a typed 4.0 in Value,
   Action or DevTools' action payload stays 4.0. (default: go; `A` starts it)

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

### Test run
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

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Nothing deploys and nothing is published. Swift on Linux was not run locally (Docker's daemon is
off on this Mac; S13 does not start it): the PR's CI jobs Core tests (swift 5.10-jammy, 6.2-noble)
run it. The writer uses no Foundation formatting, so Linux should match. The Swift fix ships with
the next `sdk-swift-v*` release through release.sh.
