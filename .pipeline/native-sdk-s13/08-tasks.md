# 08 · Tasks · native-sdk-s13

## Front page

### In one breath
tasks: 2 in 2 groups · widest group: 1 · cases: 3 of 3 placed (W1, W2, W3) · Swift only
S13 is 23b.35: Swift writes a 4.0 back as 4.0, as Dart and Kotlin do. Today it writes 4.
Group 1, T1: `encoded()` writes numbers as Dart does: request bodies and DevTools text keep 4.0.
Group 2, T2: an encoder builds JSON trees directly, so a typed 4.0 in Value or Action stays 4.0.
Checked first: Swift writes 4.0, 100.0, -0.0 as 4, 100, -0; Dart reads those back as whole numbers.

### New for you
nothing new

### Trade-offs
1 needs you: one gate per task (T1, then T2), or both as one task under one gate.
3 auto-decided: "/" unescaped as Dart; no shared fixture (all readers equate 4 and 4.0); NaN throws.

### Questions for you
1. Commands: `bun test`, `flutter test` + `flutter analyze`, `swift test` + the iOS simulator,
   `./gradlew build`. (default: as found)
2. Commits: one per task on feat/native-sdk-s13; nothing pushed before stage 10. (default: yes)
3. One gate per group (T1, then T2)? Else one merged task, one gate. (default: yes, 2 gates)

## Appendix

