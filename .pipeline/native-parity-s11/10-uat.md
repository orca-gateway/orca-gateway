# 10 · UAT · native-parity-s11

## Front page

### In one breath
Deep links work on both native SDKs: a link opens the closed app on its route, or navigates
the running app, and `onDeeplink` reports it once. Rows B11.1 to B11.4 pass on both, by
fixtures, tests and a hand-check on an iOS simulator and an Android emulator.
The tabs and drawer hand-check was repeated on merged main: still right on both.
The PR is open against main. The merge is yours; nothing is published.

### New for you
nothing new

### Trade-offs
1 auto-decided: the iOS example logs with NSLog, since a link-started app has no console.

### Questions for you
1. Merge the step 11 PR once its checks are green: yours. (default: ok; step 12 stacks on it)
2. After A: 11 skipped by default, 12 reads the PR's checks, 13 to 16 skipped. (default: yes)

## Appendix

### Hand-check, both devices (demo apps `navigation`, `tabs`, `tabs-server`, server on :8099)

| Check | iOS simulator | Android emulator |
|---|---|---|
| Closed app, `orcacounter:///home/product/42?ref=mail` | Product 42 in the Home tab, back to Home, `isColdStart=true` | same; one page request until back shows Home |
| Running app, `/settings/about`, `/home/product/7?x=1` | navigates, `isColdStart=false` | navigates, `isColdStart=false` |
| `/account?from=push`, logged out, cold and warm | Log in page, `resolvedLocation=/login wasRedirected=true`, one request | same |
| `/nope/1` | Page not found, Go to home page, no request; the button goes to `/` | same |
| Tabs app: cold `/search`, tab switch, drawer, drawer item | right tab selected, drawer opens, Settings pushed | right tab selected, drawer opens |
| Server tab bar app: cold `/profile` | Profile selected in the server-drawn bar, `_tabIndex: 2` | Search selected |

### Not covered by hand
A real https link (associated domains, app links): needs the deployer's domain; walkthrough in
docs/User_Actions.md. On iOS, `OrcaApp(client:path:)` and `OrcaApp(router:)` may report a launch
URL as a running-app link; documented, not hand-checked (the example boots from the config).
