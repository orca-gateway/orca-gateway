# 10 · UAT · native-parity-s18

## Front page

### In one breath
PR #38 rebased on main 6a7f0e0 (PRs #37, #40): no conflicts; generated files regenerated (45).
CI's iOS check: Xcode 16.4 could not type-check one test expression (T17 fixed it); on the iOS 18.5
simulator CI uses, the dark-scheme bar stayed dark before iOS 26 (T19 fixed it). T18 and T20 moved
two pins main's tests had to step 18's truth. iOS 18.5: 737 tests, 0 failures. The merge is yours.

### New for you
nothing new

### Trade-offs
1 auto-decided: a UIKit pin keeps the bar light before iOS 26 (`.visible` breaks three goldens)

### Questions for you
1. Merge PR #38 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT: seen by hand after group 7; the iOS 18 bar fix is tested, not re-seen. (default: done)
3. After A: 11 skipped by default; 12 reads PR #38's checks and your merge. (default: yes)
4. Meanwhile step 19 (DevTools and debug parity) starts here on main 6a7f0e0. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #38
https://github.com/orca-gateway/orca-gateway/pull/38, opened after gate 09 was approved under your standing rule
(its one question, "A approves the stage; stage 10 ticks C18.1-C18.5 and opens the step 18 PR", was minor). Bound to
this session; Auto-fix off, auto-merge off. Branch feat/native-parity-s18 on origin/main 3cdeef7 (PR #36): the task
commits T1-T16 with their reworks (R3, R3b), the step 16 close note (020c7cb) and the pipeline notes. At open
(`get_status`): mergeable, 0 passing, 6 pending, 0 failing. The body is in the session scratchpad (`s18/pr-s18.md`).

### What reviewers will find in the body
- Why: the natives showed raw error text, had no host views, no scheme or locale option, degraded the placeholder,
  and had no timeout.
- What changes: OrcaErrorInfo in the cores, OrcaErrorView, the host views, colorScheme and locale (Scaffold pages
  stay light), the placeholder drawn and advertised (31 to 32), the timeout, the demos and READMEs.
- Where the natives differ on purpose: Flutter's declared-but-unapplied timeout; the natives' "Try again"; a timeout
  reads Connection Failed.
- Tests: every suite's line, the four PR #33 iOS 26.5 failures by name; the hand checks; left for later.

### Test file
`/Users/amrebada/.claude/plans/native-parity/phase-c-tests.md`: C18.1-C18.5 ticked on Swift and Kotlin with the test
names, fixture 17 and "PR #38", each row corrected to Flutter's behaviour (said in its evidence). Rows ticked: Swift
17 of 35, Kotlin 17 of 35.

### Not run locally
- The Linux Swift jobs (CI runs them). The new core files (OrcaErrorInfo, the timeout) are Foundation-only; the core
  tests have no synchronous `@MainActor` methods.
- The iOS 18.5 simulator CI uses (the four PR #33 tests fail only on the local iOS 26.5 runtime).

### Round 2 (2026-11-16): rebase and CI
PR #38 conflicted after PRs #37 and #40 merged, and "UI tests and example (iOS simulator)" failed to build the test
target (run 43784457921: "the compiler is unable to type-check this expression in reasonable time",
UnsupportedWidgetPlaceholderTests.swift:211). Rebased on 6a7f0e0, conflicts resolved by hand, Generated.swift/.kt
regenerated. Fixes T17-T20, two reviews each (09 "Stage 10 rework"). Local iOS 18.5 run of the whole package
(CI's runtime and the goldens CI's Xcode skips): 737 tests, 0 failures; it found the dark bar before iOS 26 and the
warn golden's one-row seam that the iOS 26.5 runs had not. iOS 26.5 alone: 5 AppBarCardTests/ButtonTests failures, all
failing on origin/main alone (PR #33's four plus A1_9ScaffoldLeadingWidthSizesTheLeadingSlot since PR #40).
Not run locally: CI's Xcode 16.4 itself (only 27.2 is installed); the slow-check flags stand in for it.

