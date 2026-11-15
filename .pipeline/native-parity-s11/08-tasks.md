# 08 · Tasks · native-parity-s11

## Front page

### In one breath
tasks: 6 in 4 groups · widest group: 2 · cases: 8 of 8 placed
Group 1 records Flutter's link behaviour as shared fixtures. Group 2 puts the link logic in the
two pure cores (parallel). Group 3 wires `OrcaApp` on both SDKs (parallel). Group 4 makes the two
example apps open `orcacounter://` links. Then the hand-check and the User_Actions walkthrough.

### New for you
nothing new

### Trade-offs
4 auto-decided, all where Flutter has an untested quirk (brief section 1, q1 to q5): real path
parameters in the event; `isColdStart` true on iOS too; a link during boot is held and applied;
a link to the page already shown still calls back. The location of a link is path plus query.

### Questions for you
1. Commands as found (bun test, flutter test, swift test, gradlew build, xcodebuild test)? (default: yes)
2. Commits by the plugin: per task. (default: per task)
3. One gate per group, minor ones self-approved under the standing rule. (default: yes)

## Appendix

Design: `.pipeline/native-parity-s11/design-brief.md` (oracle, decisions D1 to D8, cases L-F, L1 to L7).

### Groups

| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Link fixtures, Flutter as oracle | schema/navigation-fixture.schema.json · schema/fixtures/navigation/15_deep_links.json · schema/fixtures/navigation/README.md · sdk/test/conformance/navigation_fixtures_test.dart | L-F | M | - |
| 2 | T2 | Swift core: link to location, link resolution, fixtures | sdk-swift/Sources/OrcaGatewayCore/Navigation/DeepLink.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/NavigationFixtureTests.swift · DeepLinkTests.swift (new) | L1, L3, L4 (core) | S | 1 |
| 2 | T3 | Kotlin core: link to location, link resolution, fixtures | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/navigation/DeepLink.kt (new) · core/src/test/.../navigation/NavigationFixtureTest.kt · DeepLinkTest.kt (new) · FixturePathsTest.kt | L1, L3, L4 (core) | S | 1 |
| 3 | T4 | Swift OrcaApp: onDeeplink, onOpenURL, cold boot, not-found button | sdk-swift/Sources/OrcaGateway/OrcaApp.swift · Navigation/OrcaRouter.swift · Tests/OrcaGatewayTests/DeeplinkTests.swift (new) · sdk-swift/README.md | L2, L3, L4, L5, L6 (Swift) | M | 2 |
| 3 | T5 | Kotlin OrcaApp: onDeeplink, launch Intent, new intents, cold boot, not-found button | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt · navigation/OrcaRouter.kt · sdk/src/test/.../DeeplinkTest.kt (new) · sdk-kotlin/README.md | L2, L3, L4, L5, L6 (Kotlin) | M | 2 |
| 4 | T6 | Example apps open orcacounter:// links | examples/app-ios (URL type, OrcaCounterApp.swift, README) · examples/app-android (AndroidManifest.xml, MainActivity.kt, README) | L7 | S | 3 |

### Order, and why each boundary
1 before 2: the cores are written against the recorded fixtures. 2 before 3: the UI layers call the core's link
resolution. 3 before 4: the examples use the new `onDeeplink` parameter. Within 2 and 3 the two SDKs share no file.

### Seams
The fixture count pins (navigation 14 to 15) sit in each SDK's own test files, inside T2 and T3.

### Not planned
`docs/User_Actions.md` (workspace level, outside the repo) and the device hand-check are done after group 4.

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` and
`xcodebuild test -scheme OrcaGateway-Package -destination "id=<simulator>"` · `cd sdk-kotlin && ./gradlew build`
lint: inside `./gradlew build`; `flutter analyze` · typecheck: none
baseline: engine 745 · Flutter +326 · Swift core 329, UI 183 · Kotlin core 333, sdk 275, 2026-11-16
commits: per task · gate: per group (answered under the standing rule, 2026-11-16)
