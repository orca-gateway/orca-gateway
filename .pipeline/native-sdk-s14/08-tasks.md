# 08 · Tasks · native-sdk-s14

## Front page

### In one breath
tasks: 9 in 5 groups · widest group: 2 · cases: 6 of 6 placed (M1 M2 F1 E1 P1 X1) · Swift, Kotlin
S14 is 23b.36: Swift and Kotlin read regex corners as Dart does. A probe of 8 991 cases found them.
G1: modifier groups `(?i:…)` keep their own `i`; `(?` forms Dart rejects (`(?i)a`) give null.
G2: a 217-letter table of Dart's folding: Å Ω ẞ, ligatures (Swift matches "ff" to ﬀ).
G3: escaped letters (`\x73`) fold as the letter; `\u{…}` with `u` works (null in both today).
G4: `\p{…}` names Dart lacks give null; Kotlin on the JVM reads `\p{Lowercase_Letter}`.
G5: fixtures 33-34 pin it on the engine, Flutter, Swift, Kotlin. Groups 1-4: Swift ∥ Kotlin.

### New for you
nothing new

### Trade-offs
1 needs you: backreferences under `i` — no pattern rewrite reaches them (question 4).
1 auto-decided: shared files in serial groups, one gate each (your call, 2026-11-11).
5 auto-decided: Dart-printed table; all 217 letters; fixtures last; exact names; JVM check.

### Questions for you
1. Commands: every suite, as at S13 (bun, flutter, swift + iOS, gradlew). (default: as found)
2. Commits: one per task on feat/native-sdk-s14; nothing pushed before 10. (default: yes)
3. One gate per group, 5 groups. (default: yes)
4. Major: `(s)\1` gi on "sſ" matches in both SDKs, not Dart; no rewrite fixes it. Leave it for
   23b.37? Else S14 changes design: mask the table's letters in the input. (default: leave it)
5. A new row 23b.37 holds the corners not planned (UTF-16 without `u`, Annex B…). (default: yes)

## Appendix

### Where S14 comes from
Epic row 23b.36, written at S12 gate 09: modifier-group scope; ICU's full folding where the pattern holds
ß or a ligature; escaped letters and backreferences; Kotlin's long `\p{…}` names; patterns Dart rejects
still run in Kotlin. Done when: "A TransformTests / TransformTest row per corner with Dart's printed value,
or a render fixture where the engine can express it". S14 started on your "Start S14" after native-sdk-s13
closed (gate 12 under your standing rule); stages 01-07 skipped as covered by native-sdk. Branch
feat/native-sdk-s14 from main f9d3935 (PR #20's merge), S13's closing notes cherry-picked (cf21b76).

### Checked before planning (2026-11-11)
One case list run through Dart 3.12.2 (the Flutter SDK's regex transform: `replaceAll` with `g`, "#" per
match, null for an invalid pattern), the Swift SDK (`ValueResolver`, macOS) and the Kotlin SDK (core
classes on JDK 25). Scratch programs in the session scratchpad, `s14/oracle/` (gen*.dart, the Swift and
Java probes, show.py):
| corner | cases | Swift ≠ Dart | Kotlin ≠ Dart |
|---|---|---|---|
| modifier groups (`(?i:`, `(?-i:`, nested, `m`, `s`) | 306 | 82 | 86 |
| one cased BMP letter, literal and `[c]`, against its case relatives | 7 880 | 130 | 130 |
| full case foldings (ß, ligatures, ŉ, ᾳ…) both ways, and their pieces | 313 | 150 | 12 |
| escaped letters (`\x73`, `\u017F`, `\u{73}`) | 56 | 17 | 17 |
| backreferences under `i` | 30 | 7 | 13 |
| property escapes (`\p{…}`) | 174 | 76 | 123 |
| syntax Dart rejects or reads another way | 136 | 81 | 77 |
| `\P`, negated sets under `i`/`iu` | 33 | 7 | 8 |
| supplementary letters, UTF-16 units without `u` | 63 | 31 | 31 |
What they show:
- Modifier groups: inside `(?-i:` / `(?i:` both SDKs still fold by the pattern's flags (`(?-i:s)` gi on
  "sS": Dart "#S", both "##"); `(?i:\W)` and `(?-i:\b)` use the pattern's word set.
