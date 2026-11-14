# 10 · UAT · native-sdk-s18

## Front page

### In one breath
PR #26 is open: with `u`, Swift reads escaped pairs in a class and lone halves as Dart does.
Dart's modifier-group bug stays a known difference of the Flutter SDK; both SDKs follow the spec.
3 tasks, 3 code commits, fixture 39; every suite green locally; its checks had not started yet.
The merge is yours; nothing is published (Swift ships with its next release tag).

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #26 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT, optional: nothing to see; no example page uses these regex corners. (default: skip)
3. After A: 11 skipped by default; 12 reads PR #26's checks and your merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #26
https://github.com/orca-gateway/orca-gateway/pull/26, opened at this stage after gate 09 was approved under your
standing rule (its last question, "approve the stage; ship pushes the branch and opens the PR", was minor, as at
S15's, S16's and S17's gate 09). Bound to this session, Auto-fix off, auto-merge off. Title "fix(sdk-swift): with u,
escaped pairs in classes and lone halves read as in Dart; Dart's modifier-group bug noted (S18)". Before the push
`origin/main` was cbc4b0f (PR #25's merge), already in the branch. Over main: the S17 close note (e8d5fa8), the S18
pipeline notes (5816c6a, d85fcdc, 73ca7ca, e2eb746), and the code, one commit per task: T1 5e729f8, T2 032955d,
T3 47b4914.
Read once at this card (`get_status`): open; 0 passing, 0 pending, 0 failing (the checks had not registered yet).
Expected checks, by path filters (`sdk-swift/`, `sdk-kotlin/`, `schema/` and `.pipeline/` change): SDK Swift (core
tests, swift 5.10-jammy and 6.2-noble, linux), SDK Swift UI (iOS simulator), SDK Kotlin (JDK 17 and 21, linux),
codegen drift, and the engine and Flutter jobs that read `schema/`. The body is in the session scratchpad
(`s18/pr-s18.md`).

### What reviewers will find in the body
- Why: the probe of 3 108 rows; Swift refused class ranges with an escaped-pair end and let ICU join lone halves;
  Dart's quirk is a broad Dart bug in modifier groups with `|`, which the SDKs and the engine do not follow.
- How: an escaped pair is one class member with `u`; a lone half is `(?:(?!))` outside a class and nothing in one.
- What changes: T1-T3 by commit; two S17 written-text pins updated; fixture 39, 28 rows.
- Tests: the local suites and the probe table (Swift 262 / 262 / 251 → 0; Kotlin 0 → 0).
- Known differences (row 23b.41): Dart's modifier-group bug, Flutter-only.
- Left for later: a Flutter-side fix or a Dart bug report; the run-time unset backreference.

### Not run locally
- Android's ICU path: no test runs it anywhere (as at S16, S17).

### Next
- On your merge and `A`: 11 skipped by default (config.json), 12 reads PR #26's checks once, then S18 closes:
  row 23b.41 reads ✅ Done in the epic plan with Dart's bug as its known difference, and the two follow-ups are
  proposed (question 6 of gate 08).
- Row 23b.39 (Unicode 17) waits for your word.
