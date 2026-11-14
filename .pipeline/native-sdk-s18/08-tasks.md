# 08 · Tasks · native-sdk-s18

## Front page

### In one breath
tasks: 3 in 3 groups · widest group: 1 · cases: 4 of 4 placed · Swift only, Kotlin unchanged
S18 is 23b.41. A probe (Dart 3.14, bun, Swift and Kotlin on 6 runners) split the row in two.
Dart's quirk is Dart's bug: with `|` in `(?i:…)`, all but the last alternative ignore the `i`.
bun and both SDKs follow the spec there; Flutter hands the pattern to Dart as is (question 4).
Swift's two escape corners are real; Kotlin and bun give Dart's value on every row.
G1: an escaped pair is one member in a class. G2: a lone half matches nothing. G3: fixture 39.

### New for you
nothing new

### Trade-offs
1 needs you: Dart's modifier bug, spec (default) vs emulate it (question 4) · 2 auto-decided

### Questions for you
1. Commands: every suite as at S17; Swift also in Linux 5.10/6.2; Kotlin on JDK 17/21/25 in G3.
   (default: as found)
2. Commits: one per task on feat/native-sdk-s18; nothing pushed before 10. (default: yes)
3. One gate per group, 3 groups. (default: yes)
4. Dart's quirk: both SDKs stay on the spec, as the engine; row 23b.41 records it as Flutter's
   known difference. Emulating Dart's bug is large and breaks when Dart fixes it. (default: spec)
5. T2 changes the written text two S17 rows pin for a lone half; values stay. (default: yes)
6. At close, propose: Flutter reads `|` in modifier groups as the spec; the unset-reference idea.
   (default: yes, at gate 12)

## Appendix

### Where S18 comes from
Epic row 23b.41, added at S17 gate 12: "Native SDKs match Dart in three regex corners older than S17": Dart's
`(?i:(.)\1|x)` quirk, Swift refusing a class range whose ends are escaped surrogate pairs, and Swift joining a
4-digit high-half escape and a braced low-half escape into one letter. Done when: "A TransformTests /
TransformTest row per corner with Dart's printed value". S18 started on your "Start 23b.41"; stages 01-07
skipped as covered by native-sdk. Branch feat/native-sdk-s18 from S17's close commit (on main cbc4b0f, PR #25's
merge).