### Where S13 comes from
Epic row 23b.35, written at S12 gate 08 (question 5: "note it as a new epic row"): Swift's
`JSONValue.encoded()` and `JSONValue(encoding:)` go through JSONEncoder, which writes a whole Double
as `4`. Done when: "A Swift test per path (request body, typed Value, DevTools payload) pins `4.0`".
S13 started on your "Start S13" after native-sdk-s12 gate 12 (A); stages 01-07 skipped as covered by
native-sdk. Branch feat/native-sdk-s13 from main 29d77e9 (PR #19's merge), with S12's closing notes
cherry-picked (d131e25, f3ca539).

### Checked before planning (2026-11-10)
Dart `jsonEncode` (Dart 3.12.2) against Swift's `JSONEncoder` with `.sortedKeys`, as `encoded()`
uses it today (scratch programs in the session scratchpad, `s13/oracle/`):
| value | Dart | Swift today |
|---|---|---|
| 4.0 | 4.0 | 4 (Dart reads an int) |
| 100.0 | 100.0 | 100 (an int) |
| -0.0 | -0.0 | -0 (Dart reads the int 0) |
| 0.1+0.2 | 0.30000000000000004 | the same |
| 1e21 | 1e+21 | 1e+21 |
| 1e-7, 1.5e-7 | 1e-7, 1.5e-7 | 1e-07, 1.5e-07 |
| 123456789012345680000.0 | 123456789012345680000.0 | 1.2345678901234568e+20 |
| 1e-6 | 0.000001 | 1e-06 |
| "a/b" | "a/b" | "a\/b" |
| NaN | throws | throws |
Dart reads "1e+21" and "1.0E21" as doubles and "4" as an int. Dart keeps a map's insertion order;
Swift sorts keys (stable output, kept). Kotlin's `encoded()` already writes "4.0" (its exponent text,
"1.0E21", differs from Dart's but reads as a double).

### Cases (the Flutter SDK's Dart is the oracle)
- W1 `encoded()` writes every Double so Dart reads it back as a double: an integral double keeps
  ".0" (4.0, 100.0, -0.0); numbers use Dart's text (`DartFormat.double`); ints stay ints; NaN and
  infinity still throw. Keys stay sorted in today's order; "/" is written unescaped, as Dart does.
- W2 `JSONValue(encoding:)` keeps a typed Double a `.double`: an Encoder builds the JSONValue tree
  directly (no JSONEncoder round trip), so `Value.json`, `BoolExpr.json`, `Transform.json`,
  `Action.json`, the caps vector and DevTools' action payload keep 4.0, and the public
  `ValueResolver.resolve(_: Value)` with `toString` gives "4.0".
- W3 The done-when paths: the page POST body and its appState, executeAction's params, pageState
  and appState (also from the executor's serverAction), the DevTools envelope. A Swift test per
  path pins 4.0 on the wire text.
Guards: PropertyTests' round trip, the DevTools fixtures, every existing Swift test.

### Groups
Paths from the repo root.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | encoded() writes doubles as Dart does | `sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValue.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/JSONWriteTests.swift` (new) | W1, W3 | S | none |
| 2 | T2 | Tree encoder keeps a typed 4.0 | `sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValueEncoder.swift` (new) · `sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValue.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/JSONValueEncoderTests.swift` (new) | W2 | M | T1 |
Each done-when path has its task:
- Request body: T1 (W3). That is both page POST attempts' appState, executeAction's params,
  pageState and appState, and the same body when the executor's serverAction sends it.
- DevTools payload: T1 for the envelope text with an untyped payload (a state_change carrying 4.0),
  T2 for the typed action payload.
- Typed Value: T2. That is `Value/BoolExpr/Transform/Action.json`, and `ValueResolver.resolve(_:
  Value)` giving "4.0" through `toString` (ValueResolver.swift:69, :254).
T1 adds a writer next to JSONParser in JSONValue.swift. Doubles go through `DartFormat.double`, ints
through `String(i)` and strings through `CapabilityVector.jsString`, and keys use `keys.sorted()`.
NaN and infinity throw `EncodingError.invalidValue`. Its tests cover W1's table, plus a round trip
over `Gen.json` that checks each number is still an int or a double. T2 adds an Encoder that builds
the JSONValue tree directly (the twin of S12's JSONValueDecoder), and `init(encoding:)` uses it.

### Order, and why each boundary
- 1 → 2: T2 edits JSONValue.swift after T1 (`init(encoding:)` at :198, next to T1's `encoded()` at
  :190), and its DevTools test pins `"value":4.0` in envelope text that T1's writer produces. One
  file holds both write paths, so a split costs no parallelism. It puts a gate between the wire-text
  change (every request) and the Encoder (which every model test reaches through `jsonOf`,
  Fixtures.swift:40). Merging them is question 3's alternative.

### Seams
`sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValue.swift`: T1 (`encoded()`), then T2 (`init(encoding:)`),
in groups that run one after the other; no group names it twice.

### Findings while planning
F1 `JSONValue ==` is not type-strict: `.int(a) == .double(b)` compares the values
   (JSONValue.swift:104-105). PropertyTests:60, DevToolsEventTests:84, `assertJSONEqual`
   (Fixtures.swift:53) and every fixture check pass with 4 or 4.0 alike; they guard structure only.
   New cases assert the kind (`assertDouble`/`assertInt`, OrcaClientTests.swift:58-69) or the wire
   text. `Gen.double()` makes whole-number doubles (Generator.swift:38), so a kind-checking round
   trip catches today's bug.
F2 JSONEncoder is used only at JSONValue.swift:191 and :199. `encoded()` callers: OrcaClient.swift
   :137, :209, :222, DevToolsClient.swift:145; tests ActionStub.swift:46, Fixtures.swift:54-55,
   PropertyTests:60, DevToolsEventTests:83, RouterTests:48. `JSONValue(encoding:)` callers:
   Value.swift:463/467/471, Action.swift:398, DevToolsEvent.swift:116, OrcaClient.swift:219,
   Fixtures.swift:41 (`jsonOf`), OrcaClientTests:106.
F3 Unescaped "/" costs nothing: no test reads Swift's text byte for byte (every body is decoded
   first), and `CapabilityVector.jsString` (CapabilityVector.swift:65-84) already escapes as Dart and
   JSON.stringify do. `keys.sorted()` gives today's order for ASCII keys and is the order Kotlin
   copies (SwiftText.kt:65-75).
F4 T2's Encoder must merge repeated `container(keyedBy:)` calls on one encoder: `Action.encode`
   writes the payload, then asks for a keyed container again to add `type` (Action.swift:368-393);
   `.unknown` and `.custom` write a raw JSONValue at the top (Action.swift:366, Value.swift:298,
   :428). Parity case: over `Gen.value`, `Gen.action`, `Gen.node`, `JSONValue(encoding: x)` equals
   `JSONValue.decode(JSONEncoder().encode(x))`, with every `.double` leaf kept a double.
F5 After T2 a field typed Double always encodes as `.double` (`TweenSequenceItem.duration`,
   Value.swift:58; `OpenDialog.heightFactor`, Action.swift:111): a 300 on the wire comes back as
   300.0 in `.json`, as Dart's double field holds it. Equal as data, so no existing test changes.
F6 NaN and infinity: JSONEncoder throws today, so `Value.json` gives `.null` and DevTools' `data`
   is `.null` (DevToolsEvent.swift:116); kept, the Encoder throws too.
F7 With T1 alone, untyped DevTools payloads already carry 4.0: `ClientTiming.json` writes its marks
   as `.double` (DevToolsEvent.swift:64-66), so `requestStartMs` 0 goes out as "0.0", as Dart's
   double field does. The WebSocket send (DevToolsClient.swift:145) is tested only under xcodebuild,
   so T2 pins this path in core; an end-to-end check through `DevToolsStub` is not planned.
F8 No shared fixture: every reader compares as data where 4 == 4.0 (Swift F1; Dart's `equals`,
   sdk/test/conformance/devtools_events_test.dart:159; Kotlin JsonValue.kt:42-56; DevTools
   devtools/test/fixture_parse_test.dart:62). A 4.0 in a fixture would pin nothing and force edits
   in the sdk/ and sdk-kotlin/ tests.
F9 Kotlin needs nothing: `JsonValue.Double` writes "4.0" (JsonValue.kt:141-143), its models convert
   through `encodeToJsonElement` (:181), and OrcaClientTest.kt:207-232 pins "4.0" already.
F10 After T1, `ActionStub.json` serves canned replies with 4.0 intact; no file in
   `schema/fixtures/actions` holds such a number, so no fixture result changes.

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` · `cd sdk-swift
&& xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=FDE5D612-86BA-4138-A1BD-1AB2CF9E8773'`
· `cd sdk-kotlin && ./gradlew build --console=plain` · lint: Kotlin's inside its build, `cd sdk &&
flutter analyze` · typecheck: none · baseline (2026-11-10, main 29d77e9): engine 701 pass, 0 fail;
Flutter 239 passed; flutter analyze no issues; Swift 130 tests, 0 failures; iOS UI 54 + core 130,
TEST SUCCEEDED; Kotlin core 130, sdk 128, 0 failures, lint "No issues found". Green at 09: a task's
cases pass and nothing that passed here fails.

### Not planned
- An end-to-end DevTools WebSocket check through `DevToolsStub` (F7): the envelope text is pinned in
  core instead.
- Kotlin's exponent text ("1.0E21" where Dart writes "1e+21"): read as a double everywhere; not a bug.
- A shared fixture (F8).
- Row 23b.36 (the regex corners S12 left): its own slice.

### Commits on feat/native-sdk-s13 (conventional, per task on your yes to question 2)
1. chore(pipeline): native-sdk-s12 closing notes (done, cherry-picked)
2. chore(pipeline): native-sdk-s13 stage 08
3. one `fix(sdk-swift): …` commit per task, in the order they pass review
4. chore(pipeline): stage 09 onward
