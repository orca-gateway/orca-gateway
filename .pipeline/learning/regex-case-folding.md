---
topic: regex-case-folding
status: new
first_seen: native-sdk-s12/08 2026-11-08
seen: native-sdk-s12/08, native-sdk-s12/09
---
# Regex case folding

**Concept**  With the `i` flag a regex compares letters after mapping both sides to one "case form".
Engines pick different maps: Dart (JavaScript rules) without `u` never maps a non-ASCII letter to
ASCII; with `u`, and in ICU, ſ folds to s and the Kelvin sign K to k; Java also folds ı and İ to i.

**Why here**  Only four letters fold into ASCII (ſ, K, ı, İ), so Swift and Kotlin can match Dart
by rewriting the pattern for those four instead of trusting their engine's folding.

**When not**  For text people search, Unicode folding is usually what you want; here the goal is
the same result as Dart on every phone.

**Tiny example**  Dart `RegExp('s', caseSensitive: false).hasMatch('ſ')` is false; ICU says true.

**Go deeper**  https://tc39.es/ecma262/#sec-runtime-semantics-canonicalize-ch ·
`.pipeline/native-sdk-s12/08-tasks.md` (R2)
