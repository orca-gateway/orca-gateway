# 08 · Tasks · native-sdk-s15

## Front page

### In one breath
tasks: 11 in 6 groups · widest group: 2 · cases: 6 of 6 placed (5 rows left out) · Swift, Kotlin
S15 is 23b.37's pattern side: Swift and Kotlin read a regex token by token as Dart does.
Probe: 431 of 718 cases differ from Dart today; 233 short rows, printed by Dart, are the cases.
G1: quantifiers: `a++`, `^*`, `\b*` give null, as in Dart; the reader learns each group's kind.
G2: Annex B without `u`: `\A` is "A", `\p{L}` is "p{L}", `{` literal, `\8`, octal, `[]`, `[^]`.
G3: with `u`, null wherever Dart refuses: `\-`, `}`, `\00`, `[a-\d]`, `(?=a)*`.
G4: group names dropped (`$a`, `é`, one name twice); `\1(a)` matches empty, as in Dart.
G5: `\P{Ll}` under `iu`; exact script values. G6: fixtures 35-36. In each group Swift and Kotlin run
side by side.

### New for you
1. Annex B, the lenient regex grammar without `u` → learning/regex-annex-b.md

### Trade-offs
2 needs you: split off input masking (question 4); JVM-only property names (question 5).
6 auto-decided: serial groups (your call, S13); one reader; names dropped; Dart's tables; refs.

### Questions for you
1. Commands: every suite, as at S14 (bun, flutter, swift + iOS, gradlew). (default: as found)
2. Commits: one per task on feat/native-sdk-s15; nothing pushed before 10. (default: yes)
3. One gate per group, 6 groups. (default: yes)
4. Major: backrefs under `i` and UTF-16 units without `u` need the input masked, not the pattern
   rewritten. Move them to a new row 23b.38 (S16)? (default: yes, S15 is the pattern side)
5. Major: the JVM lacks `scx=` and 33 binary properties (62 names); Android's ICU reads them.
   Leave them null on a desktop JVM, or add Dart-printed tables (~90 KB)? (default: leave)
6. `(a)?b\1`, a group unset only at run time, stays a known difference. (default: yes)

## Appendix

