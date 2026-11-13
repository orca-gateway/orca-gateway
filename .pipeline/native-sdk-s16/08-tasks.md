# 08 · Tasks · native-sdk-s16

## Front page

### In one breath
tasks: 5 in 3 groups · widest group: 2 · cases: 7 of 7 placed (1 row left out) · Swift, Kotlin
S16 is 23b.38's input side: engines search a same-length copy; text is read from the original.
Probe, Dart 3.14: 26 644 cases; 3 532 differ in Swift, 2 890 in Kotlin today (Unicode 17 aside).
G1: without `u` each half of a pair is one unit (`.` on an emoji → "##"); Kotlin steps pairs.
G2: backreferences under `i`: `(s)\1` "sſ", `(ß)\1` "ßss", Kotlin's ı and İ stop matching.
G3: render fixture 37 on the engine, Flutter, Swift and Kotlin. Swift and Kotlin run side by side.

### New for you
1. UTF-16 surrogate pairs, the two units behind one emoji → learning/utf16-surrogate-pairs.md

### Trade-offs
1 needs you: Unicode 17 (question 4).
6 auto-decided: serial groups, the `(?-i:)` limit, fixture rows (your calls); 3 mask choices.

### Questions for you
1. Commands: every suite, as at S15; the engine's 1 failure is Docker holding :8080.
   (default: as found)
2. Commits: one per task on feat/native-sdk-s16; nothing pushed before 10. (default: yes)
3. One gate per group, 3 groups. (default: yes)
4. Major: your Flutter 3.50 brought Dart 3.14, which reads Unicode 17; S14/S15's tables are
   Dart 3.12.2's: 4 new scripts, 54 letters. A new row 23b.39 for them? (default: yes)
5. Swift strings hold no lone half: where Dart's result splits a pair, Swift writes U+FFFD.
   (default: a known difference)
6. Swift with `u` finds no empty match inside a pair (`\B` gu "a😀b"). (default: known difference)

## Appendix

### Where S16 comes from
Epic row 23b.38, split off at S15 gate 08 (your answer to its question 4, under your standing rule):
backreferences under `i`; UTF-16 code units without `u`; supplementary letters folding only with `u`;
Kotlin's empty match inside a pair with `u`. "No pattern rewrite reaches these: a fix swaps the
input's text for stand-ins of the same UTF-16 length … and reads the text back from the original."
Done when: "A TransformTests / TransformTest row per corner with Dart's printed value, or a render
fixture where the engine can express it". S16 started on your "Start S16" after native-sdk-s15 gate 12;
stages 01-07 skipped as covered by native-sdk. Branch feat/native-sdk-s16 from S15's close commit
24e5872 (on main d3229af, PR #23's merge), as the slice-history memory says.

### Checked before planning (2026-11-13)
The reference moved: this morning's Flutter upgrade (3.50.0) brought Dart 3.14.0, and every expected
value below is printed by it. A new probe, session scratchpad `s16/oracle/` (gen.py, dartprobe/,
swiftprobe/, javaprobe/, show.py, bunprobe.ts): the Flutter SDK's regex transform in Dart, the Swift
SDK (macOS), the Kotlin SDK (core classes, JDK 25), replacement "#".
- 26 000 cases from Python's Unicode 17 case maps (1 479 fold classes, 2 989 code points, 307 classes
  above U+FFFF) and 36 UTF-16 patterns × 6 flag sets × 6 inputs; 644 more for the planner's F11.
- Without the 448 rows that use Unicode 17 letters: 3 532 differ in Swift, 2 890 in Kotlin.
| group | cases | Swift ≠ Dart | Kotlin ≠ Dart |
|---|---|---|---|
| `(a)\1` and `(.)\1`, gi/giu on a+b, BMP | 9 872 | 156 | 172 |
| the same, letters above U+FFFF | 2 256 | 1 128 | 1 128 |
| `a` and `[a]` gi/giu on b, BMP | 9 872 | 0 | 0 |
| the same, above U+FFFF | 2 256 | 1 128 | 1 128 (564 Dart results hold a lone half) |
| UTF-16 without `u` (g gi gm gs) | 864 | 490 | 390 (235 hold a lone half) |
| UTF-16 with `u` (gu giu) | 432 | 2 | 48 |
| F11: full-folding letters (104) and İ | 644 | 628 | 24 |
- What they show: Dart without `u` folds by upper case and never maps a non-ASCII letter to ASCII,
  so in a backreference K ≠ Kelvin sign, s ≠ ſ, ß ≠ ẞ, θ ≠ ϴ, Ω ≠ ohm sign, ᾀ ≠ ᾈ; both engines fold
  them. Kotlin's JVM also pairs ı and İ with I and i. Swift's ICU compares backreferences by full
  folding: `(ß)\1` gi "ßss" matches there, under `gi` and `giu`. Dart without `u` reads code units:
  halves match one by one, letters above U+FFFF never fold. With `u`, Kotlin finds empty matches
  between a pair's halves; Dart's search tries every unit, so its `\B` gu does too.
