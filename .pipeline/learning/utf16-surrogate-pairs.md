---
topic: utf16-surrogate-pairs
status: new
first_seen: native-sdk-s16/08 2026-11-13
seen: native-sdk-s16/08
---
# UTF-16 surrogate pairs

**Concept**  UTF-16 stores most characters in one 16-bit unit, but an emoji or any character above
U+FFFF takes two: a "surrogate pair" (a high half D800-DBFF, then a low half DC00-DFFF).
A regex can read text as units (two per emoji) or as characters (one per emoji).

**Why here**  Dart's `RegExp` without `u` reads units, so `.` on "😀" makes two matches; ICU and
Java read characters. S16 hands the engines a copy where each half is its own character.

**When not**  With the `u` flag Dart reads characters too, so nothing is masked there.

**Tiny example**  Dart `'😀'.replaceAll(RegExp('.'), '#')` gives "##"; with `unicode: true`, "#".

**Go deeper**  https://tc39.es/ecma262/#sec-pattern-semantics (the "u" flag) ·
`.pipeline/native-sdk-s16/08-tasks.md`
