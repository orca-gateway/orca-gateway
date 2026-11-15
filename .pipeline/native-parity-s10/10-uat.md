# 10 · UAT · native-parity-s10

## Front page

### In one breath
PR #32 is open against main: tabs, the server tab bar and the drawer on both native SDKs.
Rows B10.1 to B10.8 pass on both, with tests and a hand-check on a simulator and an emulator.
One defect found by hand on iOS (page showing under the server tab bar) is fixed in the PR.
The merge is yours; nothing is published.

### New for you
nothing new

### Trade-offs
1 auto-decided: on iOS the strip under a bottom bar takes the Scaffold's colour, else the
system background, and the footer-button row is opaque too.

### Questions for you
1. Merge PR #32 once its checks are green: yours. (default: ok; step 11 starts from main)
2. Flip `OrcaApp(client)` to boot from the config, as Flutter? Still open. (default: keep opt-in)
3. After A: 11 skipped by default, 12 reads the PR's checks, 13 to 16 skipped. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #32
https://github.com/orca-gateway/orca-gateway/pull/32, base `main`, head `feat/native-parity-s10`. Bound to this
session, Auto-fix off, auto-merge off. `origin/main` (81b4bc1, with PR #30 and PR #31) is merged into the branch.

### Runs on the pushed tree
engine 743 pass · Flutter +321, analyze clean · Swift core 302, UI 126, 0 failures, 0 warnings · Kotlin build with
lint, core 307, sdk 200, 0 failed · both example apps build · generators leave no diff.

### Hand-check
iPhone 16 Pro simulator (iOS 18.5) and Pixel 3a emulator (API 34), example server on :8099, `ORCA_BOOT=config`.
- `tabs`: boots into Feed under three tabs; count, scroll and typed text survive switches, drawer cycles and a
  pushed Settings; each page requested once (server log); Open post 7 pushes inside the tab; iOS back swipe and
  Android system back pop it; menu button and swipe open the drawer, scrim closes (iOS scrim close: test only),
  an item pushes Settings over the tabs; `_tabIndex = 2` switches to Profile.
- `tabs-server`: server bar and server drawer draw; `visits` repaints in the bar; SwitchTab from the drawer; the
  "Own drawers" page shows its own bottom bar (tap writes state, fires onChange) and both page drawers.
- Fixed from the hand-check: `b005c64`, iOS bottom bars cover the home-indicator strip.
- Seen once, not reproduced: a first launch after a fresh install requested `/page/feed` twice within 14 ms.
- Android gesture navigation takes a swipe from the very screen edge as back (the app then leaves at a tab root).

### Known differences
Listed in the PR body ("Known differences and limits").