- Unicode 17 (question 4): Dart 3.14 folds 54 letters JDK 25 does not know (U+A7CE, A7CF, A7D2,
  A7D4, U+16EA0-16ED3) and accepts `\p{Script=Sidetic}`, Tolong_Siki, Beria_Erfe, Tai_Yo (and their
  codes) that the Swift SDK refuses: S15's table of exact script values and fold classes is Dart
  3.12.2's. Rows that use them are left out of S16.
- bun (JSC, for fixture 37) gives Dart's value on every row but 10 Unicode 16 pairs JSC does not
  fold (U+A7CB-A7DC, U+1C89/1C8A) and the two `\B` gu rows.
Baseline (all suites, `s16/base-*.log`, Flutter 3.50.0): engine 703 pass, 1 fail (Docker holds port
8080; a test that starts a server there gets EADDRINUSE) · Flutter +243 · analyze no issues · Swift
198 · iOS 54 + 198 · Kotlin core 197, sdk 128 · lint no issues.

### Design (written here; 05-07 skipped)
In full in the session scratchpad (`s16/design.md`), pasted to the planner, with F7-F11 folded in.
0. Two entry points per SDK, no others (F1): the `regex` transform (replace, and match-only) and the
   `matches` op.
1. A masked run: the engine searches a copy of the input with the same UTF-16 length; the result,
   match 0 and every `$n` group are read from the original by range (F3). Only when needed: (a) no
   `u`, and a surrogate in the input or a character above U+FFFF / a surrogate escape in the pattern;
   (b) `i` in force anywhere (the flags or a `(?i:…)` group, F9), a backreference the reader writes,
   and a listed letter in the input. Every other pattern runs as today.
2. Without `u` (1a): each surrogate unit in the input, and each one the pattern names (literal halves,
   `\uHHHH`, class members, range ends), becomes a stand-in. Stand-ins are the lowest private-use
   units (U+E000-F8FF) that neither the input nor the pattern holds, per call (F7: icon fonts put real
   text there); never surrogates; in the halves' order. Range order is checked on Dart's units (F6).
   Swift builds the output as UTF-16 units and decodes once: a lone half becomes U+FFFD (F4,
   question 5); Kotlin keeps Dart's units.
3. Under `i` with a backreference (1b): the letters whose engine folding Dart does not share become
   one stand-in per Dart fold class under the flags in force: without `u` the 33 BMP classes (F10)
   and, on Swift, the 104 letters with a multi-letter full fold; with `u` the full-folding letters on
   Swift (ß and ẞ share one stand-in, so `(ß)\1` giu "ßẞ" still matches), ı and İ on Kotlin. In the
   pattern such a letter becomes its stand-in; a class, escape or property Dart would match it with
   takes the stand-in too (F8).
4. Kotlin with `u`: after an empty match at a high half before its low half, the next search starts
   after the pair (F12); the search still tries every unit, as Dart's does.
5. Render fixture 37: rows where bun gives Dart's value and the result holds no lone half.