- One letter: with `giu` every letter matches Dart; with `gi` 65 do not, in both SDKs: Å U+212B, Ω U+2126
  and ϴ U+03F4 match only themselves in Dart (as K does), ẞ only itself, and the 48 Greek letters with
  iota subscript only themselves; the engines fold them. 
- Full folding, Swift (ICU): `ß` matches "ss", `ﬀ` and `[ﬀ]` match "ff", and "ff", "FF", "fl", "ʼn" match
  the ligature, in both modes; Dart never. "st" and "fi" already match Dart (S12 spells s and i out).
  Kotlin (JVM) only differs on ß/ẞ and ﬅ/ﬆ, which it folds one way only.
- Escapes outside a class fold through the engine (`\x73` gi matches ſ); `\u{73}` with `u` is null in both.
- Property escapes: Kotlin returns null for every long name (`Lowercase_Letter`, `Letter`, `Alphabetic`,
  `White_Space`, `Script_Extensions=`…); both accept names Dart rejects (`IsLatin`, `InGreek`, `Latin`,
  `javaLowerCase`, `script=latin`).
- Syntax: both compile `(?i)a`, `(?-:a)`, `(?u:a)`, `(?>a)`, `(?#c)a`…, null in Dart; and many Annex B
  corners (`\p` without `u` is the letter p in Dart, braces, `\A`, `\Q`, possessive, `[]`…).
- The bun engine (JSC) agrees with Dart on every corner tried (`(?-i:s)`, `(?i:s)`, `Å`, `ß`, `ff`,
  `(?i)a`, `\p{Lowercase_Letter}`, `\u{73}`, `(s)\1`), so render fixtures can pin them.
