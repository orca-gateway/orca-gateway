# 08 · Tasks · native-sdk-s17

## Front page

### In one breath
tasks: 6 in 4 groups · widest group: 2 · cases: 6 of 6 placed · Swift, Kotlin
S17 is 23b.40: under `i`, letters the platform's Unicode lacks fold from Dart's own classes.
Probe, Dart 3.14: JDK 17 and Linux Swift 5.10 miss 67 case pairs; JDK 21 and Linux 6.2 miss 27.
JDK 17 also throws on 1 412 rows: its `i` backreference breaks on characters above U+FFFF.
G1: letters and classes take Dart's set. G2: backreferences, with 2-unit stand-ins above U+FFFF.
G3: Kotlin on JDK 17 writes backreferences exact. G4: render fixture 38. G1, G2 run side by side.

### New for you
1. Asking the engine at run time what it folds → learning/capability-probing.md

### Trade-offs
4 auto-decided: probe the engine at run time; JDK 17 masks every letter; 2 from memory (S16).

### Questions for you
1. Commands: every suite as at S16, plus Swift in Linux 5.10/6.2 and Kotlin on JDK 17/21.
   (default: as found)
2. Commits: one per task on feat/native-sdk-s17; nothing pushed before 10. (default: yes)
3. One gate per group, 4 groups. (default: yes)
4. 10 BMP pairs lag too (Unicode 14-16: ƛ/U+A7DC, ɤ/U+A7CB …), same cause and fix: row 23b.40
   becomes "letters the platform's Unicode lacks". (default: yes)
5. `\p{Lu}`, `\p{Ll}` over such letters follow the platform's own data. (default: known difference)
6. JDK 17, input with a character above U+FFFF: a part read without `i` can't tell letters of one
   class apart (`a(?i:(.)\1)` gu matches "A😀😀"; Dart: no). (default: known limit)
7. Dart's own quirk `(?i:(.)\1|x)` gu on "Aa" (no match): a follow-up at close. (default: yes)

## Appendix

### Where S17 comes from
Epic row 23b.40, added at S16 gate 12 from what PR #24's CI fix found. With `u` both SDKs hand letters
above U+FFFF to the platform's engine, which folds by its own Unicode; JDK 17's case-insensitive
backreference never repeats a capture above U+FFFF and throws at the input's end. "Fold astral letters
from Dart's fold classes, as the BMP already is, and keep JDK 17's backreference off astral captures."
Done when: "A TransformTests / TransformTest row per platform gap with Dart's printed value, run on
Swift 5.10 and 6.2 on Linux and on JDK 17 and 21 with nothing left out". S17 started on your "Start
23b.40" after native-sdk-s16 gate 12; stages 01-07 skipped as covered by native-sdk. Branch
feat/native-sdk-s17 from S16's close commit c161fbb (on main 2b4daeb, PR #24's merge).

### Checked before planning (2026-11-13)
A probe in the session scratchpad (`s17/oracle/`: gen17.py, kprobe/ with throws caught, swiftprobe/,
bunprobe.ts): S16's 26 644 rows plus 5 931 new ones (negated classes, ranges, `(?i:…)`, backreferences
mid-input, properties, and 405 J rows of backreferences over characters above U+FFFF), 32 575 in all,
Dart 3.14.0 against the Swift SDK (macOS; swift:6.2-noble and swift:5.10-jammy containers) and the
Kotlin SDK's core classes (JDK 17, 21, 25). Rows with a Unicode 17 letter left out (row 23b.39).
| platform | rows ≠ Dart, of 31 677 | why |
|---|---|---|
| macOS Swift / Kotlin JDK 25 | 3 / 1 | S16's `\B` gu/giu (Swift); Dart's `(?i:(.)\1|x)` quirk (both) |
| Linux Swift 6.2 / JDK 21 (Unicode 15) | 655 / 653 | 27 pairs: 5 BMP (Unicode 16) + Garay's 22 |
| Linux Swift 5.10 / JDK 17 (Unicode 13) | 1 645 / 3 996 (1 412 throw) | 67 pairs: 10 BMP + 57 above U+FFFF (U+10570-10D65); JDK 17's bug |
- Lagging BMP pairs: U+019B/A7DC, 0264/A7CB, 1C89/1C8A, A7CC/A7CD, A7DA/A7DB (Unicode 16; all four
  platforms) and 2C2F/2C5F, A7C0/A7C1, A7D0/A7D1, A7D6/A7D7, A7D8/A7D9 (Unicode 14; JDK 17, Linux 5.10).