### Cases (Dart 3.14's values; <D83D> is one UTF-16 unit; "unchanged" means no match; E is 😀)
- U1 Without `u` (g, gi, gm, gs), inputs E, "aEb", "EE", "𐐨", "a\nE": `.`, `[^a]`, `\S`, `\W`, `\D`,
  `[^]`, `(.)` → "##" ("aEb" → "####"); `.?` → "###"; `.{2}` → "#"; `^.$` unchanged; `^..$` → "#";
  `[E]` and `[😀]` → "##"; `[^E]` on "𐐨" → "##"; `E+` on "EE" → "##"; `\uD83D`, `[\uD83D]`,
  `[\uD800-\uDBFF]`, `.(?=.)` → "#<DE00>"; `\uDE00`, `[\uDC00-\uDFFF]`, `(?<=.).`, `.$` → "<D83D>#";
  `a??`, ``, `(?:)`, `x*`, `\B` → "#<D83D>#<DE00>#" (Kotlin's today); kept: `E`, `(?:E)+`,
  `😀`, `\b`, `^`, `$`. `matches` (no flags): `^.$` on E false, `^..$` true (F13). Swift
  writes U+FFFD for each lone half.
- U2 Letters above U+FFFF without `u` (307 classes; Deseret 𐐀 U+10400 / 𐐨 U+10428): `𐐀` gi "𐐨" →
  unchanged; `[𐐀]` gi "𐐨" → "#<DC28>" (Swift "#" U+FFFD); `(𐐀)\1` and `(.)\1` gi "𐐀𐐨" → unchanged;
  with `giu` all four "#" (Dart's today).
- K1 With `u` (gu, giu) on E: `a??`, ``, `(?:)`, `x*` → "#E#" (Kotlin today "#<D83D>#<DE00>#");
  kept: `\B` gu "aEb" → "a<D83D>#<DE00>b" (Kotlin's today; Swift's is Not planned). Swift pins the
  `a??`… rows as guards.
- B1 Backreferences under `gi`, BMP (33 classes, 78 rows): `(s)\1` "sſ", `(K)\1` "K"+U+212A, `(.)\1`
  "ßẞ", θ/ϴ, Ω/U+2126, Å/U+212B, ᾀ/ᾈ (U+1F80-1FAF, 1FB3/1FBC, 1FC3/1FCC, 1FF3/1FFC) → unchanged; kept:
  `(s)\1` gi "sS" → "#"; under `giu` all "#" (Dart folds simply).
- B2 Kotlin's JVM, ı U+0131 and İ U+0130: `(I)\1` "Iı", `(i)\1` "iı", `(ı)\1` "ıI", "ıi"; `(i)\1`
  "iİ", `(İ)\1` "İi", `(I)\1` "Iİ", `(İ)\1` "İI", "İi̇" (U+0130 i U+0307); gi and giu → unchanged.
  Swift is Dart's on all but the last (B3).
- B3 Swift's ICU, full folding (104 letters with a multi-letter fold, F11): `(ß)\1` "ßss", `(ss)\1`
  "ssß", `(.)\1` "ßss" → "ß#", ﬀ U+FB00/"ff", ŉ U+0149/"ʼn", İ/"i̇" … gi and giu → unchanged; kept
  `(ß)\1` giu "ßẞ" → "#". Kotlin is Dart's on all but İ (B2).
- X1 Render fixture 37: one row per kind from U1, U2, B1 and K1 where bun gives Dart's value and the
  result holds no lone half; green on the engine, Flutter, Swift and Kotlin.

### Groups
Paths from the repo root.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Swift: masked run for UTF-16 units | `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Sources/OrcaGatewayCore/Resolver/RegexMask.swift` (new) · `sdk-swift/Sources/OrcaGatewayCore/Resolver/ValueResolver.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift` | U1, U2, K1 (Swift: a lone half is U+FFFD; K1's rows as guards, not `\B`) | M | none |
| 1 | T2 | Kotlin: masked run, units, pair step | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `…/resolver/RegexMask.kt` (new) · `…/resolver/ValueResolver.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt` | U1, U2, K1 (Kotlin) | M | none |
| 2 | T3 | Swift: backreferences under `i`, letter stand-ins | `…/Resolver/Transforms.swift` · `…/Resolver/RegexMask.swift` · `…/TransformTests.swift` | B1, B3 (Swift); B2 pinned as guards | M | T1 |
| 2 | T4 | Kotlin: backreferences under `i`, letter stand-ins | `…/resolver/Transforms.kt` · `…/resolver/RegexMask.kt` · `…/resolver/TransformTest.kt` | B1, B2 (Kotlin); B3 pinned as guards | M | T2 |
| 3 | T5 | Fixture 37, counts pinned at 37 | `schema/fixtures/render/37_regex_utf16_units_backreferences.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt` | X1 (engine, Flutter, Swift, Kotlin) | M | T1-T4 |
Placed, Swift · Kotlin: U1, U2, K1 T1 · T2; B1 T3 · T4; B2 guards in T3 · T4; B3 T3 · guards in
T4; X1 T5 on all four runners. 5 tasks in 3 groups, at most 2 per group.

### Order, and why each boundary
- Groups 1 and 2 pair a Swift task with a Kotlin task sharing no file; they run side by side, and the
  probe runs once per group.
- 1 → 2: T3/T4 send the letters through the masked run T1/T2 build: the free-unit pool and stand-in
  table (RegexMask), the reader's table parameter and its class writing, groups read from the
  original. A letter's stand-in comes from the same pool as a half's.
- 2 → 3: fixture 37 needs U1, U2, B1 and K1 green in both SDKs; T5 alone owns the count pins.

### Seams
- `Transforms.swift`, `TransformTests.swift`: T1 then T3; `Transforms.kt`, `TransformTest.kt`: T2 then
  T4. `RegexMask.swift` (new) T1 writes, T3 extends; `RegexMask.kt` T2 then T4. `ValueResolver.swift`
  is T1's alone, `ValueResolver.kt` T2's: `matches` reaches the letter masking through the same call.
- Count pins, T5 only, 36 → 37 ("01-37"): ModelRoundTripTests.swift :10, :151; ModelRoundTripTest.kt
  :30, :176; FixturePathsTest.kt :10. The engine and Flutter read the folder (engine/test/
  conformance.test.ts:60, sdk/test/conformance/fixture_paths.dart:23). Stage by path:
  `sdk-kotlin/core/bin/` is untracked IDE output.

### Findings (planner, checked against the code)
- F1 Entry points, two per SDK: the `regex` transform (Swift Transforms.swift:197-226, Kotlin
  Transforms.kt:210-237) and `matches` (Swift ValueResolver.swift:241-247, Kotlin ValueResolver.kt:
  206-211; no flags, as Dart's value_resolver.dart:171). Every other pattern is fixed: Placeholders
  (Swift :351, Kotlin :335), ISO dates (Swift :1209, Kotlin :1205), class probes (Swift :1073, Kotlin
  :969), SwiftText.kt:21.
- F2 Hook: compile never sees the input (Swift :401-412, Kotlin :390-398) and patterns are not cached.
  One function per SDK takes pattern, flags and input, decides (1a)/(1b), builds the table, passes it
  to `asciiClasses` (Swift :538, Kotlin :541; no table is today's path) and searches the copy. The
  copy is valid Unicode (without `u` every half is replaced; with `u` none is), so Swift can search a
  String.
- F3 Reading back: Swift `Match` reads groups from `source` (:388-399), which `wrap` sets to the string
  it searched (:1134-1136): point it at the original NSString. Kotlin `Match` reads `result.group(i)`
  (:382-388), the matcher's text: read `original.substring(start(i), end(i))`. Segments, `$n`
  (`expandBackrefs`: Swift :1150-1166, Kotlin :1174-1191) and `{{value}}` read through these.
- F4 Swift output: `out += source.substring(…)` per segment (:217-224) would make each half its own
  U+FFFD and break `x*` g on E with replacement "" (E in Dart and Swift today). T1 builds the output
  as UTF-16 units and decodes once with `String(decoding:as: UTF16.self)`. A half joined through `$n`
  or `{{value}}` (Strings) stays U+FFFD: question 5 covers it. Kotlin's StringBuilder keeps Dart's units.
- F5 Pattern side: Swift reads scalars (`p` :570), so a literal above U+FFFF is one atom (`take(1)`
  :1015; class member :824-826): T1 splits it into two stand-ins before the reader, leaving group
  names alone; a `\uHHHH` half is copied as text (:942; class :811) and becomes its stand-in. Kotlin
  reads Chars, so without `u` a half is already an atom (`classAtom` :1025, literal :678-681); `escape`
  keeps `\uD83D` as written (:1067): T2 replaces it.
- F6 Ranges: Swift checks order on code points (:862-863), Kotlin leaves it to the engine (:920-921,
  :946). With stand-ins both check order on Dart's units (`[-\uD83D]` stays null); a range is written
  as its parts outside the surrogate block plus the stand-ins of the halves it covers.
- F7 Stand-ins, per call: the distinct surrogate units of input and pattern (at most 2 048), then the
  letters of point 3 the input holds, take the lowest units in U+E000-F8FF that neither holds (as a
  character or a `\uHHHH`/`\u{…}` value, read conservatively); a class part that reaches into the PUA
  leaves the stand-ins out (ICU `[[…]--[…]]`, Java `[…&&[^…]]`). The pool runs out past ~4 350
  distinct PUA characters in one input; that call runs unmasked (a pinned known difference).
- F8 Classes in (1b): Swift `Kept`/`dartFolded` (:1040-1105; lookahead :1065, M :1072-1084) and Kotlin
  `dartClass` (:967-983; lookahead :980, M :979-981) keep table letters from the engine's folding; in
  a masked run the lookahead also takes the stand-ins and M writes a masked letter as its stand-in.
  For `\p{…}` (Kotlin giu, ı) a class, escape or property adds the stand-ins of the masked letters
  Dart matches with it (a negated one leaves them out), with the same one-pass probe; sets are
  written by Swift `spelled` (:1109-1121) and Kotlin's appends (:622, :675).
- F9 "`i` in the flags" misses `(?i:…)`: trigger on any `i` in force (Swift `modifiers` :668-684,
  Kotlin `groupOpening` :860-870) plus a backreference the reader writes (Swift `reference` :876-880
  via :912-922, Kotlin :591-617). Masking where it is not needed gives the same result.
- F10 B1's 78 Swift rows are 39 ordered pairs × 2 forms over 33 classes: K U+212A, ſ, Å U+212B, ϴ, Ω
  U+2126, ẞ/ß and 27 Greek pairs (ᾈ-ᾏ, ᾘ-ᾟ, ᾨ-ᾯ, ᾼ, ῌ, ῼ with their lower forms). In each Dart keeps
  one letter alone and the rest fold as the engine folds them, so one stand-in per class is enough;
  Dart's sets come from DartFoldTable. Kotlin adds ı (and İ, F11).
- F11 Probed at this card (`s16/oracle/f11*`): Kotlin pairs İ with i and I in a backreference (JVM
  CIBackRef, toLowerCase(İ) = i): 20 rows → B2. Swift's ICU compares backreferences by full folding
  (rematch.cpp): all 104 multi-letter-fold letters differ under gi and giu, 624 rows, plus `(İ)\1`
  "İi̇" → B3. Under giu Dart unites ß with ẞ: one stand-in per Dart class keeps that a match.
- F12 K1: Kotlin `allMatches` loops on `m.find()` (:1162-1166), one unit after an empty match; with
  `u`, after an empty match at a high half before its low half, T2 calls `m.find(i + 2)` (the reset
  keeps `^` at 0, lookbehinds see the whole input). Swift (ICU, :1143-1146) already steps a code point.
- F13 No row pins today's wrong behavior on halves: every supplementary row runs with `u` (Swift
  TransformTests.swift:789-795, :1190, :1217, :1650-1682; Kotlin TransformTest.kt:847-849, :885,
  :1014, :1047-1055, :1871-1959); `(?<sik>s)\k<sik>` gi "sSx" → "#x" (TransformTest.kt:467) guards the
  unmasked reference. No case covers `matches`: T1 and T2 add `^.$` and `^..$` on E.
- F14 Swift's per-group probe check reads each lone half in Dart's value as U+FFFD (question 5).

### Done when
- test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` and
  `xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=FDE5D612-86BA-4138-A1BD-1AB2CF9E8773'`
  · `cd sdk-kotlin && ./gradlew build`
- lint: `cd sdk && flutter analyze` · Android lint inside `./gradlew build`
- typecheck: none (the compilers)
- baseline: engine 703 pass, 1 fail (EADDRINUSE on :8080, Docker) · Flutter +243 · analyze no issues ·
  Swift 198 · iOS 54 + 198 · Kotlin core 197, sdk 128 · lint no issues, 2026-11-13 (Flutter 3.50.0)
- and the probe (`s16/oracle`, Dart 3.14.0) after each group: no Swift or Kotlin difference left in
  the group's rows, Unicode 17 rows aside, a lone half read as U+FFFD for Swift.
- commits: per task · gate: per group (answered at gate 08, 2026-11-13, with your "A, approve":
  every default; question 4: Unicode 17 moves to a new epic row 23b.39; questions 5 and 6: Swift's
  U+FFFD for a lone half and its `\B` inside a pair with `u` are known differences, written into
  row 23b.38)

### Not planned
- Swift, `\B` with `u` inside a pair (`\B` gu and giu "aEb" → "a<D83D>#<DE00>b"): ICU never starts a
  search inside a pair (question 6).
- Unicode 17 (question 4, proposed row 23b.39): the 448 rows with U+A7CE, A7CF, A7D2, A7D4,
  U+16EA0-16ED3, and the scripts Sidetic, Tolong_Siki, Beria_Erfe, Tai_Yo; S14/S15's tables follow
  Dart 3.12.2.
- A `(?-i:…)` group inside an `i` pattern with a backreference, over letters of one masked class
  (e.g. ß and ẞ under giu): they share a stand-in, so the group can't tell them apart (your
  modifier-group call: a known limit).
- An input with more than ~4 350 distinct private-use characters runs unmasked (F7).
