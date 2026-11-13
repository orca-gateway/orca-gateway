# 09 · Implementation · native-sdk-s16

## Front page

### In one breath
group 3 of 3 · tasks: 1 green, 0 blocked · cases: 7 of 7 green · suites green
T5: render fixture 37, 21 rows, one per kind of S16's corners; count pins 36 -> 37.
Every runner resolves it as Dart does; the SDKs from before S16 fail 14 rows (Swift), 15 (Kotlin).
Tests: engine 704, Flutter 244, Swift 217, iOS 54 + 217, Kotlin core 215, sdk 128, lint clean.
Stage: 5 of 5 tasks green over 3 groups, 0 blocked; 5 commits on the branch, nothing pushed.

### New for you
nothing new

### Trade-offs
3 auto-decided: B1's three kinds, each with its `giu` form; two rows name a replacement so whole
emoji come back; `(.)(.)` "$1$2" left out (Swift's approved U+FFFD).

### Questions for you
1. Blocked: none.
2. `A` approves the stage; ship (stage 10) pushes the branch and opens the PR. (default: go)

## Appendix

### Group 1
Commits: T1 54a2d26, T2 47bf415 (one per task, staged by path). Nothing pushed. Gate 08 approved with
your "A, approve" (every default; Unicode 17 moved to row 23b.39; Swift's U+FFFD per lone half and
its `\B` inside a pair with `u` are known differences in row 23b.38).

#### Task T1 · Swift: masked run for UTF-16 units
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/RegexMask.swift` (new) · `…/Resolver/Transforms.swift` · `…/Resolver/ValueResolver.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: U1, U2, K1 → green (`swift test`: 207 tests, 0 failures; the 198 of before pass) · red first:
7 of the 9 new tests; the 2 guards (`testU1_guard_…`, `testK1_guard_…`) passed before any code.
Changed: RegexMask.swift adds `RegexMask` (when to mask; the shared stand-in `Pool` T3 draws letters
from; the input copy; the pattern split that leaves group names alone; range parts) and
`Regex.Run` / `Regex.run`, which the `regex` transform and `matches` both call. Transforms.swift:
`asciiClasses` / `compile` take an optional `mask` (nil runs as before); groups are read from the
input by range; output is built as UTF-16 units, decoded once. Tests: `S16 — UTF-16 units without
u`, 9 tests, values printed by Dart 3.14.0.
Decisions: 1. a range over surrogates is written as sub-ranges around the stand-ins, not ICU set
subtraction (same output) · 2. three known differences pinned, Swift's value beside Dart's: `\B`
gu/giu on "a😀b"; `(.)(.)` "$1$2" on 😀 gives two U+FFFD; 6 399+ private-use characters with one pair
run unmasked · 3. a class opening `[-` then a surrogate escape: Dart accepts it, the test follows Dart.
Review fit: pass
Review quality: pass

#### Task T2 · Kotlin: masked run, units, pair step
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/RegexMask.kt` (new) · `…/resolver/Transforms.kt` · `…/resolver/ValueResolver.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: U1, U2, K1 → green (`./gradlew build`: core 207, sdk 128, 0 failures, lint no issues; the 197
core tests of before pass) · red first: the 6 fix tests; the 4 guard tests passed before any code.
Changed: RegexMask.kt gives every surrogate unit in the input or named by the pattern the lowest free
private-use unit, from one file-private `StandInPool`, in the halves' order, and builds the
same-length copy; null with `u`, when nothing needs masking, or when the pool runs out.
Transforms.kt: `RegexSupport.search` is the one way in; `Match` reads groups from the original by
range; `compile`, `asciiClasses`, `characterClass`, `classAtom` take the mask; with `u`,
`allMatches` calls `find(end + 2)` after an empty match at a high half. Tests: `// MARK: S16`, 10 tests.
Decisions: 1. sub-ranges around the stand-ins, not Java's `[…&&[^…]]` (same output) · 2. U2 loops
DartFoldClasses' 282 classes above U+FFFF by a rule checked against all 2 256 rows Dart printed per
flag set · 3. the pair step in `allMatches` only, only with `u`.
Review fit: pass (note: 276 `gm`/`gs` rows took `g`'s value unprinted; Dart printed them since, all equal)
Review quality: pass

#### Group 1 test run
Once after the group, before the commits (logs `s16/g1/*.log`):
- `cd engine && bun test` · 703 pass, 1 fail (EADDRINUSE on :8080, Docker: as the baseline).
- `cd sdk && flutter test` · +243: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift build` · 0 warnings · `swift test` · 207 tests, 0 failures.
- iOS simulator (iPhone 16 Pro) · 54 + 207 tests, 0 failures · TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build --rerun-tasks` · BUILD SUCCESSFUL · core 207, sdk 128, 0 failures ·
  lint: No issues found.
- Probe (`s16/oracle`, Dart 3.14.0, a lone half read as U+FFFD for Swift; `s16/recount.py`), 26 196
  rows (26 644, less the 448 with a Unicode 17 letter): every U row and every row with a character above U+FFFF matches Dart in both SDKs, but
  Swift's 2 `\B` gu/giu rows (known difference). Group 2's rows are left: BMP backreferences under
  `gi` (Swift 78 + 78, Kotlin 82 + 82), `giu` on Kotlin (ı, 4 + 4), the İ and full-folding rows.

### Group 2
Commits: T3 e38e838, T4 6825fad (one per task, staged by path). Nothing pushed. Group 1's card approved
with your standing rule (its one question, start group 2, minor); group 2's first card the same (retry
T3 once, comments only, then group 3).

#### Task T3 · Swift: backreferences under `i`, letter stand-ins
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/RegexMask.swift` · `…/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: B1, B3, B2 guards → green (`swift test`: 217 tests, 0 failures; the 207 of before pass) · red
first: 9 of the 10 new tests (1 635 assertions); the B2 guard passed before any code.
Changed: RegexMask.swift decides case (1b): `foldsReference` (`i` in force, from the flags or a
modifier group, and a backreference the reader writes); `foldsApart` holds the 104 letters with a
multi-letter full fold, and without `u` also ſ, ϴ and the ohm, Kelvin and angstrom signs; one
stand-in per Dart fold class from the same pool, after the halves'. Transforms.swift: a masked
letter, literal or escaped, is written as its stand-in; a class or property becomes
`(?:(?!S)X|(?-i:[M]))`, M the stand-ins Dart's class matches. Tests: `S16 — backreferences under i`.
Decisions: 1. the wrapper goes around the class as written (same output) · 2. the 104 letters are a
hardcoded list (Swift has no case-folding API; the same 104 as F11) · 3. pinned, Swift's value beside
Dart's: `(?-i:ß)|(.)\1` giu on "ẞ" (the approved limit); 2 rows where the pool runs out for a letter.
Review fit: pass (notes: the trigger also starts on valid patterns whose reference sees only an unset
group, same output or the approved limit; a stale "never with `u`" comment at Transforms.swift:550)
Review quality: Transforms.swift:550 said a mask never exists with `u`, fixed (one rework: comments only, 32
`///` lines, 217 tests) · then Transforms.swift:918-919 and RegexMask.swift:250-251 still say every
stand-in where only the halves' are meant, blocked · retry on your standing rule: those two and 5 more
comments of the kind fixed (comments only; `swift test` 217, iOS 54 + 217 after) · fit: pass ·
quality: pass

#### Task T4 · Kotlin: backreferences under `i`, letter stand-ins
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/RegexMask.kt` · `…/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: B1, B2 → green, B3 as guards (`./gradlew build`: core 215, sdk 128, 0 failures, lint no
issues; the 207 core tests of before pass) · red first: 4 of the 8 new tests; the 4 guards passed.
Changed: RegexMask.kt `withLetters` also masks the listed letters the input holds, one stand-in per
Dart fold class from the same pool, after the halves. Transforms.kt: `search` reads the pattern once
(a `Reading`) and re-compiles with the letter mask only when a backreference is written where `i` is
in force; `dartClass` wraps a class in `(?:(?!stand-ins)D|matched stand-ins)`; literal and escaped
letters, and Dart's sets of them, become stand-ins. Tests: `// MARK: S16 — backreferences under i`.
Decisions: 1. mask only where a reference sits under `i` (same output: both engines fold a
reference by the `i` at it) · 2. without `u` a stand-in per letter, each its own Dart class · 3. on
your standing rule (minor): ΐ U+0390/1FD3, ΰ U+03B0/1FE3 and ﬅ/ﬆ U+FB05/FB06 masked under `giu`.
Review fit: pass (correction: decision 3 fixes 12 rows and costs 3 the approved limit, not 1)
Review quality: pass

#### Group 2 test run
Once after the group, before the commits (logs `s16/g2/*.log`):
- `cd engine && bun test` · 703 pass, 1 fail (EADDRINUSE on :8080, Docker: as the baseline).
- `cd sdk && flutter test` · +243: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift build` · 0 warnings · `swift test` · 217 tests, 0 failures.
- iOS simulator (iPhone 16 Pro) · 54 + 217 tests, 0 failures · TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build --rerun-tasks` · BUILD SUCCESSFUL · core 215, sdk 128, 0 failures ·
  lint: No issues found.
- Probe (`s16/recount.py`): cases 25 552 rows: Swift differs only on the 2 approved `\B` gu/giu
  rows (was B gi 78 + B. gi 78), Kotlin on none (was 82 + 82 gi, 4 + 4 giu); f11 644 rows: none in
  either (were 628 and 22); T4's 24 class rows: none in either.
- T4's grid (1 072 rows): `(?i:(x)\1)|ß` gu and 6 like it differ on Swift, `|ΐ` and `|[^ΐ]` on
  Kotlin: the approved limit, a part read without `i` (row 23b.38 reworded). `|\w`, `|\W`, `|[\W]`
  under `gu` differ on both, and did before S16 (Dart's `\w` takes ſ and K once a `(?i:` group exists).

### Group 3
Commit: T5 83b56e8 (staged by path). Nothing pushed. Group 2's card (round 3) approved with your
standing rule (its one question, start group 3, minor).

#### Task T5 · Fixture 37, counts pinned at 37
Files: `schema/fixtures/render/37_regex_utf16_units_backreferences.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt`
Cases: X1 → green on the engine, Flutter, Swift and Kotlin · red first: with the file in and the pins
at 36, Swift 1 failure and Kotlin 2 (the counts); the resolver fixture tests passed at once (T1-T4 are
in); on the SDKs from before S16 (398017b, exported to the scratchpad) 14 rows fail on Swift, 15 on Kotlin.
Changed: fixture 37, 21 rows, Dart 3.14's values (E is U+1F600): `.`, `[^a]`, `\S`, `[E]` on E → "##";
`.{2}` with "[{{value}}]" → "[E]"; `^(..)$` with "<$1>" → "<E>"; `x*` with "" → E; `E+` on EE → "##";
`(?<=.).` on aEb → "a###"; `matches` `^.$` no, `^..$` yes; U+10400 on U+10428 gi unchanged, giu "#";
`x*` gu → "#E#"; `(s)\1` "sſ", `(K)\1` "K"+U+212A, `(.)\1` "ßẞ": gi unchanged, giu "#"; `(s)\1` gi
"sS" → "#". Pins 36 -> 37 and "01-36" -> "01-37" (5 lines).
Made by `s16/oracle/t5/gen37.py` (json.dumps indent=2, ensure_ascii=True; reruns byte for byte):
`expected` from the engine's encodeJsonTree, `resolved` from the Flutter transform's code under Dart
3.14; the engine's own ValueResolver agrees on all 21; pure ASCII; no schema or model change.
Decisions: 1. B1's three kinds (ſ, Kelvin sign, ß/ẞ), each with its `giu` form; θ/ϴ, Ω, Å and ᾀ/ᾈ
repeat them and stay in the unit tests · 2. two rows name a replacement so the match and a group
come back as whole emoji; `(.)(.)` "$1$2" left out (Swift's approved U+FFFD) · 3. `x*` g with "" on E,
the one empty-match row with no lone half, passes before S16 too: it guards F4's joined output.
Review fit: pass
Review quality: the description said "with `u` an empty match never falls between the two halves", false
for Dart (`\B` gu finds that position), fixed (one rework, description only: "after an empty match at a
pair's high half the next search starts after the whole pair"; "No result splits a pair" narrowed to
the rows; the other keys unchanged; suites as before)

#### Group 3 test run
Once after the group, before the commit (logs `s16/g3/*.log`):
- `cd engine && bun test` · 704 pass, 1 fail (EADDRINUSE on :8080, Docker: as the baseline; the new
  test is fixture 37).
- `cd sdk && flutter test` · +244: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift build` · 0 warnings · `swift test` · 217 tests, 0 failures.
- iOS simulator (iPhone 16 Pro) · 54 + 217 tests, 0 failures · TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build --rerun-tasks` · BUILD SUCCESSFUL · core 215, sdk 128, 0 failures ·
  lint: No issues found.

### Blocked
none (T3 was blocked on its quality review at group 2's first card; its retry passed both reviews)

### Not done
none

### For ship (stage 10) to know
nothing to deploy (no migration, config or env); the SDK fixes ship with the next `sdk-swift-v*` and
`sdk-kotlin-v*`; the schema gains fixture 37. The branch also carries S15's close note (24e5872, not on
main yet). Row 23b.38's known-limit wording was widened at group 2 (in the epic plan, outside the repo).
Found in passing, not S16's: Dart's `\w` takes ſ and the Kelvin sign under `gu` once a `(?i:` group
exists; neither SDK does (3 rows); Android's ICU path (full folding, like Swift) is not run anywhere.
