# 10 · UAT · native-sdk-s17

## Front page

### In one breath
PR #25 is open: under `i`, Swift and Kotlin fold letters the platform's Unicode lacks as Dart does.
On JDK 17, backreferences over characters above U+FFFF no longer throw (row 23b.40).
6 tasks, 6 code commits, fixture 38; local suites green; its 8 checks were pending at this card.
The merge is yours; nothing is published (the SDKs ship with their next release tags).

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #25 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT, optional: nothing to see; no example page uses these regex corners. (default: skip)
3. After A: 11 skipped by default; 12 reads PR #25's checks and your merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #25
https://github.com/orca-gateway/orca-gateway/pull/25, opened at this stage after gate 09 was approved
under your standing rule (its last question, "approve the stage; ship pushes the branch and opens the
PR", was minor, as at S15's and S16's gate 09). Bound to this session, Auto-fix off, auto-merge off.
Title "fix(sdk-swift, sdk-kotlin): under i, letters the platform's Unicode lacks fold as in Dart; JDK 17
backreferences (S17)". Before the push `origin/main` was 2b4daeb (PR #24's merge), already in the branch.
Over main: the S16 close note (c161fbb), the S17 pipeline notes (e56bd4b, 6da23f7, 99bc3c7, 4d782c4,
76dbea4), and the code, one commit per task: T2 bea0d78, T1 17e2887, T3 80bf0f0, T4 66f297e, T5 9bc3774,
T6 fe3e5ce.
Read once at this card (`get_status`): open; 0 passing, 8 pending, 0 failing.
Expected checks, by path filters (`sdk-swift/`, `sdk-kotlin/`, `schema/` and `.pipeline/` change): SDK
Swift (core tests, swift 5.10-jammy and 6.2-noble, linux), SDK Swift UI (iOS simulator), SDK Kotlin
(JDK 17 and 21, linux), and the engine and Flutter jobs that read `schema/`. These are the runners PR #24's
CI failed on; the U2 guards and fixture 38 now run every row there. The body is in the session scratchpad
(`s17/pr-s17.md`).

### What reviewers will find in the body
- Why: PR #24's CI; Linux ICU (Unicode 13 / 15), JDK 17 (13) and JDK 21 (15) miss 67 / 27 case pairs
  Dart has; JDK 17's case-insensitive backreference never repeats a capture above U+FFFF and throws.
- How: lagging classes learned once from the SDK's own engine (none on Apple's ICU and JDK 24+, asserted;
  a test seam); letters and classes written as Dart's set; S16's masked run also masks lagging letters,
  two-unit stand-ins above U+FFFF; Kotlin on JDK 17 masks every fold-class letter and writes backreferences
  exact; escaped pairs read as their letter with `u`.
- What changes: T1-T6 by commit; fixture 38, 30 rows (29 fail on JDK 17 and 21 on Linux 5.10 before S17).
- Tests: the local suites and the probe table (before → after per runner).
- Known differences (row 23b.40): properties over letters the platform lacks; on JDK 17 over an input with
  a character above U+FFFF, a part read without `i` can't tell apart letters of one class.
- Left for later: Dart's `(?i:(.)\1|x)` quirk; the two older escape corners (Swift); row 23b.39.

### Gate 08's limit, seen at group 3 (written into row 23b.40 at close)
JDK 17 only, outside the probe: "#" where Dart leaves the input in `a(?i:(.)\1)` gu on "A😀😀",
`(?-i:a)(.)\1` giu on "A😀😀", `(?-i:\w)(.)\1` giu on "ſ😀😀", `(?-i:A)(.)\1` giu on "a😀😀"; "#😀" in
`(?i:(.)\1)a` gu on "bBA😀" and `(?i:(.)\1)|a` gu on "A😀". None pinned.

### Not run locally
- Android's ICU path (full folding, like Swift): no test runs it anywhere.

### Next
- On your merge and `A`: 11 skipped by default (config.json), 12 reads PR #25's checks once, then S17
  closes: row 23b.40 reads ✅ Done in the epic plan, its known differences gain the six JDK 17 limit rows,
  and the follow-ups (Dart's quirk, the two older escape corners) are listed.
- Row 23b.39 (Unicode 17) waits for your word.
