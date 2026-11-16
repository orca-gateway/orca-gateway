# 10 · UAT · native-parity-s18

## Front page

### In one breath
PR #38 is open: step 18, the app shell, theming and error screens on both native SDKs.
On main 3cdeef7 (PR #36); every suite green locally except PR #33's four iOS 26.5 tests.
C18.1-C18.5 ticked on Swift and Kotlin; hand-checked on the iOS simulator and the Android emulator.
The merge is yours; nothing is published (the SDKs ship with their next release tags).

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #38 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT: seen by hand after group 7 (error screens, dark, splash with locale, cards). (default: done)
3. After A: 11 skipped by default; 12 reads PR #38's checks and your merge. (default: yes)
4. Meanwhile step 19 (DevTools and debug parity) starts on origin/main. (default: go)

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