- Every row over a lagging pair differs: `x` gi/giu on y, `(?i:x)` gu, `[x]`, `[^x]`, `[x-x+1]`,
  `(x)\1` and `(.)\1` gi/giu (also mid-input), `(?i:(x)\1)` gu; and `\p{Lu}`, `\p{Ll}`, `[\p{Lu}z]` giu,
  where the platform has no such letter at all (question 5).
- JDK 17: 1 412 rows throw StringIndexOutOfBoundsException out of the SDK's resolve (`Pattern$CIBackRef`
  loops over the capture's chars but steps by code points); `(.)\1` giu on two identical 😀 never
  matches mid-input. Exact backreferences are fine there; JDK 21 and 25 are fine; Android's
  java.util.regex runs on ICU.
- Dart's quirk (question 7): inside `(?i:A|B)` a backreference in the first alternative compares
  case-sensitively: `(?i:(.)\1|x)` gu on "Aa", "éÉ", "𐐀𐐨" unchanged; `(?i:x|(.)\1)`, `(?i:(.)\1)` match.
- bun (JSC, the engine) gives Dart's value on the letter, class, range, `(?i:…)` and backreference rows
  above U+FFFF and most J rows; it lacks the 5 Unicode 16 BMP pairs; `(.)\1` giu mid-input, properties
  and 20 J rows differ. Fixture 38 takes rows where bun gives Dart's value.
Baseline (all suites, `s17/base-*.log`; Swift and Kotlin from the CI fix's runs): engine 704 pass, 1 fail
(EADDRINUSE on :8080, Docker) · Flutter +244 · analyze no issues · Swift 217 (macOS, Linux 6.2, 5.10) ·
iOS 54 + 217 · Kotlin core 215, sdk 128 on JDK 17, 21, 25 · lint no issues.

### Design (written here; 05-07 skipped)
In full in the session scratchpad (`s17/design.md`), pasted to the planner.
0. Lagging classes, per process, lazily, from the SDK's own engine: the Dart fold classes (Swift
   `Regex.foldClasses`, Kotlin `DartFoldClasses`) it does not fold in full (a letter fails to match
   another of its class under its case-insensitive one-letter match), less the classes `DartFoldTable`
   lists (F2). Apple's ICU and JDK 24+: none (asserted); Linux's Foundation, JDK 17/21, an older
   Android ICU: those newer than their Unicode. A test seam sets the set (F3). Without `u` BMP only.
1. A literal letter under `i` (a letter, `\uHHHH`, `\u{…}`, `\x{…}`) of a lagging class is written as
   Dart's set, exact, `(?-i:[set])`, as `DartFoldTable`'s letters are; with `u` above U+FFFF too.
2. A class under `i` also takes, exact, each letter of a lagging class it meets (negated: leaves them
   out), with the properties branch's one-pass probe; ranges the same.
3. A backreference under `i`: S16's letter mask also masks the input's lagging letters, one stand-in
   per Dart class (memory "regex-mask-extra-dart-classes"). A letter above U+FFFF takes a two-unit
   stand-in (U+F0000-FFFFD, then U+100000-10FFFD, neither in input nor pattern): the copy keeps its
   UTF-16 length. S16's `(?-i:…)` limit applies to these letters too.
4. Kotlin on a JVM whose case-insensitive backreference never repeats a capture above U+FFFF (probed
   once: JDK 17): with `i` and a backreference, `u`, and a character above U+FFFF in the input, every
   fold-class letter of the input is masked and every backreference read under `i` is written exact,
   `(?-i:\N)`, `(?-i:(?:\1|\2))` (F11, F12); `\w`, `\W`, `\b`, `\B` take the word letters' stand-ins
   (F13). Question 6 is the limit this widens.
5. Everything else as today: no `i`; a platform with no lagging class; a JVM without the bug.
6. The U2 guards' filters from PR #24's CI fix go: every row on every platform (G1, F14).
7. Render fixture 38 from rows where bun gives Dart's value (X1).

### Cases (Dart 3.14's values; "unchanged" means no match; E is 😀; 𐵐 U+10D50 / 𐵰 U+10D70)
- L1 Literal letters of a lagging class under `i`: `ƛ` gi and giu on U+A7DC → "#", U+A7DC gi on ƛ →
  "#", every lagging BMP pair both ways; `𐵐` giu on 𐵰 → "#", `(?i:𐵐)` gu → "#", every astral pair both
  ways with `u`; without `u` the astral rows stay S16's (unchanged).
- C1 Classes: `[x]` gi/giu on y → "#"; `[^x]` giu on y → unchanged; `[x-x+1]` giu on y → "#"; a class
  meeting no lagging class is written as today.
