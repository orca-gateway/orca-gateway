# 10 · UAT · native-parity-s1

## Front page

### In one breath
PR #33 is open: the widgets both native SDKs already draw now honour Flutter's props, and Android
keeps its page stack through a rotation. Rows A1.1 to A1.13 pass on both SDKs (26 of 26 cells).
Hand-checked on an iPhone simulator and an Android emulator with the `parity-a` demo.
The merge is yours; nothing is published.

### New for you
nothing new

### Trade-offs
none needs you: 3 auto-decided at gate 09 (the /config boot kept through a rotation, a kept router
takes the shown activity's hooks, OrcaAppBoot hooks internal); known differences are in the PR body.

### Questions for you
1. Merge PR #33 once its checks are green: yours. (default: ok; step 2 stacks on the branch)
2. After A: 11 skipped by default, 12 reads the PR's checks, 13 to 16 skipped. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #33
https://github.com/orca-gateway/orca-gateway/pull/33, base `main`, head `feat/native-parity-s1`. Bound to this
session, Auto-fix off, auto-merge off. The branch was rebased on `origin/main` 81b4bc1 (PR #30 and #31 merged) before
the push; the conflict in `sdk-kotlin/.../OrcaApp.kt` was merged so both sides hold (fit and quality reviews pass).
CI's three codegen generators were rerun on the head: no drift. 5c6b57e is already on main.

### Suites at the head (local)
engine 740 pass · Flutter 305, analyze clean · Kotlin `./gradlew build` sdk 219 + core 301, lint clean · Swift
macOS 120 UI + 298 core · iOS scheme (iPhone 16 Pro simulator, iOS 18.5) 140 UI + 298 core, goldens unchanged.
Not run locally: CI's Xcode 16.4 (only Xcode 27.2 here); no golden moved.

### Hand-checks (demo app `parity-a`, page `polish`, example server on :8131)
| Row | iPhone 16 Pro simulator, iOS 18.5 | Android emulator, API 34 |
|---|---|---|
| A1.9 | pushed page shows "< Polish (step 1)"; the no-back page shows none | back arrow on the pushed page; none on the no-back page |
| A1.13 | Count 2, push, rotate: the pushed page stays; back shows Count 2 | the same; the activity is relaunched (logcat) and the stack survives |
| A1.9 (bar) | found the title drawn twice with centerTitle false; fixed (0f56d7f), re-checked once | 72-wide leading, title after it, shadow with shadowColor |

### Rows
phase-a-tests.md rows A1.1 to A1.13 are ticked in both columns, each with its tests and PR #33.

### Next
Step 2 (lifecycle and triggers, A2.1 to A2.6) starts on a branch stacked on this one.
