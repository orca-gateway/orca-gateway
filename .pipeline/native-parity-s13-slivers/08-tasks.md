# 08 · Tasks · native-parity-s13-slivers

## Front page

### In one breath
tasks: 6 in 3 groups · widest group: 2 · cases: 13 of 13 placed
Group 1: the shared fixture with a Flutter test, and the `slivers` demo app with its engine tests.
Group 2: the two pure cores (the item list and the bar's maths), Swift and Kotlin side by side.
Group 3: the two UI layers, with capabilities, tests and READMEs.

### New for you
nothing new

### Trade-offs
2 auto-decided, yours to overturn: the SDK draws the collapsing bar itself, not the system
large-title bar, so expandedHeight, floating and flexibleSpace can be honoured · the bar
collapses only as the first sliver of a vertical view; elsewhere it scrolls as a plain box.

### Questions for you
1. Commands as found (bun test, flutter test, swift test + simulator, gradlew build)? (default: yes)
2. Commits by the plugin: per task? (default: per task)
3. One gate per group? (default: all groups under one card)

## Appendix

Design in force: `.pipeline/native-parity-s13-slivers/design-brief.md` (stages 05 to 07 skipped; its
"Cases" section stands in for 07).

### Groups
| G | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Render fixture 69 with a `resolved` block; Flutter count pin; Flutter widget test pinning the builders and the bar's extents | schema/fixtures/render/69_custom_scroll_view_slivers.json · sdk/test/sliver_widgets_test.dart · sdk/test/conformance/* (count pin only) | C-fix (Flutter), C-flutter | M | — |
| 1 | T2 | `slivers` demo app, registered and in the README; example test; native parity test (red for the natives until group 3) | examples/server/slivers.ts · examples/server/index.ts · examples/server/README.md · engine/test/slivers-example.test.ts · engine/test/parity-b-slivers.test.ts | C-demo, C-caps | M | — |
| 2 | T3 | Swift core: `SliverItems`, `SliverAppBarGeometry`, tests with the shared case tables | sdk-swift/Sources/OrcaGatewayCore/Render/SliverItems.swift · SliverAppBarGeometry.swift · sdk-swift/Tests/OrcaGatewayCoreTests/SliverCoreTests.swift | C-items-S, C-geo-S | M | T1 |
| 2 | T4 | Kotlin core: the same | sdk-kotlin/core/…/render/SliverItems.kt · SliverAppBarGeometry.kt · sdk-kotlin/core/src/test/…/render/SliverCoreTest.kt | C-items-K, C-geo-K | M | T1 |
| 3 | T5 | Swift UI: CustomScrollView and the four slivers, capabilities, generated files, fixture count pin, tests, README | sdk-swift/Sources/OrcaGateway/Widgets/Slivers.swift (+ Lists.swift helpers made internal, registry line) · sdk-swift/capabilities.json · Generated.swift · sdk-swift/Tests/OrcaGatewayTests/SliverTests.swift · count pins · sdk-swift/README.md | C-fix (Swift), B13.1-S, B13.2-S, C-fallback-S | M | T3 |
| 3 | T6 | Kotlin UI: the same | sdk-kotlin/sdk/…/widgets/Slivers.kt (+ registry line in standard()) · sdk-kotlin/capabilities.json · Generated.kt · sdk-kotlin/sdk/src/test/…/widgets/SliverTest.kt · count pins · sdk-kotlin/README.md | C-fix (Kotlin), B13.1-K, B13.2-K, C-fallback-K | M | T4 |

### Order, and why each boundary
1 → 2: the cores take their geometry numbers from T1's Flutter test. 2 → 3: the UI layers draw what the cores compute.

### Seams
`gen-native-capabilities.ts` writes both Generated.swift and Generated.kt in one run: T5 and T6 each change only
their own capabilities.json; the main session reruns the three generators once after group 3 and commits the result.
T2's parity test is red for the native vectors until group 3 adds the names.

### Not planned
none

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` and the package tests
on the iOS simulator (id 90215DCF-FB0F-4EBD-B08E-90AE7E3032E6) · `cd sdk-kotlin && ./gradlew build`
lint: inside gradlew build, `flutter analyze` · typecheck: none
baseline: see `### Baseline` (filled from the run on 20611b2 + 2 pipeline commits, 2026-11-16)
commits: per task · gate: all (standing rule, 2026-11-16)