### Where S15 comes from
Epic row 23b.37, written at S14 gate 08 and grown during S14: backreferences under `i`; UTF-16 code
units without `u`; Annex B and engine-only syntax (`\p` without `u`, braces, `\u{73}` without `u`,
`\x{73}`, `\A \z \Z \G \Q…\E \h \R \X \e \N{…} \o{…}`, possessive quantifiers, POSIX classes, `[]`,
`[^]`, `\0 \8 \a`, identity escapes with `u`, duplicate group names, `\k` with no named group, forward
references, `[a-\d]` and `[\p{L}-z]` with `u`, `(?=a)*`); `\P{…}` and `[^\p{…}]` under `iu`; on the JVM
`\p{ASCII}`/`\p{Lt}` under `iu`, Script_Extensions, 62 binary names, Emoji on JDK 17, `Script=Qaai`;
loose script values. Done when: "A TransformTests / TransformTest row per corner with Dart's printed
value, or a render fixture where the engine can express it". S15 started on your "ok start" after
native-sdk-s14 closed; stages 01-07 skipped as covered by native-sdk. Branch feat/native-sdk-s15 from
main 95bd5c8 (PR #21's merge), S14's closing notes cherry-picked (2313bcc).

### Checked before planning (2026-11-11)
S14's probe re-run on main: unchanged from S14's last run (`s14/oracle`, 8 991 cases). A new probe,
718 cases through Dart 3.12.2, the Swift SDK (macOS) and the Kotlin SDK (core classes, JDK 25),
session scratchpad `s15/oracle/a1/` (gen.py, dart.dart, show.py):
| kind | cases | Swift ≠ Dart | Kotlin ≠ Dart |
|---|---|---|---|
| `\` + letter (`\A`, `\Q`, `\K`…) | 99 | 60 | 78 |
| `\` + punctuation | 66 | 18 | 18 |
| `[\` + punctuation`]` | 66 | 17 | 17 |
| braces `{ } ]` | 36 | 12 | 16 |
| quantifiers (`a++`, `(?=a)*`, `^*`) | 44 | 23 | 25 |
| `\c` | 22 | 10 | 12 |
| `\x`, `\u` short or braced | 34 | 17 | 15 |
| `\0`, `\1`…`\9`, octal | 44 | 25 | 28 |
| group names, `\k` | 36 | 16 | 14 |
| `\p` without and with `u` | 22 | 11 | 11 |
| classes (`[]`, `[^]`, `[[:a:]]`, `&&`, ranges) | 70 | 42 | 34 |
| reference to a group that did not take part | 10 | 10 | 10 |
| reference before its group closes | 12 | 12 | 12 |
| `\A \z \G \Q \N{} \o{} \h \R \X \e \K` | 45 | 32 | 34 |
| `\P{…}`, `[^\p{…}]` under `iu` | 40 | 10 | 13 |
| script values, `scx` | 72 | 18 | 30 |
| all | 718 | 333 | 367 |
Then 233 short rows (`s15/oracle/rows/rows.txt`, Dart's value per row; 129 differ in Swift or Kotlin
today). What they show:
- Without `u` Dart reads Annex B: an unknown escape is the letter (`\A` g "aA" → "a#"), `\p{L}` is the
  text "p{L}", `{` and `}` are literal unless they make a quantifier, `\u61` is "u61", `\8` is "8",
  `\377` is ÿ, `[]` matches nothing, `[^]` anything, `(?=a)*` is allowed. ICU and the JVM read
  `\A`, `\Q`, `\h`, `\R`, `\X`, POSIX `[[:alpha:]]`, `&&` and `{,3}` their own way or refuse them.
- With `u` Dart refuses every identity escape of a non-syntax character, lone braces, `\00`, `\8`,
  bad `\c`, ranges with class escapes and quantified lookaheads; both engines accept most of them.
- In both modes Dart refuses possessive quantifiers (`a++`) and quantified assertions (`^*`, `\b*`).
- Group names: Dart accepts `(?<$a>x)`, `(?<é>x)` and one name in two alternatives; both engines
  refuse them. A reference to a group that cannot have matched yet is empty in Dart, a failure in
  both engines (`\1(a)` g "aa" → "##"; `(a)|\1b`).
- Under `iu` Dart folds a property's set after negating: `\P{Ll}` matches every letter, both engines
  none of the cased ones. ICU accepts loose script values (`latin`, `Hrkt`, ` Latin`) Dart refuses.
- Dart's tables, printed for S15 (`s15/oracle/tables/`): 1 454 simple-fold classes under `u` (2 938
  code points, 282 classes above U+FFFF: Deseret, Osage, Vithkuqi, Old Hungarian, Garay, Warang Citi,
  Medefaidrin, Adlam; candidates from Python's Unicode 17 case maps, every member checked against
  Dart); 336 script values (long names and codes, Unicode 16,
  `Qaai`, `Qaac`; `Hrkt` refused). JDK 25 refuses only `Qaai` and `Qaac`; JDK 21 also the 7 Unicode 16
  scripts, JDK 17 another 12.
- bun (JSC) gives Dart's value on 219 of the 233 rows; the 14 others are properties under `iu`, where
  JSC does not fold (so those stay TransformTests rows, not fixtures).
- Sizes for question 5 (Dart, every code point): the 33 binary properties the JVM lacks hold 8 231
  ranges, the Emoji six 359, Script_Extensions over Script 505.
Baseline (all suites, `s15/base-*.log`): engine 703 pass · Flutter +241 · analyze no issues · Swift 168
· iOS 54 + 168 · Kotlin core 151, sdk 128 · lint no issues.

### Design (written here; 05-07 skipped)
In full in the session scratchpad (`s15/design.md`), pasted to the planner. S14's rewriter stays; it
reads every token as ECMAScript does instead of copying the ones it does not know.
0. A pre-pass counts capturing groups and collects names: `\N` is a backreference only when N is at
   most the count, and `\k` is a letter only when the pattern has no named group.
1. Without `u`, Annex B: unknown letter escapes are the letter; `\p`, `\P`, `\k` letters; `\c`, `\x`,
   `\u` fall back to letters; decimal escapes are backreference, legacy octal or digit; non-quantifier
   braces and a lone `]` literal; `[]`, `[^]`; `[ & ~ -` escaped in classes; class-escape ranges a
   union; lookaheads quantified as `(?:(?=a))*`.
2. With `u`, null wherever Dart refuses (the A2 rows).
3. Both modes: null for a quantifier on a quantifier or an assertion.
4. Group names dropped, numbers kept; `\k<name>` the number(s); a reference that can only see an unset
   group (before its group closes, or in a sibling alternative) is `(?:)`.
5. Under `iu`, a class or escape holding `\p`/`\P` goes S14's `dartFolded` way over Dart's simple-fold
   classes instead of the 217 table letters; script values exactly Dart's; on the JVM `Qaai`/`Zinh` →
   `Inherited`, `Qaac` → `Coptic`.
6. Render fixtures 35-36 pin rows where bun gives Dart's value.

### Cases (Dart's values; all rows in `s15/oracle/rows/rows.txt`)
- A1 Annex B, `g`: `\A` "aA" → "a#"; `\Qa\E` "QaE a" → "# a"; `\p{L}` "p{L} a" → "# a"; `{` "{x}" →
  "#x}"; `}` "{x}" → "{x#"; `x{,3}` "x{,3} x" → "# x"; `a{1,` "a{1, a" → "# a"; `\u61` "u61 a" → "# a";
  `\u{3}` "uuu u" → "# u"; `\x{2}` "xx x" → "# x"; `\c1` "\c1" → "#"; `[\c1]` "\u0011 c 1" → "# c 1";
  `\0` "a\0" → "a#"; `\377` "ÿ" → "#"; `\400` " 0" → "#"; `\18` "\u00018" → "#"; `\8` "8" → "#"; `\k`
  "k" → "#"; `[]` "ab" → "ab"; `[^]` "a\nb" → "###"; `[[:alpha:]]` "a:] a" → "a# a"; `[a&&b]` "a&b" →
  "###"; `[a--b]` → null; `[a-\d]` "a-1b" → "###b"; `[\B]` "Bb" → "#b"; `(?=a)*` "ab" → "#a#b#";
  `(?=a){2}` "ab" → "#ab"; gi: `\K` "kKK" → "##K", `\p{L}` "p{L} P{l}" → "# #".
- A2 With `u`, null: `\A`, `\z`, `\-`, `\%`, `\_`, `\a`, `}`, `]`, `\00`, `\01`, `\8`, `\c1`, `\c`,
  `[\c_]`, `\x6`, `[a-\d]`, `[\d-z]`, `[\w-a]`, `[\p{L}-z]`, `[a-\p{L}]`, `(?=a)*`, `(?!a)?`, `[\k]`,
  `[\B]`, `[\a]`, `[\_]`, `[\1]`, `[\8]`, `[\00]`; kept: `\/` "a/" → "a#", `\^`, `\$`, `[\-]` "-a" →
  "#a", `[\b]`, `\0` and `[\0]` "a\0" → "a#", `\cA`.
- A3 Both modes, null: `a++`, `a*+`, `a?+`, `a{1,2}+`, `a{1}{2}`, `{3}`, `a**`, `^*`, `$+`, `\b*`,
  `\B+`, `(?<=a)*`, `(?<!a)+`, `a{2,1}`; kept: `a+?` "aaa" → "###", `a??` → "#a#a#a#", `(?:)*`, `()+`.
- G3 Groups, `g` and `gu`: `(?<$a>x)` and `(?<é>x)` "x" → "#"; `(?<a>x)|(?<a>y)` "xy" → "##";
  `(?:(?<a>x)|(?<a>y))\k<a>` "xx yy xy" → "# # xy"; `\k<a>(?<a>x)` "xx" → "##"; null:
  `(?<a>x)(?<a>y)`, `(?<a>x)\k<b>`, `(?<a>x)\k`, `(?<a>x)\k<a`, `(?<a>x)[\k]`; `\1(a)` "aa" → "##";
  `(a\1)` → "##"; `(a)|\1b` "ab b" → "## #"; `(a)|b\1` → "## #"; `\2(a)(b)` "ab" → "#";
  `(?:\1b|(a))+` "ab" → "#"; `g` only: `(a)\2` "a\u0002" → "#", `(a)\10` "a\u0008" → "#", `(a)\8` "a8"
  → "#" (with `u` all three null).
- G4 Under `giu`, input "sSſkKK_!éÉǅǄǆßẞ": `\P{Ll}`, `\P{Lu}`, `\P{Lt}`, `[\P{Ll}]`, `[\P{Ll}\d]`,
  `\P{Lowercase}` → all "#"; `[^\P{Ll}]` → unchanged; `\P{ASCII}` → "######_!#######"; JVM `\p{Lt}` →
  "sSſkKK_!éÉ###ßẞ", `\p{ASCII}` → "########éÉǅǄǆßẞ". Under `gu`, input "aὰⲁ゛॑": null for
  `\p{Script=latin}`, `\p{sc=latn}`, `\p{Script=Hrkt}`, `\p{Script=Katakana_Or_Hiragana}`, `\p{Script=
  Latin}`, `\p{Script=Latin }`, `\p{Script=OldItalic}`, `\p{scx=latin}`; kept `\p{Script=Latn}`
  "#α…", `\p{Script=Old_Italic}`, `\p{Script=Zzzz}`; JVM `\p{Script=Qaai}` → "aα#ⲁ゛#",
  `\p{Script=Qaac}` → "aὰ#゛॑", `\p{scx=Qaai}` unchanged.
- X1 Render fixtures 35-36: a selection of A1-A3, G3 and the script rows (bun = Dart), green on the
  engine, Flutter, Swift and Kotlin.

### Groups
Paths from the repo root.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Swift: quantifiers on quantifiers, assertions | `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift` | A3 (Swift) | S | none |
| 1 | T2 | Kotlin: quantifiers on quantifiers, assertions | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt` | A3 (Kotlin) | S | none |
| 2 | T3 | Swift: pre-pass, Annex B without `u` | `…/Resolver/Transforms.swift` · `…/TransformTests.swift` | A1 (Swift) | S | T1 |
| 2 | T4 | Kotlin: pre-pass, Annex B without `u` | `…/resolver/Transforms.kt` · `…/resolver/TransformTest.kt` | A1 (Kotlin) | S | T2 |
| 3 | T5 | Swift: strict grammar under `u` | `…/Resolver/Transforms.swift` · `…/TransformTests.swift` | A2 (Swift) | S | T3 |
| 3 | T6 | Kotlin: strict grammar under `u` | `…/resolver/Transforms.kt` · `…/resolver/TransformTest.kt` | A2 (Kotlin) | S | T4 |
| 4 | T7 | Swift: drop names, empty unset backreferences | `…/Resolver/Transforms.swift` · `…/TransformTests.swift` | G3 (Swift; not the 4 rows under Not planned) | S | T1, T3 |
| 4 | T8 | Kotlin: drop names, empty unset backreferences | `…/resolver/Transforms.kt` · `…/resolver/TransformTest.kt` | G3 (Kotlin; not the 4 rows under Not planned) | S | T2, T4 |
| 5 | T9 | Swift: `iu` properties, exact script values | `…/Resolver/Transforms.swift` · `sdk-swift/Sources/OrcaGatewayCore/Resolver/RegexPropertyNames.swift` · `sdk-swift/Sources/OrcaGatewayCore/Resolver/DartFoldClasses.swift` (new) · `…/TransformTests.swift` | G4 (Swift) | M | T5 |
| 5 | T10 | Kotlin: `iu` properties, scripts, JVM aliases | `…/resolver/Transforms.kt` · `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/RegexPropertyNames.kt` · `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/DartFoldClasses.kt` (new) · `…/resolver/TransformTest.kt` | G4 (Kotlin, with Qaai/Zinh → Inherited, Qaac → Coptic; not `\p{scx=Qaai}`) | M | T6 |
| 6 | T11 | Fixtures 35-36, counts pinned at 36 | `schema/fixtures/render/35_regex_annex_b_strict_unicode.json` (new) · `schema/fixtures/render/36_regex_group_names_script_values.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt` | X1 (engine, Flutter, Swift, Kotlin) | M | T1-T10 |
Placed, Swift · Kotlin: A3 T1 · T2; A1 T3 · T4; A2 T5 · T6; G3 T7 · T8; G4 T9 · T10; X1 T11 on all
four runners. 11 tasks in 6 groups, at most 2 per group. `…/` abbreviates the folder in the rows above.