- R1 Backreferences: `(x)\1` and `(.)\1` gi/giu on x+y → "#"; `(x)\1` giu on x+y+"z" → "#z"; `(.)\1`
  giu on "z"+x+y+"z" → "z#z"; `(?i:(x)\1)` gu on x+y → "#"; `$1` reads the original letter back.
- J1 JDK 17: the 405 J rows (`(.)\1`, `(E)\1`, `(\S)\1`, `(?<n>.)\k<n>`, `(.)(.)\2\1`, `(a.)\1`,
  `(.+)\1`, `(.)\1+`, `(.)\1|x`; giu, gu, gi, g and inside `(?i:…)` gu; over EE, EEx, xEE, E🎉, aEaE,
  EEEE, 𐐀𐐨, 𐐀𐐀x, aEEa) give Dart's value and nothing throws (`(.)\1` giu on EE → "#", EEx → "#x",
  xEE → "x#"); and (F13) `\w(.)\1` giu on aEE → "#", `\b(.)\1` → "a#", `\B(.)\1` → unchanged,
  `\W(.)\1` on " EE" → "#", `[\w](.)\1` → "#", `\w(.)\1` on "ſEE" and "K"(U+212A)"EE" → "#".
- G1 The U2 guards run every row on every platform; the SDK's lagging set is empty on Apple's ICU and
  JDK 24+ (asserted), and seam-driven rows run the lagging paths on macOS and JDK 25.
- X1 Render fixture 38: one row per kind from L1, C1, R1 and J1 where bun gives Dart's value; green on
  the engine, Flutter, Swift (macOS, iOS, Linux in CI) and Kotlin (JDK 17, 21, 25).

