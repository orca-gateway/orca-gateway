# 10 · UAT · native-sdk-s3

## Front page

### In one breath
PR #7 is open: feat/native-sdk-s3 → main, 5 code commits plus pipeline ones. CI is running.
basic-actions is on the iPhone 16 Pro simulator now, against the example server on :8097.
UAT is yours: both apps, and DevTools showing the iOS app. Steps are in the appendix.

### New for you
Nothing new.

### Trade-offs
1 done: your gate 09 defaults are kept: one warning per type, fixture later, empty traces, Debug.
2 done: epic row 23b.20 now says 15 kinds.
3 noted: like Flutter, the app stops trying DevTools after 10 tries (about 3 min).
  So start DevTools first, then relaunch the app.

### Questions for you
1. UAT: do both apps and DevTools work for you? (default: none; the gate waits for your word)
2. Turn on Auto-fix for PR #7, so CI failures and review comments wake me? (default: off)
3. After A: 11 skipped by default, 12 records PR #7's CI, 13-16 skipped; nothing deploys.
   (default: yes; the sdk patch for the Dart DevTools builders waits for your release.sh run)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### UAT steps
The simulator panel shows an iPhone 16 Pro on iOS 18.5 with app-ios installed (Debug, DevTools on).
The server is `PORT=8097 bun run index.ts` in `examples/server`. I run it and stop it at the next
gate. Ports 8080 (Docker) and 8091 (another bun) are left alone.

1. basic-actions, on screen now. Work through it top to bottom:
   - +, - and Reset change the count.
   - Go to About pushes a page; its Go Back button and the bar's Back both pop.
   - Product, E-commerce and Checkout each push their own page.
   - Show Snackbar and Show Toast.
   - Copy Message, then paste anywhere.
   - Open Flutter Docs opens Safari. Use the "◀ Orca Counter" corner to come back.
   - Share Count shows "My counter is at N!".
2. server-actions:
   ```
   SIMCTL_CHILD_ORCA_SERVER_URL=http://localhost:8097 SIMCTL_CHILD_ORCA_APP_ID=server-actions \
     SIMCTL_CHILD_ORCA_PATH=shop xcrun simctl launch --terminate-running-process booted \
     com.orcagateway.examples.counter
   ```
   - Add to Cart shows "Adding...", then after 3 s a new row, the count, the stock and a snackbar.
   - Add 3 to Cart does the same without the loading state.
   - Clear Cart empties the list and shows the toast "Cart cleared!".
   - The cart lives on the server, so earlier runs' items count until you clear it.
3. DevTools:
   - Start the app with `task devtools:dev` in `open-source/`.
   - Relaunch either app with the command above (basic-actions: `ORCA_APP_ID=basic-actions`,
     `ORCA_PATH=home`).
   - "Orca Counter" (iOS, iPhone17,1) should appear.
   - Tap around. Network, Timing, State and Actions fill in; Errors stays empty unless
     something fails.
   - Network shows Authorization as `<redacted>`.
   - Timing has client marks only: the example server sends no `x-orca-timing`.

### PR #7
https://github.com/orca-gateway/orca-gateway/pull/7, opened at this stage. Its commits:
- 4c39f13 executor (23b.20)
- 44c4fcd adapters (23b.21)
- 59f0970 app-ios (23b.22)
- fb0cb4d DevTools contract (23b.28)
- 1ca967d Swift DevTools client (23b.29)
- pipeline commits

When it opened, 1 check had passed and 4 were pending. The branch starts at 5a2dbf9. Main has
since merged #6, which only touches `scripts/release.sh`, so there is no conflict. Before
pushing, `flutter analyze` on the SDK reported no issues.

### Release (question 3)
S3 changes `sdk/lib` in 4 files since sdk-v0.3.2:
- the DevTools envelope, handshake and FallbackPrompt builders;
- the renderer's once-per-type warning.
The engine is unchanged. That is a patch for `orca_gateway` whenever you run `release.sh`; nothing
breaks while it waits. The Swift SDK is not releasable until S5's mirror exists.

### Next
- 11 Release: skipped by default (config.json); question 3.
- 12 Deploy watch: PR #7's CI.
- 13-16: nothing is deployed, only a simulator; skipped at gate 12 as for S2.
- S4 (23b.23-24): the three policies, 426, and six more widgets. At S4's stage 08 you choose
  whether to add Stack, Positioned, ClipRRect and GestureDetector (the food-app screen) and a host
  button-style hook (your two questions at this gate).