### Order, and why each boundary
- Groups 1-5 pair a Swift task with a Kotlin task sharing no file; they run side by side, and the
  probe runs once per group.
- 1 → 2: T3/T4 make a brace literal only where T1/T2's quantifier reader finds no `{n}`, `{n,}` or
  `{n,m}`, and write a quantified lookahead `(?:(?=a))*` from the group kind and output offset T1/T2
  keep for each open group.
- 2 → 3: T5/T6 give null under `u` in the branches T3/T4 write (escapes, braces, classes) and read
  `\N` and `\k` through T3/T4's pre-pass (group count, names).
- 3 → 4: T7/T8 take numbers for names from the pre-pass, track alternatives on T1/T2's group stack,
  and extend the `\k` branch T5/T6 made strict.
- 4 → 5: no call between them; the shared files force the order (G5 could equally go first).
- 5 → 6: fixture 35 needs A1/A2 green in both SDKs, 36 needs G3 and the script rows; T11 alone
  owns the count pins.

### Seams
- `Transforms.swift` and `TransformTests.swift`: T1, T3, T5, T7, T9, one per group in that order;
  `Transforms.kt` and `TransformTest.kt`: T2, T4, T6, T8, T10 the same way.
- New files and the property names, one writer each: `RegexPropertyNames.swift`, `DartFoldClasses.swift`
  T9; `RegexPropertyNames.kt`, `DartFoldClasses.kt` T10.
