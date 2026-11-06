# 10 · UAT · native-sdk-s4

## Front page

### In one breath
PR #8 is open: feat/native-sdk-s4 → main, 9 code commits plus pipeline ones. CI is running.
native-widgets is on the iPhone 16 Pro simulator now, against the example server on :8097.
Servers with the warn (:8095) and require (:8096) policies run too. UAT is yours; steps below.

### New for you
Nothing new.

### Trade-offs
1 done: gate 09 defaults kept: the 426 page from fetchPage, host style only on plain buttons.
2 done: the Flutter warn-wrapper crash runs in its own session, which you started.
3 noted: iOS cannot show the 426 page live yet: its alpha version skips the gate (S5 fixes it).

### Questions for you
1. UAT: do native-widgets and capability-demo work for you? (default: none; the gate waits)
2. Turn on Auto-fix for PR #8, so CI failures and review comments wake me? (default: off)
3. Epic row 23b.23 still says "debug placeholder"; gate 08 kept S2's prompt. Fix it? (default: yes)
4. After A: 11 skipped by default, 12 records PR #8's CI, 13-16 skipped; nothing deploys.
   (default: yes; the sdk 426 patch waits for your release.sh run)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### UAT steps
The simulator panel shows an iPhone 16 Pro on iOS 18.5 with app-ios installed (Debug, DevTools
off). Three example servers run from `examples/server`, all mine, stopped at the next gate:
:8097 (the default, graceful), :8095 (`ORCA_FALLBACK_POLICY=warn`) and :8096 (`require`). Ports
8080 (Docker), 8091 (another bun) and 6363 (DevTools) are left alone.

To open any page, change the three values in:
```
SIMCTL_CHILD_ORCA_SERVER_URL=http://localhost:8097 SIMCTL_CHILD_ORCA_APP_ID=native-widgets \
  SIMCTL_CHILD_ORCA_PATH=home SIMCTL_CHILD_ORCA_DEVTOOLS=0 xcrun simctl launch \
  --terminate-running-process booted com.orcagateway.examples.counter
```

1. native-widgets (on screen now):
   - Type in "Search dishes", fast or slow, then delete. "You typed:" follows every key.
   - Tap a heart: it fills or empties at once. Hold it: the toast "<dish>: long press".
   - Look at the cards: photos cover their box (from picsum.photos, so they need the network; offline
     the box shows "!"), top corners rounded, badge top right, a soft shadow.
   - Scroll down: flex 1 is half as wide as flex 2; the Spacer pushes its label to the right edge.
   - The bordered box: one tap shows "Tapped" after about 0.3 s (the double-tap wait), two quick
     taps show "Double tapped". Toasts stay 2 s.
2. capability-demo on :8097, paths `home`, `upgrade`, `blocked`, `negotiation`, `degrade`:
   - home: a blue info prompt; "Learn more" opens example.com in Safari ("◀ Orca Counter" comes back).
   - upgrade: an orange warn prompt. blocked: a red blocking prompt, centred.
   - negotiation: a Divider between two texts. degrade under graceful: the Checkbox is simply gone.
3. The policies, path `degrade`:
   - :8095 (warn): the orange banner "Some content needs an update" on top, then "Unsupported content"
     where the Checkbox was.
   - :8096 (require): one blocking prompt instead of the page.
4. counter, basic-actions and server-actions on :8097: they should look as they did in S3.

### PR #8
https://github.com/orca-gateway/orca-gateway/pull/8, opened at this stage. Its commits:
- 31be328 Flutter 426 page
- 4f392e4 degrade on iOS (23b.23)
- 4c5dbdf six widgets (23b.24)
- 79f6d0f Stack, Positioned, ClipRRect, GestureDetector (23b.30)
- f2bd8d6 OrcaTheme (23b.31)
- 3a035ef, 1c09298 layout fixes; f07c8cf TextField and gestures
- 9ece76f native-widgets demo and goldens
- pipeline commits

When it opened, 1 check had passed and 3 were pending; GitHub reports it mergeable. The branch
contains main, so nothing needed merging. `flutter analyze` on the SDK reported no issues.

### The 426 page, live (trade-off 3)
The engine's `parseSemver` (`engine/src/core/min-sdk-version.ts:41`) takes only X.Y.Z. The Swift SDK
sends `0.1.0-alpha.1`, so a high `ORCA_MIN_SDK_VERSION` never blocks it; the iOS 426 page is
covered by `DegradeTests` and the recorded `degrade-426.json` (made with `--sdk-version 0.1.0`).
Flutter's sdk sends a plain version, so the Flutter example would show the page live; S4 does not
run the Flutter app.

### Release (question 4)
Since sdk-v0.3.2, `sdk/lib` has 5 changed files: S3's 4 (the DevTools builders, the once-per-type
warning) and S4's `orca_client.dart`, which returns the 426 page. Together they are a patch for
`orca_gateway` whenever you run `release.sh`. The engine is unchanged.
The Swift SDK is not releasable until S5's mirror exists.

### Next
- 11 Release: skipped by default (config.json); question 4.
- 12 Deploy watch: PR #8's CI.
- 13-16: nothing is deployed, only a simulator; skipped at gate 12 as for S2 and S3.
- S5 (23b.25-26): the release.sh mirror and the docs, plus the min-SDK pre-release fix.
- The Flutter warn-wrapper fix lands in its own PR from its own session.