The fold table (`s14/oracle/table/fold-table.tsv`, 217 letters: code point, Dart's set without `u`,
Dart's set with `u`) was printed by Dart from S12's ten, the 65, the 104 letters with a full folding
(Python 3.15's `casefold`, Unicode 17) and the letters that start one, closed over Dart's sets.
Baseline (all suites, `s14/base-*.log`): engine 701 pass · Flutter +239 · analyze no issues · Swift 147 ·
iOS 54 + 147 · Kotlin core 130, sdk 128 · lint no issues.

### Design (written here; 05-07 skipped)
In full in the session scratchpad (`s14/design.md`), pasted to the planner. S12's approach stays: letters
whose folding differs never reach the engine's folding; they become case-sensitive sets of Dart's.
1. Modifier scope: a stack of the effective `i` per open group; letters, classes, `\w \W \b \B` follow it.
2. `(?` forms Dart rejects give null: after `(?` only `:`, `=`, `!`, `<=`, `<!`, `<name>`, or flags from
   `ims` (each once, not both sides empty) then `:`.
3. The fold table: under an effective `i` its 217 letters become Dart's set (without or with `u`),
   outside a class and inside one (S12's `(?:(?!T)C|(?-i:[M]))`).
4. Escapes `\xHH`, `\uHHHH`, `\u{H…}` (with `u`) spelling a table letter are that letter; `\u{H…}`
   becomes the engine's `\x{H…}`.
5. With `u`, `\p{…}` names ECMAScript lacks give null (General_Category and binary names exact; script
   values left to the engine); Kotlin on the JVM translates the long names and aliases, Android keeps
   them as written.
6. Fixtures 33-34 pin a selection on all four runners.

### Cases (Dart's values)
- M1 Modifier scope: `(?-i:s)` gi "sS" → "#S"; `(?i:s)` g "ſsS" → "ſ##"; `(?i:k)` g "kKK" → "##K";
  `(?-i:k)` gi "kKK" → "#KK"; `(?i:ſ)` g "sSſ" → "sS#"; `(?-i:[^s])` gi "sSſx" → "s###"; `(?i:[^s])` g
  "sSſx" → "sS##"; `(?i:\W)` gu "sSſK!" → "sSſK#"; `(?-i:\b)` giu "ſ a" → "ſ #a#"; `(?i:(?-i:s))` gi
  "sS" → "#S"; `(?-i:a)s` gi "aS AS as" → "# AS #"; `(?-i:s)(s)` gi "sS SS" → "# SS"; JVM `(?i:i)` g
  "iIıİ" → "##ıİ".
- M2 null for `(?i)a`, `(?im)a`, `(?i)`, `((?i)s)`, `(?-:a)`, `(?u:a)`, `(?x:a)`, `(?ii:a)`,
  `(?i-i:a)`, `(?-i-m:a)`, `(?>a)`, `(?#c)a`, `(?P<n>a)`, `(?'n'a)`, `(?^:a)`; `matches` gives false.
- F1 Fold table: Å Ω ϴ ẞ ᾀ/ᾈ only themselves under gi, their simple folding under giu; `å` gi "åÅÅ" →
  "##Å"; `ß` gi "ß ss SS ẞ" → "# ss SS ẞ", giu → "# ss SS #"; `ﬀ` gi "ﬀ ff FF" → "# ff FF"; `ff`, `FF`
  gi → "ﬀ # #"; `[ﬀ]` gi → "# ff FF"; `ﬅ` gi "ﬅ st ﬆ" → "# st ﬆ", giu → "# st #"; `ʼn` gi "ŉ ʼn" →
  "ŉ #"; `αι` gi "ᾳ αι" → "ᾳ #"; the same in classes; every table letter by the probe.
- E1 Escapes: `\x73` gi "s S ſ" → "# # ſ"; `\u017F` gi → "s S #"; `\u212A` gi "k K K" → "k K #";
  `\xdf` gi "ß ẞ" → "# ẞ"; `\u1E9E` gi "ß ẞ" → "ß #"; `\u{73}` gu "s S" → "# S", giu "s S ſ" → "# # #";
  `\u{17F}` giu "s S ſ" → "# # #"; `\u{110000}` gu → null; guards `\x0a`, `\x7F`, `\u00ff` unchanged.
- P1 With `u`: null for `\p{IsLatin}`, `\p{InGreek}`, `\p{IsAlphabetic}`, `\p{Latin}`, `\p{Greek}`,
  `\p{Han}`, `\p{javaLowerCase}`, `\p{script=latin}`, `\p{L&}`; Kotlin (JVM) reads as Dart:
  `\p{Lowercase_Letter}`, `Letter`, `Cased_Letter`, `General_Category=Lowercase_Letter`,
  `Decimal_Number`, `Punctuation`, `Space_Separator`, `Uppercase_Letter`, `Titlecase_Letter`,
  `Alphabetic`, `White_Space`, `Any`, `Assigned`, `Uppercase`, `Lowercase`, `Hex_Digit`, `Emoji`,
  `\P{Lowercase_Letter}`, `[^\p{Lowercase_Letter}]`, `[\p{Uppercase_Letter}\d]` (gu).
- X1 Render fixtures 33 (modifier scope, fold table, escapes) and 34 (`(?` rejects, property names),
  green on the engine, Flutter, Swift and Kotlin.

### Groups
Paths from the repo root.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Swift modifier scope and `(?` rejects | `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift` | M1, M2 (Swift) | S | none |
| 1 | T2 | Kotlin modifier scope and `(?` rejects | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt` | M1, M2 (Kotlin) | S | none |
| 2 | T3 | Swift: Dart's 217-letter fold table | `sdk-swift/Sources/OrcaGatewayCore/Resolver/DartFoldTable.swift` (new) · `…/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift` | F1 (Swift) | M | T1 |
| 2 | T4 | Kotlin: Dart's 217-letter fold table | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/DartFoldTable.kt` (new) · `…/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt` | F1 (Kotlin) | M | T2 |
| 3 | T5 | Swift escaped letters, `\u{…}` with `u` | `…/Resolver/Transforms.swift` · `…/TransformTests.swift` | E1 (Swift) | S | T3 |
| 3 | T6 | Kotlin escaped letters, `\u{…}` with `u` | `…/resolver/Transforms.kt` · `…/resolver/TransformTest.kt` | E1 (Kotlin) | S | T4 |
| 4 | T7 | Swift rejects non-ECMAScript property names | `sdk-swift/Sources/OrcaGatewayCore/Resolver/RegexPropertyNames.swift` (new) · `…/Resolver/Transforms.swift` · `…/TransformTests.swift` | P1 (Swift: the rejects) | M | none |
| 4 | T8 | Kotlin property names: rejects, JVM spellings | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/RegexPropertyNames.kt` (new) · `…/resolver/Transforms.kt` · `…/resolver/TransformTest.kt` | P1 (Kotlin: rejects, JVM names) | M | none |
| 5 | T9 | Fixtures 33-34, counts pinned at 34 | `schema/fixtures/render/33_regex_modifier_scope_fold_table.json` (new) · `schema/fixtures/render/34_regex_invalid_groups_property_names.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt` | X1 (engine, Flutter, Swift, Kotlin) | M | T1-T8 |
Placed, Swift · Kotlin: M1 and M2 T1 · T2; F1 T3 · T4; E1 T5 · T6; P1 T7 · T8; X1 T9 on all four
runners. 9 tasks in 5 groups, at most 2 per group. `…/` abbreviates the same folder as the row above.

### Order, and why each boundary
- 1 → 2: the table folds letters by the effective `i` from T1/T2's scope stack, in the same loop.
- 2 → 3: T5/T6 hand escaped letters to the table T3/T4 create, and rely on T3/T4 reading `\xHH` and
  `\uHHHH` whole (F1).
- 3 → 4: T7/T8 change the `\p{` branch of the same files; no other link. Last keeps M → F1 → E1 short.
- 4 → 5: the fixtures land green: 33 needs M1, F1, E1 and 34 needs M2, P1, in both SDKs; one owner for
  the count pins.
- Groups 1-4 pair a Swift task with a Kotlin task sharing no file: they run in parallel, and the probe
  runs once per group.

### Seams
- `Transforms.swift` and `TransformTests.swift`: T1, T3, T5, T7, one per group in that order;
  `Transforms.kt` and `TransformTest.kt`: T2, T4, T6, T8 the same way.
- The fixture count pins: T9 only, 32 → 34 ("01-34"): ModelRoundTripTests.swift :10 and :151,
  ModelRoundTripTest.kt :30 and :176, FixturePathsTest.kt :10.
- New files, one writer each: DartFoldTable.* T3/T4 (T5/T6 only read it); RegexPropertyNames.* T7/T8.

### Findings (planner, checked against the code)
- F1 Both rewriters copy two characters of an escape (Swift `take(n == "c" ? 3 : 2)` :507, Kotlin
  `escapeEnd` :542-551), so the hex digits after `\x`/`\u` go through the letter branch. The table adds
  a, A, f, F: under `i`, `\x0a`, `\x7F` would break. T3/T4 read `\xHH` and `\uHHHH` whole, with guard
  rows (Dart's values).
- F2 M1 and M2 are one parser (T1/T2). `modifiers()` (Swift :465) and `isModifiers` (Kotlin :472) accept
  any run of `ims-`. `(?i)s` under `i` is null today only by accident (the `i` is rewritten as a letter;
  Kotlin's row TransformTest.kt:513 passes that way). `asciiClasses` becomes optional (one caller).
- F3 Kotlin's fast path (Transforms.kt:425) skips patterns without `i`, `\` and `[`, so `(?i:s)` and most
  of M2 never reach the rewriter. T2 removes it or keeps it only for patterns without `(`; row :514's
  comment "without i nothing is rewritten" changes.
- F4 Every branch needs the scope: the word set and `\b`/`\B` lookarounds are built once from the
  pattern's flags (Swift :440-446, Kotlin :426-427) and class folding keys on them (Swift :494, Kotlin
  :447); the group-name and modifier branches push too; a `)` in a class or escaped does not pop; an
  unbalanced `)` does not pop an empty stack.
- F5 The `matches` op compiles with no flags (Swift ValueResolver.swift:244, Kotlin ValueResolver.kt:209);
  Dart's returns false for an invalid pattern. T1/T2 add a guard row: `(?i)a` gives false.
- F6 Test shapes: Swift `assertRegex(pattern, flags, input, expected)` tables under a new `// MARK: S14`
  (TransformTests.swift :377-475; `expected` widened to `String?` by T1); Kotlin `Rx(…, expected:
  String?)` through `assertDart(listOf(…))` (:473-487). Escape rows use two backslashes (`"\\x73"`).
- F7 Doc comments that state today's gaps change with their task: Swift :435-438 (T3, T5); Kotlin
  :417-422 (T2, T6), :370-376 and :406-415 (T4); TransformTest.kt :521-522 becomes a row (T8).
- F8 Neither SDK caches compiled patterns (Transforms.swift:203, Transforms.kt:215): T3/T4 test each
  distinct table set once per class, not 217 × members; the probe shows the time.
- F9 Loose values under an exact name (`\p{Script=latin}`, `\p{Lowercase_letter}`): GC and binary names
  are checked exactly; script values stay with the engine (to 23b.37).
- F10 T8 learns the runtime once, up front (UNICODE_CHARACTER_CLASS), and translates class bodies too
  (`characterClass` compiles `[body]`, :527). No test runs Android's ICU (Robolectric is the JVM).
- F11 T9: in 31/32's shape the engine keeps page-state Values unresolved (shape and watches); Flutter,
  Swift and Kotlin check the results. 34 is the first `resolved` map holding null.
- F12 `sdk-kotlin/core/bin/` (untracked IDE output) holds stale copies of the tests: stage by path.

### Done when
- test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` and
  `xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=FDE5D612-86BA-4138-A1BD-1AB2CF9E8773'`
  · `cd sdk-kotlin && ./gradlew build`
- lint: `cd sdk && flutter analyze` · Android lint inside `./gradlew build`
- typecheck: none (the compilers)
- baseline: engine 701 pass 0 fail · Flutter +239 · analyze no issues · Swift 147 · iOS 54 + 147 ·
  Kotlin core 130, sdk 128 · lint no issues, 2026-11-11
- and the probe (`s14/oracle/`) after each group: no Swift or Kotlin difference left in the group's
  corners.

### Not planned (proposed for a new epic row 23b.37)
- Backreferences under `i` (`(s)\1` gi on "sſ": Dart no match, both SDKs match; `(.)\1` gi on "ßẞ";
  "ıI" on the JVM): the engine compares a captured text with its own folding, which no pattern rewrite
  reaches. A fix would mask the table's letters in the input (each swapped for a private-use character of
  the same UTF-16 length, the text read back from the original): another design than S12's (question 4).
- Without `u` Dart reads UTF-16 code units: `.` on an emoji gives two matches, `[^a]`, `\S` likewise;
  supplementary letters (Deseret, Osage, Adlam…) fold only with `u`.
- Annex B and engine-only syntax: `\p` without `u` is the letter p; literal braces (`{`, `}`, `x{,3}`);
  `\A \z \Z \G \Q…\E \h \R \X \e \N{…} \o{…}`; possessive quantifiers; POSIX `[[:alpha:]]`; `[]`, `[^]`;
  `\0`, `\8`, `\a`; identity escapes with `u` (`\-`, `\%`, `\_`, `]`); duplicate group names; `\k` with no
  named group; forward references `\1(a)`; `[a-\d]` with `u`; `(?=a)*`.
- `\P{…}` and `[^\p{…}]` under `iu` (Dart closes over case first: `\P{Ll}` matches every letter); on the
  JVM `\p{ASCII}`/`\p{Lt}` under `iu`, `Script_Extensions` and the binary properties it lacks; loose
  script values (`\p{Script=latin}`).
- Android's ICU (the Kotlin SDK on a device): not run here; Kotlin's tests run on the JVM.

### Commits on feat/native-sdk-s14 (conventional, per task on your yes to question 2)
fix(sdk-swift) / fix(sdk-kotlin) per task; test(schema) for T9; chore(pipeline) for the notes. Staged by
path (F12). Nothing pushed before stage 10.