- The fixture count pins: T11 only, 34 → 36 ("01-36"): ModelRoundTripTests.swift :10 and :151,
  ModelRoundTripTest.kt :30 and :176, FixturePathsTest.kt :10. Staged by path (`sdk-kotlin/core/bin/`
  is untracked IDE output).

### Findings (planner, checked against the code)
- F1 Kotlin's fast path (Transforms.kt:450) returns a pattern without `i`, `\`, `[` and `(` untouched,
  so `{`, `}`, `]`, `x{,3}`, `a{1`, `a++`, `^*`, `$+`, `{3}` never reach the reader. T2 removes it or
  narrows it to patterns with no syntax character.
- F2 The group stack holds only the `i` (Swift `scope: [Bool]` :476, Kotlin `open` :451). T1/T2 widen an
  entry to the group's kind and output offset; T7/T8 add the alternatives seen.
- F3 `\b`/`\B` are written as lookaround groups (Swift :466-469, :589-591; Kotlin :467-468), which both
  engines let a quantifier follow: why `\b*` differs today. T1/T2 mark them assertions.
- F4 Escapes are copied: Swift `take(n == "c" ? 3 : 2)` :610, `\k<…>` :592-593, `\p{…}` without `u`
  :594-596; Kotlin `escapeEnd` :593-606. An identity-escaped letter must reach the fold branch (Swift
  :629-631, Kotlin :493) so `\K` gi gives "##K".
