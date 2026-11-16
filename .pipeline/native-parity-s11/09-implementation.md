# 09 · Implementation · native-parity-s11

## Front page

### In one breath
group 4 of 4 · tasks: 6 green, 0 blocked · cases: 7 of 7 green · all suites green (see Test run)
T1 fixtures: 18 deep links pinned on Flutter. T2, T3 cores: link to location, event, open.
T4, T5 OrcaApp: links open the app or navigate it, onDeeplink fires once, home button on not-found.
T6 examples: both counter apps register `orcacounter://` and log each event.

### New for you
nothing new

### Trade-offs
4 auto-decided: a link whose final location is on screen navigates nothing (D5, location only) ·
Kotlin draws one empty frame on a cold link under OrcaApp(router) ·
Swift path mode and OrcaApp(router:) may see a launch URL as a running-app link (documented) ·
a Swift router made with `link:` drops one repeat of that URL while on the boot location.

### Questions for you
1. Approve the stage? Device hand-checks are recorded in stage 10. (default: go)

## Appendix

### Group 1

#### T1 · Deep link fixtures, Flutter as the oracle
Files: schema/navigation-fixture.schema.json · schema/fixtures/navigation/15_deep_links.json · README ·
sdk/test/conformance/navigation_fixtures_test.dart
Cases: L1, L3, L4 on Flutter → green. 18 links, 4 cold. Flutter quirks q1 to q6 carried as per-case
`flutter` overrides, not copied by the native SDKs.
Review fit: pass · Review quality: wasRedirected description, fixed

### Group 2

#### T2 · Swift core: DeepLink.location, DeeplinkEvent, TabShell.open(link:)
Files: Sources/OrcaGatewayCore/Navigation/DeepLink.swift · DeepLinkTests.swift · NavigationFixtureTests.swift
Cases: L1, L3, L4 → green. Review fit: grapheme split disagreed with Kotlin on a delimiter before a
combining scalar, fixed (split by scalar, three pairs on both twins) · Review quality: pass

#### T3 · Kotlin core: DeepLink.location, DeeplinkEvent, TabShell.open(link)
Files: core/.../navigation/DeepLink.kt · DeepLinkTest.kt · NavigationFixtureTest.kt · FixturePathsTest.kt
Cases: L1, L3, L4 → green. Aligned to Swift on the D5 rule and the API shape.
Review fit: pass · Review quality: pass

### Group 3

#### T4 · Swift OrcaApp: onDeeplink, onOpenURL, cold boot, not-found button
Files: OrcaApp.swift · Navigation/OrcaRouter.swift · Tests/OrcaGatewayTests/DeeplinkTests.swift · README.md
Cases: L2 to L6 → green. `router.handleDeeplink(_:isColdStart:)`, `router.onDeeplink`,
`OrcaApp(onDeeplink:)`, `OrcaAppBoot.handleDeeplink`, `.onOpenURL` and `.onContinueUserActivity`.
Review fit: path-mode cold link was a replace with a route event; host-driven boot got a late first
link as cold; docs promised too much for path mode; all fixed. Second pass: path-mode query cut by
scalar, fixed (the input cannot reach it through a URL; kept as a parity pin).
Review quality: pass

#### T5 · Kotlin OrcaApp: onDeeplink, launch Intent, new intents, cold boot, not-found button
Files: OrcaApp.kt · navigation/OrcaRouter.kt · sdk/src/test/.../DeeplinkTest.kt · README.md
Cases: L2 to L6 → green. `handleDeeplink`, `handleIntent`, `onDeeplink`, launch Intent read once,
`addOnNewIntentListener`.
Review fit: a loosened assertion made exact; launch link handled again after hide and show, fixed for
both overloads. Review quality: path mode decoded the query with URLDecoder, now core's RouteTable; fixed

### Group 4

#### T6 · Example apps open `orcacounter://` links
Files: examples/app-ios (Info.plist, project, OrcaCounterApp.swift, README) · examples/app-android
(manifest, MainActivity.kt, README)
Cases: L7 → green, by build and by device run. iOS log moved from print to NSLog after the device
run showed a link-started app has no console.
Review fit: pass · Review quality: pass

### Test run
After merging origin/main (PR #36): engine 748 · Flutter +348, analyze clean · Swift core 358, UI 237, 0 warnings;
simulator package tests TEST SUCCEEDED · Kotlin core 359, sdk 314, lint clean · both example builds succeed.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Follow-ups, not in this slice: Swift RouteTable.swift:271, TabShell.swift:213 and OrcaRouter.swift:401
still split by Character (Kotlin by code unit); Swift compares locations by canonical equivalence.
A real web link (https) needs the deployer's domain setup: docs/User_Actions.md, step 11 entry.
