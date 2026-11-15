# 10 · UAT · native-parity-s9

## Front page

### In one breath
PR #30 is open: both native SDKs boot from the server config, match routes, apply the redirect
rule, share app state and title the routes outside the tabs. Rows B9.1 to B9.10 pass on both.
Hand-checked on an iPhone simulator and an Android emulator against the `navigation` demo.
The merge is yours; nothing is published.

### New for you
nothing new

### Trade-offs
1 needs you: `OrcaApp(client)` keeps opening `home`; booting from the config is opt-in.
Flutter boots from the config by default. Flip the native default, or keep the opt-in.

### Questions for you
1. Merge PR #30 once its checks are green: yours. (default: ok; step 10 stacks on the branch)
2. Flip the default so `OrcaApp(client)` boots from the config, as Flutter? (default: keep opt-in)
3. `5c6b57e` from your local main is in this diff, with one regenerated Dart line. (default: ok)
4. After A: 11 skipped by default, 12 reads the PR's checks, 13 to 16 skipped. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #30
https://github.com/orca-gateway/orca-gateway/pull/30, base `main`, head `feat/native-parity-s9`. Bound to this
session, Auto-fix off, auto-merge off. `origin/main` was 9706551 at the push and already in the branch, so no rebase.
Over it: `5c6b57e` (the user's unpushed local-main commit), the step 9 commits one per task, the pipeline notes, and
28ac5b1, which regenerates `sdk/lib/src/capabilities/generated.dart` (`'Video'`): `5c6b57e` added Video to the
widget registry without rerunning `gen-sdk-capabilities.ts`, and the "Codegen drift detection" check failed on the
first push for that reason. All four generators of that job were rerun locally; nothing else drifts.

### Suites at the head (local)
engine 738 pass · Flutter 303, analyze clean · Swift core 248, UI 74 · Kotlin core 243, sdk 152, build
successful · Android `assembleDebug` and the iOS simulator build succeed.

### Hand-checks (demo app `navigation`, example server on :8099, `ORCA_BOOT=config`)
| Row | iPhone 16 Pro simulator, iOS 18.5 | Pixel 3a emulator, API 34 |
|---|---|---|
| B9.1 | boots at Welcome, the config's initial route | the same |
| B9.4 | Account opens Log in while logged out; opens after "Log in as Ada" | the same; loggedIn true, Ada |
| B9.8 | Settings pushed with title bar "Settings"; back button pops | top bar "Settings" with a Back arrow; it pops to Account |

On Android the Login route showed the fallback title "Login" and then the page title "Log in" (the live title).

### Known differences (in the PR body)
Swift compares path text by canonical equivalence; one bar on iOS against two on Android and Flutter when a page
has its own AppBar on a titled route; boot error wording; the Kotlin config-failure message says "Failed to fetch
page"; a push of a nested location adds only the top page; a host write of null during a fetch is refilled by the
page seed; no JSON-schema validator in the repo; the iOS back button is checked by hand only.

### Next
Step 10 (tabs and drawer, B10.1 to B10.8) starts on a branch stacked on this one.