- F5 Classes: Swift `classSet` (:548-576) copies `[`, `&`, `~`, `-` as written (:568-570) and an unknown
  escape as `\X` (:573); Kotlin `characterClass` escapes only `[` (:546) and stops at the first `]`
  (:543), so `[]` and `[^]` reach the engine as they are.
- F6 Group names and `\k<name>` are copied (Swift :618-619, :592-593; Kotlin :517, :600). Dropping them
  is safe: replacements read only `$1`-`$9` (Swift :699-715, Kotlin :708-725); no source reads a
  group by name.
- F7 The pre-pass reuses the group-opening tests (Swift :614-619, Kotlin :511-517), skips classes and
  escapes, and counts `(` without `?` plus `(?<name>`, not `(?<=`/`(?<!`.
- F8 Some rows go green early: the G3 escape rows (`(a)\2`, `(a)\8`, `(a)\10`) after T3-T6, A2's `\0`
  and `[\0]` gu after T3/T4. Each stays pinned under its own task's `// MARK: S15`.
- F9 Swift's `iu` path: `dartFolded` (:656-669) and `notFoldLetter` (:650) are built on the 217 table
  letters; `spelled` (:672-674) writes `\u%04X`, wrong above U+FFFF; those members need `\x{…}` as
  `braced` (:536) writes them.
- F10 Kotlin handles the BMP only there: `DartFoldTable.set(c: Char…)` (DartFoldTable.kt:31), `it <=
  0xFFFF` (Transforms.kt:476), a members test over Chars (:578-581). T10 keys DartFoldClasses by code
  point.
