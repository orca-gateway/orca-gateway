# 10 · UAT · native-sdk-s8

## Front page

### In one breath
PR #14 is open: feat/native-sdk-s8 → main. On the Pixel 3a emulator basic-actions and
server-actions work: pages push and pop (back too), URL, clipboard, share, server actions.
U1 found two bugs in the DevTools client, both fixed in 7878ecb and reviewed twice: it never
stayed in your DevTools, and its reconnect test failed on Linux CI. It now stays connected.

### New for you
nothing new

### Trade-offs
1 auto-decided: the client stops offering compression, rather than a DevTools server change.
1 noted: dart:io's DevTools reply breaks RFC 7692; a DevTools-side fix is a follow-up, not S8.

### Questions for you
1. UAT: the emulator and the server on :8097 are up; does it look right to you? (default: ok)
2. Your DevTools window should list "Orca Counter" on sdk_gphone64_arm64. (default: it does)
3. After A: 11 skipped by default, 12 records PR #14's CI and the merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #14
https://github.com/orca-gateway/orca-gateway/pull/14, opened at this stage, bound to this session,
Auto-fix off. Code commits: 0370b1d, dcc5762, b3830cc, 33bf323, 3fbd70a, c64b24a, 778c06a and the
UAT fix 7878ecb. Pipeline commits: 2def978, b9a0c0d, fee8e61 (S7 close), 0a7d2c1 (S8 stage 08),
d78a0a7 (stage 09). The first CI run (at d78a0a7) failed: SDK Kotlin on JDK 17 and 21, push and
PR, `DevToolsClientTest > c2_reconnectsAfterDevToolsRestarts` with `BindException: Address already
in use` (the test bound its stub's port twice; Linux refuses, macOS allows). CI at 7878ecb: below.

### U1 on the emulator (what I ran and saw)
Pixel 3a API 34 (`sdk_gphone64_arm64`), `examples/server` from this branch with `PORT=8097`, the
example installed with `task example:android:run URL=http://10.0.2.2:8097 APP=… PAGE=…`. Docker on
8080 and the bun on 8091 untouched. Your DevTools app was not running; I opened it (`open -a "Orca
Gateway DevTools"`), as gate 08 agreed the emulator joins it on :6363.
| Step | Result |
|---|---|
| basic-actions home | GET 412, POST 200 with the Kotlin vector, page drawn; later GETs 200 |
| Go to About Page, then Go Back | About pushed; Go Back pops to home |
| Product: + then system back | quantity 2, total $99.98; the back key pops to home |
| E-commerce: Sell 1, ← Back to Home | stock 10 → 9; back to home |
| Checkout: Place Order without, then with the terms box | "Payment failed — please agree to terms", then "Payment successful!"; Reset All clears it |
| Copy Message | Android's clipboard preview shows "Hello, Orca Gateway!"; the page's toast "Copied to clipboard!" |
| Open Flutter Docs | Chrome opens https://flutter.dev (Chrome's own screens left alone) |
| Share Count | the share sheet with "My counter is at 0!" (closed without sharing) |
| server-actions shop: Add to Cart, Add 3 | 1 item then 4, stock 99 then 96, snackbars "Added 1x/3x …" (each action ~3 s, the server's delay) |
| Refresh Cart, Clear Cart | 4 items, then 0; the server log has 5 action POSTs, all 200 |
| DevTools (before the fix) | the app connected to 10.0.2.2:6363 again and again and never stayed |
| DevTools (after 7878ecb) | one ESTABLISHED connection, still up 35 s later after taps and a push/pop |
Screenshots (sent to you): basic-actions home, product at quantity 2, the paid checkout, the
clipboard preview, the share sheet, the shop with 4 items, the cleared cart.

### The DevTools bug (found by U1)
dart:io's `WebSocketTransformer.upgrade` in `devtools/lib/server/ws_server.dart` answers OkHttp's
`Sec-WebSocket-Extensions: permessage-deflate` offer with `permessage-deflate;
client_max_window_bits=15` (curl showed it). OkHttp 4.12 fails any upgrade whose reply sets
`client_max_window_bits` (`RealWebSocket.isValid`, close code 1010 "unexpected Sec-WebSocket-
Extensions in response header"), so the Kotlin client looped through reconnects. Without the offer
DevTools replies with no extension. The fix (one S8.4a rework by a fresh implementer, fit and
quality both pass): the client's own OkHttpClient strips the offer with an application interceptor
(OkHttp skips network interceptors for WebSockets). New test `c1_aDartDevToolsServerKeepsTheClient`
(a stub answering like dart:io); C2 now plays the restart on one server, no second bind. core 106,
sdk 71, lint 0; the DevTools client tests passed 5 runs in a row. The MockWebServer stubs of 09
never negotiated compression, which is why the tests missed it.

### Findings
- F1 dart:io's reply breaks RFC 7692 §7.1.2.2 (no `client_max_window_bits` unless offered). Other
  OkHttp-based clients would hit it too; turning compression off in `ws_server.dart` is a small
  DevTools follow-up (a DevTools release), not part of S8.
- F2 A rotation still rebuilds the router at the root (S7 F1, 08 F4), noted, not built.
- F3 Server actions in the example take ~3 s each (the server's simulated delay), not the SDK.

### Next
- 11 Release: skipped by default; nothing is published before S10.
- 12 Deploy watch: PR #14's CI and the merge (you merge).
- After S8: S9 (23b.27d): FallbackPrompt looks, the three policies, the drawn 426 page, ten more
  widgets, Android theme hooks.