### Groups
Paths from the repo root.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Swift: lagging classes, letters, classes | `sdk-swift/Sources/OrcaGatewayCore/Resolver/DartFoldClasses.swift` · `…/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift` | L1, C1 (Swift) | M | none |
| 1 | T2 | Kotlin: lagging classes, letters, classes | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/DartFoldClasses.kt` · `…/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt` | L1, C1 (Kotlin) | M | none |
| 2 | T3 | Swift: two-unit stand-ins, backreferences, guards | `…/Resolver/RegexMask.swift` · `…/Resolver/Transforms.swift` · `…/TransformTests.swift` | R1, G1 (Swift); J1's rows pinned as guards | M | T1 |
| 2 | T4 | Kotlin: two-unit stand-ins, backreferences | `…/resolver/RegexMask.kt` · `…/resolver/Transforms.kt` · `…/resolver/TransformTest.kt` | R1 (Kotlin; on JDK 17 its astral rows stay behind `jvmRepeats` until T5) | M | T2 |
| 3 | T5 | Kotlin: JDK 17 exact backreferences, guards | `…/resolver/Transforms.kt` · `…/resolver/RegexMask.kt` · `…/resolver/TransformTest.kt` | J1, G1 (Kotlin) | M | T4 |
| 4 | T6 | Fixture 38, counts pinned at 38 | `schema/fixtures/render/38_regex_case_pairs_jdk17_backreferences.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt` | X1 (engine, Flutter, Swift macOS/iOS/Linux, Kotlin JDK 17/21/25) | M | T1-T5 |
Placed, Swift · Kotlin: L1, C1 T1 · T2; R1 T3 · T4; J1 guards in T3 · T5; G1 T3 · T5; X1 T6 on all
runners. 6 tasks in 4 groups, at most 2 per group; Swift is done after group 2.

### Order, and why each boundary
- Groups 1 and 2 pair a Swift task with a Kotlin task sharing no file; they run side by side.
- 1 → 2: T3/T4 mask lagging letters with T1/T2's set, seam and "Dart's set" helper; the stand-ins go
  through the letter and class writing T1/T2 extend.
- 2 → 3: T5 masks every fold-class letter, astral ones with T4's two-unit stand-ins and code-point
  letter table, and takes T4's JDK 17 rows out from behind `jvmRepeats`.
- 3 → 4: fixture 38 holds J1 rows, green on JDK 17 only after T5; T6 alone owns the count pins.

### Seams
- `Transforms.swift`, `TransformTests.swift`: T1 then T3; `DartFoldClasses.swift` T1's alone,
  `RegexMask.swift` T3's alone.
- `Transforms.kt`, `TransformTest.kt`: T2, T4, T5 in turn; `RegexMask.kt` T4 then T5; `DartFoldClasses.kt`
  T2's alone.
- Count pins, T6 only, 37 → 38 ("01-38"): ModelRoundTripTests.swift :10, :151; ModelRoundTripTest.kt
  :30, :176; FixturePathsTest.kt :10. The engine and Flutter read the folder (engine/test/
  conformance.test.ts:60, sdk/test/conformance/fixture_paths.dart:23); no skip list.
- No ValueResolver change: `matches` goes through `Regex.run` (ValueResolver.swift:246) and
  `RegexSupport.search` (ValueResolver.kt:210), `(?i:` included. Stage by path: `sdk-kotlin/core/bin/`
  is IDE output.

### Findings (planner, checked against the code)
- F1 Lagging set, once per process on first use under `i`, beside the classes: Swift a `static let` in
  DartFoldClasses.swift over `foldClasses` (:15-22), NSRegularExpression `.caseInsensitive` on
  `escapedPattern(for:)` as the test's `icuFolds` (TransformTests.swift:1822-1826); Kotlin `by lazy`
  beside `classes`/`letters`/`classOf` (DartFoldClasses.kt:26-38) with `compileIcuLike` CI|UC, as
  `unicodeClasses` is learned (Transforms.kt:1287-1292). About 2 938 one-letter compiles, once.
- F2 Leave out the classes `DartFoldTable` lists: the JVM never folds {0390,1FD3}, {03B0,1FE3},
  {FB05,FB06} (RegexMask.kt:176-183), so JDK 25 would report 3 and G1's "empty" fails; they are table
  letters already written as Dart's set and masked by S16 (Swift `fullFolding` RegexMask.swift:139-147,
  Kotlin `lettersWithU` :183).
- F3 Test seam: Swift has no mutable static in Resolver; copy OrcaDebug's NSLock-guarded static var
  (OrcaDebug.swift:15-29); Kotlin a `@Volatile internal var`. What derives from the set follows the
  seam, not a once-only let: Swift `tableKept` (Transforms.swift:1161-1164), Kotlin `foldLetters`/
  `foldClassAt` (Transforms.kt:1120-1128). Tests restore it in tearDown / @AfterTest.
- F4 One "Dart's set" helper per SDK, by code point: the table's gi/giu column, else the fold class
  (none of the 10 BMP lagging pairs is in `DartFoldTable`). Today only the table: Swift `dartFold`
  (:1104-1106), Kotlin `DartFoldTable.set(c: Char)` (DartFoldTable.kt:31). Point 1 sites: Swift
  `literal` (:841-846), hex escape (:1002), letter (:1084); Kotlin `folded` (Transforms.kt:646) and the
  escape `letter` (:705, `<= 0xFFFF`). Kotlin reads Chars, so with `u` a literal above U+FFFF reaches
  the `else` branch (:766-770) as two halves: read its code point there and step 2.
- F5 The same helper fixes the masks: Swift RegexMask.swift:124 (`dartFold ?? []` + letter: a lagging
  pair gets two stand-ins, so `(x)\1` never matches) and Transforms.swift:588 (`?? [$0]`: `[^x]` would
  take y's stand-in); Kotlin RegexMask.kt:142 and Transforms.kt:1113 call `DartFoldTable.set(...)!!`,
  which throws for a letter outside the table.
- F6 Classes: Swift `dartFolded` (:1171-1178) uses `tableKept` for a class without a property: add the
  lagging letters to that Kept, astral too with `u`. Kotlin `dartClass` (:1102-1109) tests table
  letters one by one with `member(c: Char)` (:1092): add the lagging letters with the properties
  branch's one-pass probe (:1095-1101). A class holding `\p{…}` is already exact over every class.
- F7 Two-unit stand-ins, Swift: the pool (RegexMask.swift:57-71) is U+E000-F8FF over a `Set<UInt16>`;
  `note` (:82-88) drops values above U+FFFF and the input loop (:89) walks units, so a held U+F0000+ is
  never seen. A second cursor (U+F0000-FFFFD, then U+100000-10FFFD) skips the input's and pattern's
  scalars and `escape` values (:212-231). `letterStandIns` (:48), `standIn(forLetter:)` (:241-243) and
  `copy(of:)` (:253-255) move to scalars; callers Transforms.swift:598, 842, 999, 1011, 1081.
- F8 Two-unit stand-ins, Kotlin: `StandInPool` (RegexMask.kt:198-224) is BMP only; `hold` (:208-210) and
  the input loop (:203) miss U+F0000+; `escapedValues` (:227-240) already yields them. `letters`/
  `letterStandIns` (CharArrays :56-57), `letter()` (:69-73), `maskedLetters` (:79) and the copy
  (:153-154) move to code points; users `withStandIns` (Transforms.kt:916-917), the escape's
  `m::standIn` (:706), `dartClass`'s masked tail (:1111-1116).
- F9 Same length: halves are masked only without `u`, astral letters only with it, so Swift
  `scalars(of:)`/`range` (:261-349) and Kotlin `ranges` (:89-113) stay; no Dart class mixes BMP and
  astral letters (DartFoldClasses.kt:1214-1495); groups read from the original by range (Swift
  :400-407, Kotlin :393-397); Kotlin's pair step (:1337) treats a stand-in pair as the original pair.
- F10 Point 3's trigger is S16's: Swift `foldsReference` (RegexMask.swift:164-208) gates `folding`
  (:108-109), T3 adds the lagging letters by scalar (BMP only without `u`); Kotlin
  `reading.foldedReference` (Transforms.kt:693) → `withLetters` in `search` (:421-432; candidates
  RegexMask.kt:140-142).
- F11 Kotlin writes a backreference at Transforms.kt:694-700: `(?:)` (:696), `(?:\1|\2)` for
  `\k<name>` (:697), else the pattern's text (:698). Java picks CIBackRef or BackRef from the flags in
  force where it parses, so `(?-i:\N)` and `(?-i:(?:\1|\2))` compile to BackRef. The "write exact"
  switch reaches the second `compile` (:429, :439-447) as its own flag, not through the mask: `build`
  returns null when the input holds no letter (RegexMask.kt:143, `(.)\1` giu on "😀😀") or the pool runs
  out, and those runs must not reach CIBackRef either.
- F12 The JDK 17 path reuses S16's trigger, `reading.foldedReference`, plus: the `u` flag (without it
  every half is masked, RegexMask.kt:139, 154); a character above U+FFFF in the input; a JVM probe
  learned once beside `unicodeClasses` (:1287-1292), `(.)\1` CI|UC on "𐐀𐐀" in runCatching, as the
  test's `jvmRepeats` (TransformTest.kt:2371); its own seam. Then the candidates are every
  `DartFoldClasses` letter.
- F13 New: masking every fold-class letter masks ASCII letters, ſ and K too, which breaks S16's rule
  "no masked letter is one of Dart's word characters" (Transforms.kt:610-612). Outside a class `\w`,
  `\W`, `\b`, `\B` (:644-645, :668-671) take the word letters' stand-ins; in a class `dartClass` already
  probes each letter. T5 adds the J1 word rows, Dart's values printed at this card (`s17/oracle/f13*`).
- F14 G1: Swift drops `icuFolds` (TransformTests.swift:1821-1826) and `skipped` (:2220, :2228-2234,
  :2248-2250); Kotlin drops `jvmFolds`, `jvmRepeats`, `kept`, `leftOut` (TransformTest.kt:2369-2381);
  both assert the SDK's set is empty on Darwin / `Runtime.version().feature() >= 24`. T1 and T3 also
  run in the Linux containers; T2, T4, T5 also on JDK 17 and 21.

### Done when
- test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` and
  `xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=FDE5D612-86BA-4138-A1BD-1AB2CF9E8773'`
  and `swift test` in swift:6.2-noble and swift:5.10-jammy containers (read-only mount,
  `--scratch-path /tmp/b`) · `cd sdk-kotlin && ./gradlew build` on JDK 25, 17 and 21
- lint: `cd sdk && flutter analyze` · Android lint inside `./gradlew build`
- typecheck: none (the compilers)
- baseline: engine 704 pass, 1 fail (EADDRINUSE on :8080, Docker) · Flutter +244 · analyze no issues ·
  Swift 217 (macOS, Linux 6.2, 5.10) · iOS 54 + 217 · Kotlin core 215, sdk 128 on JDK 17, 21, 25 ·
  lint no issues, 2026-11-13 (Flutter 3.50.0)
- and the probe (`s17/oracle`, Dart 3.14.0) after each group: no Swift or Kotlin difference left in
  the group's rows on any of the six runners, Unicode 17, properties (question 5) and Dart's quirk
  (question 7) aside.
- commits: per task · gate: per group (answered at gate 08, 2026-11-13, under your standing rule:
  every default; question 4: row 23b.40 covers every letter the platform's Unicode lacks, BMP too;
  questions 5 and 6: properties over such letters and JDK 17's wider `(?-i:…)` limit are known
  differences, written into row 23b.40; question 7: Dart's `(?i:(.)\1|x)` quirk is a follow-up at close)

### Not planned
- Properties of letters the platform's Unicode lacks (`\p{Lu}` giu on 𐵰 on JDK 21): its own data
  (question 5).
- Dart's `(?i:(.)\1|x)` quirk (question 7): pattern side, a follow-up.
- Unicode 17 letters and scripts (row 23b.39, memory "unicode17-dart-reference"); Android's ICU path
  (not run anywhere).
