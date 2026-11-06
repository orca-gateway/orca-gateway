# 05 · Technical design · native-sdk

## Front page

### In one breath
A pure core (models, resolver, Elm store, executor emitting effects, caps vector) behind platform
adapters (HTTP, renderer, navigation, toast, storage); one in Swift, one in Kotlin, both proven by
the render fixtures plus new action fixtures; models and caps vectors generated from the manifest.

### New for you
1. Technology Compatibility Kit (TCK), fixtures as the spec → learning/tck-conformance-kit.md

### Trade-offs
1 needs you: logic core, two native (Swift, Kotlin) vs one Kotlin Multiplatform core; default two.
2 needs you: models, generated from the manifest (like Dart caps) vs hand-written; default gen.
3 needs you: action fixtures, assert state and emitted effects vs state only; default both.
4 needs you: re-render, per node via its watches (as Flutter SDK) vs whole page; default per node.

### Questions for you
1. Layout? (default: sdk-swift/ and sdk-kotlin/; tasks sdk-swift:test and sdk-kotlin:test; one CI)
2. Fixtures in native tests? (default: read ../schema/fixtures at run time; mirror ships no tests)
3. Decoding? (default: Swift Codable with a custom Value decoder; Kotlin kotlinx.serialization)
4. Targets source? (default: static targets on each widget class, read by gen-widget-registry.ts)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-design module replaces it.

### Components, per SDK
core/: Models (ComponentNode, Value, Action, PageResponse); ValueResolver (9 Value kinds, 31 transforms,
13 BoolExpr ops); ElmStore (page and app scopes, watches); ActionExecutor (28 action kinds in, new state plus an
Effect list out); Caps (generated, like sdk/lib/src/capabilities/generated.dart).
adapters/: OrcaClient (URLSession / OkHttp; sends x-orca-platform, x-orca-sdk-version, X-Orca-Caps-Hash,
screen and safe-area headers); Renderer + Registry (type to view builder, unknown type degrades safely);
Navigation (NavigationStack / NavHost); Presentation (toast, sheet, alert); Storage (UserDefaults /
DataStore). Only adapters touch a platform API.

### Page load and tap, in sequence
OrcaApp -> client GET page with caps headers -> PageResponse decoded -> store seeded from state defs ->
Renderer walks ComponentNode[], each node view subscribes to its watches -> tap -> executor(action,
state) -> (state', effects) -> store commits state' -> adapters run effects (navigate, toast, POST).

### Conformance, the TCK
render: schema/fixtures/render/*.json (input + context -> expected), run by XCTest and JUnit as bun does.
actions: new schema/fixtures/actions/*.json {initialState, action, context, expected: {state, effects}}.
The Flutter SDK runs them first, so the Dart executor becomes the reference; then Swift, then Kotlin.

### Codegen additions
gen-widget-registry.ts gains targets per widget; a gen-native-capabilities.ts emits the Swift and Kotlin
caps files; schema.yml diffs them like the Dart one. tools/gen-go-registry.ts picks targets up for free.

### Alternatives considered
Kotlin Multiplatform core: one port of the logic, but iOS gets a binary XCFramework, Swift interop goes
through Objective-C, and the mirror must carry binaries. Whole-page re-render: simpler, visibly slower.

### Finding, verified after the video session
action.schema.json lists 23 action kinds; engine/src/types/action.ts and the SDK caps vector list 28
(closeDialog, debugLog, refetchPage, plus the lifecycle modes always and once). The schema, which is the
contract, lags the types. Action fixtures (trade-off 3) must be cut from a re-synced schema, not from
the Dart code. Also: 7 of the 9 Value kinds resolve client-side; info and request resolve in the engine.
Earlier cards quoted the schema's 23 and a lumped 43; the counts above are the verified ones.

### Carried
scope: thin alpha, sized in stage 06 · spec source: action fixtures first (trade-off 3 here).
