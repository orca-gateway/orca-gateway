---
topic: regex-annex-b
status: new
first_seen: native-sdk-s15/08 2026-11-11
seen: native-sdk-s15/08
---
# Regex Annex B

**Concept**  JavaScript regexes have two grammars. Without the `u` flag, Annex B of the spec keeps
old browsers' leniency: an unknown escape like `\A` is just "A", a stray `{` is a literal brace.
With `u` the grammar is strict and those same patterns are errors (null in our transform).

**Why here**  Dart's `RegExp` follows both grammars; ICU (Swift) and Java (Kotlin) read their own,
where `\A` means "start of input" and `{` must start a quantifier, so the same pattern differs.

**When not**  When the engine is yours to pick, write patterns with `u` and escape what you mean.

**Tiny example**  `\p{L}` without `u` matches the text "p{L}"; with `u` it matches any letter.

**Go deeper**  https://tc39.es/ecma262/#sec-regular-expressions-patterns (Annex B.1.2) ·
`.pipeline/native-sdk-s15/08-tasks.md`