### Checked before planning (2026-11-14)
Three probes in the session scratchpad (`s18/`: gen.py, cmp.py, diff2.py; `q2/`, `q3/`), Dart 3.14.0 against bun
(the engine), Swift (macOS; swift:6.2-noble and swift:5.10-jammy containers) and Kotlin (JDK 17, 21, 25):
3 108 rows over the quirk and the escape corners, 152 rows pinning the quirk's rule, 800 rows of a term at each
position of 1-4 alternatives.
- **The quirk is Dart's bug, and wider than the row says.** Inside `(?i:…)`, `(?-i:…)`, `(?s:…)` or `(?m:…)`, a
  `|` (at the group's top or nested deeper) makes Dart read some alternatives with the flags outside the group:
  - letters, escapes, quantified atoms, lookarounds and backreferences in every alternative but the last
    (`(?i:a|x)` g on "A": Dart unchanged; `(?i:x|a)`: "#"; `(?i:x|(.)\1|y)` gu on "Aa": unchanged);
  - classes and `.` in every alternative but the first (`(?i:x|[a])` g on "A": unchanged);
  - Dart's own disjunction optimizations add more (`(?i:a|x|y)` g on "A": "#", three one-letter alternatives).
  A group without `|` inside is read right (`(?i:(.)\1)`, `(?:(?i:a)|(?i:x))`). bun and both SDKs follow
  ECMAScript on every such row. The Flutter SDK hands the pattern to Dart's RegExp as is
  (sdk/lib/src/state/value_resolver.dart:497), so Flutter apps see the bug (question 4).
- **Swift, E1:** with `u`, a class range whose upper end is an escaped pair (two `\uHHHH`) is refused (null);
  Dart reads the pair as one code point. Example: `[` pair(𐐀) `-` pair(𐐧) `]` giu on 𐐨 gives "#" in Dart.
  Its own lower end, or a braced or literal upper end, works today by accident (ICU joins the halves it writes).
  macOS, Linux 6.2 and 5.10 alike.
- **Swift, E2:** with `u`, a high half and a low half spelled by escapes Dart does not read as a pair (one braced:
  `\uD801` then `\u{DC00}`, or `\u{D801}` then a 4-digit low half) are two lone halves in Dart and match nothing in
  a string of whole pairs; Swift writes them side by side and ICU joins them into 𐐀 ("#"). Also with `+`, inside
  `(?i:…)`, after `x`, for 😀, and in a class (macOS and Linux 6.2; 5.10's ICU does not join inside a class).
- Kotlin (JDK 17, 21, 25) and bun give Dart's value on every E1 and E2 row: S18 has no Kotlin code.
- Found in passing, already a known difference since S15: a backreference to a group that takes part or not only
  at run time (`(?:(a)|b)\1` on "b": Dart and bun "#", both SDKs unchanged). An empty marker group inside the
  group, and `(?:\M\1|(?!\M))` for the reference, may close it on ICU and the JVM; not tried (for close).
Baseline: S17's group 4 run on this same code (cbc4b0f's tree, 2026-11-14): engine 705 pass, 1 fail (EADDRINUSE
on :8080, Docker) · Flutter +245 · analyze no issues · Swift 225 (macOS, Linux 6.2, 5.10) · iOS 54 + 225 ·
Kotlin core 226, sdk 128 on JDK 17, 21, 25 · lint no issues.

### Design (written here; 05-07 skipped)
In full in the session scratchpad (`s18/design.md`), pasted to the planner.
1. With `u`, a class member that is an escaped pair (a high half's `\uHHHH` then a low half's) is one member, the
   code point it spells, as outside a class, so a range compares code points; its ends are written braced.
   Without `u` as today (S16's halves).
2. With `u`, a lone half (an escape that spells a surrogate and is not half of such a pair) matches nothing in a
   Swift string, which holds no lone half. It is written so that ICU cannot join it to a half beside it: outside
   a class as `(?:(?!))`, which a quantifier may follow; in a class it adds nothing (a class left empty is
   `(?:(?!))`, negated `[\s\S]`, as `[]` and `[^]` are); a range over the surrogate block keeps its parts outside it.
3. Everything else as today: no `u`; two `\uHHHH` that make a pair (one letter outside a class; now inside too).
4. Kotlin: no change. Dart's quirk: no change in either SDK (question 4).
5. Render fixture 39 pins E1 and E2 rows where Dart, bun and both SDKs agree on every runner.

### Cases (Dart 3.14's values; "unchanged" means no match; A is 𐐀 U+10400, a is 𐐨 U+10428, Z is 𐐧 U+10427)
- E1 Ranges with an escaped pair at an end, `u`: `[`P(A)`-`P(Z)`]` giu on A, a, "Ax", "a"+A+"b" → "#", "#", "#x",
  "a#b"; gu on a → unchanged; the negated class giu on "Ax" → "A#", on "x" → "#"; braced, literal and mixed ends;
  the emoji range P(😀)-P(U+1F64F) giu on 😀 → "#"; P(A)-P(A) giu on a → "#"; with `+` on "AZ" → "#". Out of
  order (P(Z)-P(A)) stays null, as in Dart. (P(c): the two `\uHHHH` of c's halves.)
- E2 Lone halves, `u`: `\uD801\u{DC00}`, `\u{D801}\uDC00`, `\u{D801}\u{DC00}`, `\uD801\u{0DC00}`, with `+` after,
  inside `(?i:…)`, after `x`, `\uD83D\u{DE00}` on 😀, `[\uD801\u{DC00}]`: unchanged on every input, giu and gu;
  P(A) still "#" on A.
- G1 Swift's existing rows stay green (S16's halves without `u`, S17's escaped pairs, a lone half alone).
- X1 Render fixture 39: rows of E1 and E2 where Dart, bun and both SDKs agree, green on the engine, Flutter,
  Swift (macOS, iOS, Linux in CI) and Kotlin (JDK 17, 21, 25). Candidates: `s18/fixture-candidates.json`
  (486 rows where Dart, bun and Kotlin agree and no result splits a pair; Swift differs on 262 of them today).

### Groups
Paths from the repo root. Kotlin gets no code task (design 4); it runs in G3.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Swift: an escaped pair is one member in a class | `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift` | E1 | S | none |
| 2 | T2 | Swift: with `u` a lone half matches nothing | `…/Resolver/Transforms.swift` · `…/TransformTests.swift` | E2, G1 | S | T1 |
| 3 | T3 | Fixture 39, counts pinned at 39 (+ Kotlin's quirk comment, added by hand) | `schema/fixtures/render/39_regex_escaped_pairs_lone_halves.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt` (comment only) | X1 | M | T1, T2 |
Placed: E1 T1; E2, G1 T2; X1 T3. 3 tasks in 3 groups, one each: both corners live in the same reader code.

### Order, and why each boundary
- One task per group: E1 and E2 live in the same code (Transforms.swift `classMember` :879, `classSet` :915,
  the escape branch :1019-1033) and one test file.
- 1 → 2: T2's "lone half" is a half not read as half of a pair; in a class that reading exists only once T1 has
  `classMember` call `letterEscape` (:882).
- 2 → 3: fixture 39 holds E1 and E2 rows, which Swift resolves (ResolverFixtureTests.swift:9-31) only after T2;
  T3 alone moves the count pins. G1 and G2 run Swift on macOS, iOS, Linux 6.2 and 5.10; G3 every suite.

### Seams
- `Transforms.swift`, `TransformTests.swift`: T1, then T2.
- Count pins, T3 only, 38 → 39 ("01-39"): ModelRoundTripTests.swift :10, :151; ModelRoundTripTest.kt :30, :176;
  FixturePathsTest.kt :10. The engine (engine/test/conformance.test.ts:58) and Flutter
  (sdk/test/conformance/fixture_paths.dart:20-28) read the folder.
- The comments that call Dart's quirk "a known follow-up" become "Dart's bug, a known difference (row 23b.41)":
  TransformTests.swift:2916-2918 in T2, TransformTest.kt:3052-3054 in T3. The planner left the Kotlin one in no
  task; added to T3 by hand (a comment, no code). Stage by path: `sdk-kotlin/core/bin/` is IDE output.

### Findings (planner, checked against the code)
- F1 E1 (T1): `classMember` (:879-910) reads escapes with `hexEscape()` (:882), so `[`P(A)`-`P(Z)`]` is D801 plus
  the range DC00-D801, refused by the order check (:938-939). Read with `letterEscape()` (:774-783), which with `u`
  joins a high and a low 4-digit escape (:776, :780) and otherwise is `hexEscape`'s reading; write a value above
  U+FFFF braced (:1259), as `\u{…}` already is (:885). `classSet` (:929, :935, :937) takes the value as is. Reword
  `letterEscape`'s "outside a class" (:772) and `classMember`'s comment (:875-878).
- F2 E2 outside a class (T2): after `guard let value` (:1021), with `u` and a value in D800-DFFF (a half
  `letterEscape` did not pair), write `(?:(?!))`, as `[]` is (:980), and skip `escape.length`; `now` stays `.atom`
  (:971), so `+`, `{2}`, `+?` may follow (testA2 :1270-1287 pins `[]` with each). The branch can sit before the mask
  branch (:1022): with `u` no half is masked (RegexMask.swift:104-106).
- F3 E2 in a class (T2): `classMember` returns "" and the half's value for a lone half with `u`; a class left with
  no member reaches :979-980 (`(?:(?!))`, negated `[\s\S]`). With `u` `mask?.range` is nil (RegexMask.swift:379),
  so `classSet` (:940) gets a `u` branch: a range that meets D800-DFFF is written as its parts outside the block,
  braced (:943-946), no stand-ins; the order check stays first (`[\uDC00-\uD801]` still null). Under `i`,
  `dartFolded` (:1219-1239) and `standingIn` (:605-612) take braced members; an empty body never reaches them.
- F4 No `u`: untouched. Halves are masked only without `u` (RegexMask.swift:104-106, :149); `letterEscape` without
  `u` is `hexEscape` (:776); the new branches test `unicode`. S16's rows (TransformTests.swift:2058-2201) stay.
- F5 G1 (T2, question 5): two S17 rows pin the written text of a lone half with `u`: :2745 (high alone) becomes
  `(?:(?!))`, :2746 (low then high) `(?:(?!))(?:(?!))`; their value rows (:2706) keep Dart's values. K1 rows
  (:2291-2297) change written text only; the raw pair outside a class (:1032) stays, so :2739-2744 hold.
- F6 Group names untouched: `hexEscape(inName: true)` refuses a surrogate (:678-680), `(?<a\u{D801}>x)` stays null.
- F7 Rows to add, Dart's value printed at 09 where the probe lacks it: `\uD801+\uDC00` (two lone halves in Dart
  too), `(?<=\u{D801})x`, `[^\uD801\u{DC00}]` giu on A (Dart "#" expected; macOS and 6.2 give A today),
  `[a-\uD801\u{DC00}]` giu on A, the negated E1 class through `dartFolded`'s negated path.
- F8 Linux 5.10 needs nothing different: after T2 Swift never leaves ICU two halves to join, so each row has one
  value on macOS, iOS, 6.2 and 5.10, no `#if os(Linux)`.
- F9 Tests: pairs built with `Self.escapes(_:)` (TransformTests.swift:2646-2654), rows with `differs` (:2657-2666)
  and `assertRegex`, a `// MARK: S18` section before :2980; one doc bullet after Transforms.swift:487-490.
- F10 Fixture 39 (T3): resolved by ResolverFixtureTests.swift:9-31, ResolverFixtureTest.kt:24 and Flutter's
  render_resolved_test.dart; the engine checks `expected`. Its patterns need a real backslash then u (fixture 38's
  JSON escapes decode to characters): generate it with a bun script (`String.fromCharCode(92)`), `expected` from
  the encoder in 38's node order. Every row uses `u`, so no result splits a pair.
- F11 Kotlin: Transforms.kt untouched; Dart's value on every E1/E2 row on JDK 17, 21, 25 (X1 via ResolverFixtureTest).

### Done when
- test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` and
  `xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=FDE5D612-86BA-4138-A1BD-1AB2CF9E8773'`
  and `swift test` in swift:6.2-noble and swift:5.10-jammy containers (read-only mount,
  `--scratch-path /tmp/b`) · `cd sdk-kotlin && ./gradlew build` on JDK 25, 17 and 21
- lint: `cd sdk && flutter analyze` · Android lint inside `./gradlew build`
- typecheck: none (the compilers)
- baseline: engine 705 pass, 1 fail (EADDRINUSE on :8080, Docker) · Flutter +245 · analyze no issues ·
  Swift 225 (macOS, Linux 6.2, 5.10) · iOS 54 + 225 · Kotlin core 226, sdk 128 on JDK 17, 21, 25 ·
  lint no issues, 2026-11-14 (S17 group 4's run on this code; Flutter 3.50.0)
- and the probe (`s18/`, Dart 3.14.0) after each group: no Swift difference left in the E rows on macOS,
  Linux 6.2 or 5.10, but S16's U+FFFD for a lone half in a result (no `u`).
- commits: per task · gate: per group (answered at gate 08, 2026-11-14, under your standing rule: every
  default; question 4: both SDKs stay on ECMAScript where Dart's modifier groups err, a known difference of the
  Flutter SDK written into row 23b.41 at close; question 5: T2 updates two S17 written-text pins; question 6:
  the Flutter-side row and the unset-reference idea are proposed at gate 12)

### Not planned
- Corner 1, Dart's bug with `|` in a modifier group (question 4): both SDKs stay on ECMAScript, as the engine; a
  known difference of the Flutter SDK (sdk/lib/src/state/value_resolver.dart:497), written into row 23b.41 at close.
- A group name with a pair spelled as two 4-digit escapes (Transforms.swift:541-543): not probed, left as is.
- The run-time unset backreference (`(?:(a)|b)\1`): a known difference since S15; the marker-group idea is
  proposed at close (question 6).
