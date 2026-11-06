# 07 · Test cases · native-sdk

## Front page

### In one breath
Seven test groups mirror the seven slices: contract drift and action fixtures first, then decode
and resolve round trips, the 412 caps handshake, the counter page, degrade policies and the mirror
install. The pure-Swift core tests run on Linux per PR; only SwiftUI tests need a macOS runner.

### New for you
1. Property-based testing for round trips and arithmetic → learning/property-based-testing.md

### Trade-offs
1 needs you: iOS CI, core on Linux per PR, SwiftUI on macOS nightly vs all on macOS; default split.
2 needs you: look tests, structural plus one counter golden vs a golden per widget; default former.
3 needs you: resolution spec, resolved map in render fixtures vs a new resolve set; default the map.
4 needs you: action fixtures, 12 per kind plus 3 scenarios vs per kind only; default both.

### Questions for you
1. Done per slice? (default: its test group green in CI and its example pages run on a simulator)
2. Fixture source? (default: lifted from the Dart ActionExecutor tests; Flutter SDK passes first)
3. Server in client tests? (default: a fixture-backed stub; the Bun server only in integration)
4. 412 handshake in alpha? (default: yes; without it the server treats the client as unversioned)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-design module replaces it.

### Design addendum found while writing tests
engine/test/caps-412-protocol.test.ts defines the client handshake: send X-Orca-Caps-Hash; on 412
caps_vector_unknown retry once with _orcaCapsVector in the body; the server caches the hash. OrcaClient
(stage 05 adapter) must implement it; it was not named there. Render fixtures carry unresolved state
Values plus watches, so for a client they test decoding; resolution needs trade-off 3.

### T0 Contract (S0; bun + flutter test, ubuntu)
T0.1 every kind literal in engine/src/types/action.ts is in action.schema.json and vice versa (28).
T0.2 widget-registry.json has targets on all 92; the eight iOS orphans lack "ios"; schema.yml diffs.
T0.3 schema/fixtures/actions/: 12 per-kind cases plus 3 scenarios (counter plus, plus, reset;
     conditionalAction both branches; serverAction request, response state merge, error); Flutter passes.
T0.4 render fixtures with state Values gain a resolved map (prop -> value for context); Flutter passes.

### T1 Skeleton core (S1; XCTest on ubuntu, pure Swift)
T1.1 decode all 24 fixtures' expected nodes, re-encode, JSON-equal. Property: decode(encode(n)) == n.
T1.2 resolver(context) equals each fixture's resolved map. T1.3 31 transforms table-tested, plus
     properties: add then subtract is identity, split then join round-trips, trim is idempotent.
T1.4 13 BoolExpr ops with the Dart null semantics (cases lifted from the ValueResolver test group).
T1.5 ElmStore: page and app scopes, nested keys, a change notifies only subscribers of that key.
T1.6 generated caps vector equals the manifest's ios targets; hash canonicalisation matches the engine's.

### T2 Skeleton UI (S2; XCTest on macOS)
T2.1 handshake A to E from caps-412-protocol mirrored against a stub: 412 then retry then cached.
T2.2 headers: x-orca-platform ios, x-orca-sdk-version, X-Orca-Caps-Hash, screen and safe-area values.
T2.3 counter page: 16 nodes, title "Counter Example", plus increments (ViewInspector), Reset shows the
     toast for two seconds. T2.4 one golden snapshot of the counter page, iPhone 15, light.
T2.5 unknown widget type: no throw, zero-height view, one warning (mirror of safe_degrade_test.dart).

### T3 Executor (S3)
T3.1 all action fixtures pass in Swift. T3.2 effects reach adapters: navigate pushes, goBack pops,
openUrl, copyToClipboard and share hit mocked system adapters. T3.3 serverAction POST shape, response
state merged, error renders OrcaError. T3.4 basic-actions and server-actions run against the Bun server.

### T4 Degrade (S4)
T4.1 FallbackPrompt info, warn, blocking with the Flutter colours; CTA opens the URL.
T4.2 policies via stubbed responses: graceful strips the node, warn banners, require replaces the page,
     426 shows the embedded blocking page (mirror of caps-policy-e2e). T4.3 debug build shows the
     placeholder card for a degraded node; release build shows nothing.

### T5 Publish (S5) and T6 Compose (S6)
T5.1 clean machine resolves the mirror via SPM at 0.1.0-alpha.1; Package.swift at root; no tests shipped.
T5.2 README banner, Epic 23b row and User_Actions entry exist. T6 repeats T1 to T4 in Kotlin: JUnit on
ubuntu for the core, Compose UI tests with Robolectric; same fixture files, same scenarios.

### CI matrix
| job | runner | trigger |
|---|---|---|
| schema drift, T0 | ubuntu | every PR |
| swift core T1, T3.1 | ubuntu (swift toolchain) | every PR touching sdk-swift or schema |
| swift UI T2, T4 | macos | nightly and release tags |
| kotlin T6 | ubuntu | every PR touching sdk-kotlin or schema |
