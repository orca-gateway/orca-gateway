---
topic: utf16-code-units
status: new
first_seen: native-sdk-s11/08 2026-11-07
seen: native-sdk-s11/08
---
# Comparing strings: UTF-16 code units or characters

**Concept**  "é" can be stored as one code point (U+00E9) or as two ("e" plus a combining accent).
Dart, like JavaScript and Java, compares the stored UTF-16 units, so the two spellings differ. Swift
compares the characters you see, so it calls them equal.

**Why here**  Flutter (Dart) is the reference, so `eq`, `contains`, `startsWith` and `split("")` in
Swift and Kotlin must compare units too, or one page can resolve differently on each phone.

**When not**  In text a person reads, such as search or sorting, character-level comparison is
usually what you want. Here the goal is the same result on every SDK.

**Tiny example**  Dart: `'é' == 'é'` is false. Swift: `"\u{e9}" == "e\u{301}"` is true.

**Go deeper**  https://dart.dev/libraries/dart-core#strings-and-regular-expressions ·
`.pipeline/native-sdk-s11/08-tasks.md` (P2, F6)