- F11 The fold-class table the planner read was short (1 014 classes, Deseret the only script above
  U+FFFF: candidates came from Dart's own case mapping). Regenerated before this card from Python's
  Unicode 17 case maps, each class checked against Dart: 1 454 classes, 2 938 code points, 282 above
  U+FFFF (`s15/oracle/tables/fold-classes-u.txt`, `classes2.dart`).
- F12 Script values: Swift (RegexPropertyNames.swift:18) and Kotlin (RegexPropertyNames.kt:27) accept
  any non-empty value; Kotlin `jvm` passes `Script=` through (:43) and gives null for scx (:44). Dart
  accepts the same 336 values under `scx=` as under `Script=` (checked with tables.dart).
- F13 Rows already green guard the `iu` path: Swift TransformTests.swift:530-532, :855, :862, :864,
  :866, :870, :873; Kotlin TransformTest.kt:560-562, :971-979, :996-997, :1011, :1016, :1020, :1071.
  Patterns are not cached (Transforms.swift:203, Transforms.kt:214); Swift :904-924 compiles 690 giu
  property patterns, so the new path's cost shows there.
- F14 Swift :839-849 only checks non-null ("its matches are row 23b.37's"); T3 replaces it with Dart's
  values. Kotlin's rejects (TransformTest.kt:922: `\pL`, `\p`, `\P` under gu/giu) stay null under T6.
- F15 Doc comments describing today's copying change with their task: Swift :414-418, :455-458;
  Kotlin :432-447.
- F16 bun gives Dart's value on every A1, A2, A3, G3 and script row, and differs on 14 of the 16 `iu`
  property rows (rows.txt:198-213; the engine checks `expected`, conformance.test.ts:92-108). Those
  stay TransformTests rows, as the design says; fixtures leave them out, and the run-time-unset rows.

### Done when
- test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` and
  `xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=FDE5D612-86BA-4138-A1BD-1AB2CF9E8773'`
  · `cd sdk-kotlin && ./gradlew build`
- lint: `cd sdk && flutter analyze` · Android lint inside `./gradlew build`
- typecheck: none (the compilers)
- baseline: engine 703 pass 0 fail · Flutter +241 · analyze no issues · Swift 168 · iOS 54 + 168 ·
  Kotlin core 151, sdk 128 · lint no issues, 2026-11-11
- and the probe (`s15/oracle/{a1,rows}`) after each group: no Swift or Kotlin difference left in the
  group's rows.
- commits: per task · gate: per group (answered at gate 08, 2026-11-11, with your standing rule, "all
  incoming questions approved, unless there is something needs a big change…": every default; question
  4: input masking moved to the new epic row 23b.38; question 5: JVM-only names stay null on a desktop
  JVM, no tables; question 6: a group unset only at run time stays a known difference, written into
  row 23b.37)

### Not planned
- Input masking, proposed as row 23b.38 (question 4): backreferences under `i` (`(s)\1` gi "sſ": Dart
  no match, both SDKs match; `(.)\1` gi "ßẞ"; "ıI" on the JVM); UTF-16 units without `u` (`.` g "😀x"
  → "###", both SDKs "##"; `[^a]`, `\S`, `[😀]`, `\uD83D`; the empty matches between a pair's halves,
  `a??` g); supplementary letters fold only with `u` (`𐐀` gi "𐐨": Dart no match); Kotlin's empty match
  inside a pair with `u` (`a??` gu). Each needs the input's text swapped for same-length stand-ins and
  read back from the original.
- A group unset only at run time (`(?:(a)|b)\1` g "b ab aa" → "# a# #", `(a)?b\1`): Dart matches
  empty, both engines fail, and neither has a construct that tells "unset" from "set elsewhere"
  (question 6).
- On a desktop JVM (question 5): `Script_Extensions`/`scx=` (the row `\p{scx=Qaai}` gu, Kotlin), the 33 binary properties it lacks (62
  names), the Emoji six on JDK 17, and the scripts newer than a JDK's Unicode (JDK 21: Garay and six
  more; JDK 17: also Kawi, Nag_Mundari, Vithkuqi …). Android's java.util.regex is ICU and reads them.
