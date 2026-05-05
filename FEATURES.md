# Orca Gateway — OSS Feature Inventory

This document enumerates every architectural feature shipped in the Orca Gateway
open-source repository. Each entry lists what the feature does, where it
lives, the primary entry point, any backing conformance fixtures, and a
maturity status.

The catalog is organized by **layer** — engine, SDK, wire contract, plugins,
and tooling — because that matches the directories in this repo. For
release-by-release context, see [CHANGELOG.md](CHANGELOG.md); for the task
breakdown, see [.claude/plans/orcagateway-epics.md](../.claude/plans/orcagateway-epics.md).

**Summary:** 13 engine features · 14 SDK features · 5 wire-contract features ·
4 plugins · 5 tooling items.

---

## Engine (Bun / TypeScript)

The engine is a Bun HTTP server that renders server-driven UI trees. Source
lives under [engine/src/](engine/src/).

### 4-Stage Page Pipeline

**What it does:** Runs every served page through `getInfoData` → `getState` →
`render` → `postRender`, so external data, initial state, and widget
construction compose in a predictable order.

**Key files:**
- [engine/src/core/pipeline.ts](engine/src/core/pipeline.ts)
- [engine/src/core/page.ts](engine/src/core/page.ts)

**Entry point:** `Page` abstract class (subclass and implement the four
stages) and `runPipeline(ctx, page)`.

**Conformance fixtures:** [schema/fixtures/render/01_text_static.json](schema/fixtures/render/01_text_static.json),
[08_info_collapse.json](schema/fixtures/render/08_info_collapse.json),
[09_partial_resolve.json](schema/fixtures/render/09_partial_resolve.json).

**Status:** stable.

**Example:** [examples/server/counter.ts](examples/server/counter.ts).

### Widget System & Base Classes

**What it does:** Five base classes — `SingleChildLayout`,
`MultiChildLayout`, `PrimitiveWidget`, `ButtonWidget`, `StructureWidget` —
enforce consistent child semantics across 80+ built-in components.
All instances are created via `.new()` static factories, never `new`.

**Key files:**
- [engine/src/types/widget.ts](engine/src/types/widget.ts)
- [engine/src/components/layout/column.ts](engine/src/components/layout/column.ts)
- [engine/src/components/structure/scaffold.ts](engine/src/components/structure/scaffold.ts)

**Entry point:** `Column.new({ children })`, `Scaffold.new({ body })`, etc.
Base classes in `types/widget.ts`.

**Conformance fixtures:** [02_column_children.json](schema/fixtures/render/02_column_children.json),
[07_scaffold_slots.json](schema/fixtures/render/07_scaffold_slots.json),
[19_icon_material.json](schema/fixtures/render/19_icon_material.json),
[20_icon_network_src.json](schema/fixtures/render/20_icon_network_src.json).

**Status:** stable.

### Value Objects & Expression System (`V.*` / `Expr.*`)

**What it does:** Any prop can be a `Valueable<T>` — static, derived from
state, transformed, conditional, or tweened. The encoder auto-extracts
a `watches[]` per node so the SDK only re-renders when relevant state
keys change. Companion `Expr.*` factories build boolean expressions for
conditionals.

**Key files:**
- [engine/src/types/value.ts](engine/src/types/value.ts)

**Entry point:** `V.static`, `V.pageState`, `V.appState`, `V.info`,
`V.request`, `V.transform`, `V.when`, `V.extractWatches`; `Expr.eq`,
`Expr.and`, `Expr.not`, `Expr.isNull`, etc.

**Conformance fixtures:** [03_state_watches.json](schema/fixtures/render/03_state_watches.json),
[05_conditional.json](schema/fixtures/render/05_conditional.json),
[06_nested_state.json](schema/fixtures/render/06_nested_state.json).

**Status:** stable. Breaking-change-free since `VALUE_KIND_VERSIONS` 1.0.0.

### Value Resolver

**What it does:** Evaluates `Value` objects at render time against page
state, app state, info data, and request context. Handles dot-path
traversal and cascades transforms and boolean expressions in a single
pass per request.

**Key files:**
- [engine/src/core/value-resolver.ts](engine/src/core/value-resolver.ts)

**Entry point:** `new ValueResolver(state, appState, info, request).resolveProps(props)`.

**Conformance fixtures:** [04_transform_chain.json](schema/fixtures/render/04_transform_chain.json),
[10_template_vars.json](schema/fixtures/render/10_template_vars.json),
[23_regex_replace.json](schema/fixtures/render/23_regex_replace.json).

**Status:** stable.

### Action System (21 action kinds)

**What it does:** Serializable event handlers that execute on tap, change,
or lifecycle triggers. Covers navigation, state mutation, server round-trips
(`ServerAction`), UI feedback (snackbar, toast, share, clipboard), animation
triggers, and lifecycle hooks. `ActionGroup` composes actions sequentially
or in parallel; `ConditionalAction` branches based on a `BoolExpr`.

**Key files:**
- [engine/src/types/action.ts](engine/src/types/action.ts)

**Entry point:** `Navigate`, `SetState`, `ServerAction`, `Sequential`,
`Parallel`, `When`, `Lifecycle`.

**Status:** stable. Custom actions via `custom:*` prefix.

**Example:** [examples/server/basic-actions.ts](examples/server/basic-actions.ts).

### Server-Side Actions (RPC)

**What it does:** Actions of type `serverAction` round-trip to the engine.
The server handler receives current state + params and returns a list of
`ResponseAction`s (`setState`, `navigate`, `updateComponent`, `showSnackbar`,
etc.) which the SDK executes in order.

**Key files:**
- [engine/src/core/server-action.ts](engine/src/core/server-action.ts)

**Entry point:** `ServerAction.create({ id, params, execute })` and
`App.registerServerAction(action)`.

**Status:** stable.

**Example:** [examples/server/server-actions.ts](examples/server/server-actions.ts).

### Flows & Routes

**What it does:** Tree-structured routing via `Flow.create()`. Supports path
parameters (`/product/:id`), redirects, per-route `onEnter`/`onExit` hooks,
nested flows, and static-vs-dynamic designation for offline caching.

**Key files:**
- [engine/src/core/flow.ts](engine/src/core/flow.ts)
- [engine/src/core/app.ts](engine/src/core/app.ts)

**Entry point:** `Flow.create({ name, routes })`, `App.create({ flows })`.

**Status:** stable.

### Cache Providers (SQLite + Redis)

**What it does:** Pluggable `CacheProvider` caches the combined output of
stages 1–3 keyed by page ID + state hash. Ships with `SQLiteCache`
(zero-config default, `bun:sqlite` with WAL) and `RedisCache` (distributed).
Per-page `CachePolicy` selects which request/state fields contribute to the
cache key.

**Key files:**
- [engine/src/core/cache.ts](engine/src/core/cache.ts)
- [engine/src/core/sqlite-cache.ts](engine/src/core/sqlite-cache.ts)
- [engine/src/core/redis-cache.ts](engine/src/core/redis-cache.ts)

**Entry point:** `Engine.setCacheProvider(provider)`; auto-selects Redis
when `REDIS_URL` is set.

**Status:** stable.

### Middleware Pipeline

**What it does:** Request/response interceptors with an `onRequest` /
`onResponse` contract. Ships with CORS, auth (API key), rate limiting,
structured logging, and error recovery middlewares.

**Key files:**
- [engine/src/core/middleware.ts](engine/src/core/middleware.ts)
- [engine/src/middlewares/cors.ts](engine/src/middlewares/cors.ts)
- [engine/src/middlewares/auth.ts](engine/src/middlewares/auth.ts)
- [engine/src/middlewares/rate-limit.ts](engine/src/middlewares/rate-limit.ts)
- [engine/src/middlewares/logging.ts](engine/src/middlewares/logging.ts)
- [engine/src/middlewares/recovery.ts](engine/src/middlewares/recovery.ts)

**Entry point:** `App.use(middleware)`; custom via the `Middleware`
interface.

**Status:** stable.

### Capability Negotiation & Fallback Policy

**What it does:** The SDK sends a capability vector (supported widget
types, value kinds, transforms, BoolExpr operators, actions) with each
request. The engine filters unsupported nodes via one of three modes:
`require` (block with `FallbackPrompt`), `graceful` (drop node, track
dropped features), `warn` (render a banner). Pure, deterministic,
cache-stable.

**Key files:**
- [engine/src/core/capability-filter.ts](engine/src/core/capability-filter.ts)
- [engine/src/core/fallback-policy.ts](engine/src/core/fallback-policy.ts)
- [engine/src/core/min-sdk-version.ts](engine/src/core/min-sdk-version.ts)

**Entry point:** `Engine.setFallbackPolicy('graceful' | 'warn' | 'require')`,
`Engine.setMinSdkVersion(v)`.

**Conformance fixtures:** [11_fallback_prompt.json](schema/fixtures/render/11_fallback_prompt.json),
[12_caps_graceful_strip.json](schema/fixtures/render/12_caps_graceful_strip.json),
[13_caps_warn_banner.json](schema/fixtures/render/13_caps_warn_banner.json),
[14_caps_require_blocker.json](schema/fixtures/render/14_caps_require_blocker.json),
[16_plugin_widget_deprecated.json](schema/fixtures/render/16_plugin_widget_deprecated.json),
[17_unsupported_widget_placeholder.json](schema/fixtures/render/17_unsupported_widget_placeholder.json).

**Status:** stable.

**Example:** [examples/server/capability-demo.ts](examples/server/capability-demo.ts).

### Widget Registry & Codegen

**What it does:** Scans every widget class and emits two generated
artifacts: a typed TS registry used by the encoder, and a
language-neutral JSON manifest consumed by plugins, alternative-language
ports, and IDE tooling. CI diffs the generated files against HEAD.

**Key files:**
- [engine/src/core/widget-registry-gen.ts](engine/src/core/widget-registry-gen.ts)
- [schema/gen-widget-registry.ts](schema/gen-widget-registry.ts)
- [schema/widget-registry.json](schema/widget-registry.json)

**Entry point:** `bun run schema/gen-widget-registry.ts`;
`WIDGET_REGISTRY` constant for introspection.

**Status:** stable.

### JSON Tree Encoder

**What it does:** Alternative encoding path that accepts a pre-serialized
JSON widget tree (`{ type, props, children, slots, actions }`) and
produces the same `ComponentNode[]` wire format as the class-based
`.new()` pipeline. Powers dashboard authoring, persistence layers, and
plugin widget registration.

**Key files:**
- [engine/src/core/json-tree-encoder.ts](engine/src/core/json-tree-encoder.ts)

**Entry point:** `new JsonTreeEncoder(options).encode(tree)`.

**Conformance fixtures:** [15_plugin_widget.json](schema/fixtures/render/15_plugin_widget.json),
[18_sub_page.json](schema/fixtures/render/18_sub_page.json).

**Status:** stable.

### Monitoring & Observability

**What it does:** Non-blocking event emitter that broadcasts lifecycle
signals — `onCacheHit`, `onCacheMiss`, `onAction`, `onPageRender`,
`onError`, session start/end — to registered `Monitor` implementations.
`TimingCollector` captures per-stage latency and is available via the
`X-Orca-Debug` header. A debug ring buffer retains the last 100 requests.

**Key files:**
- [engine/src/core/monitor.ts](engine/src/core/monitor.ts)
- [engine/src/core/timing.ts](engine/src/core/timing.ts)
- [engine/src/core/debug-store.ts](engine/src/core/debug-store.ts)

**Entry point:** `Engine.registerMonitor(monitor)`, `ConsoleMonitor`,
`GET /api/v1/debug/last-requests`.

**Status:** stable.

---

## Flutter SDK

The Flutter SDK renders the engine's wire format natively. Source lives
under [sdk/lib/src/](sdk/lib/src/).

### ElmStore

**What it does:** Unidirectional state container backed by
`ChangeNotifier`. Dispatches updates through pure reducers; widgets
subscribe only to keys they watch.

**Key files:**
- [sdk/lib/src/state/elm_store.dart](sdk/lib/src/state/elm_store.dart)

**Entry point:** `ElmStore(initialState)`, `store.dispatch(update)`,
`store.get(key)`.

**Status:** stable.

### StateManager

**What it does:** Owns one app-scoped store (survives navigation) plus
one page-scoped store per live page. Initializes both from the
`StateDefinition[]` returned by the engine.

**Key files:**
- [sdk/lib/src/state/state_manager.dart](sdk/lib/src/state/state_manager.dart)

**Entry point:** `StateManager.initPage(pageId, definitions)`,
`getPageStore(pageId)`, `appStore`.

**Status:** stable.

### ComponentRegistry

**What it does:** Maps wire-format `type` strings to Flutter
`WidgetBuilder`s. Plugins register custom builders here. Also tracks
per-widget web-support metadata for graceful degradation in the cloud
Flutter Web preview.

**Key files:**
- [sdk/lib/src/rendering/component_registry.dart](sdk/lib/src/rendering/component_registry.dart)

**Entry point:** `ComponentRegistry.register(type, builder)`,
`registerWebStub(type, stub)`.

**Status:** stable.

### ComponentRenderer

**What it does:** Walks the flat `ComponentNode[]` list, builds a
lookup map by ID, and constructs the Flutter widget tree recursively.
Wraps nodes that declare `watches` in a `WatchBuilder` for selective
rebuild.

**Key files:**
- [sdk/lib/src/rendering/component_renderer.dart](sdk/lib/src/rendering/component_renderer.dart)

**Entry point:** `ComponentRenderer(nodes: ..., registry: ...).render()`.

**Status:** stable.

### WatchBuilder

**What it does:** A `StatefulWidget` that subscribes to a specific list of
state keys and only rebuilds when one of them changes. Auto-applied by
`ComponentRenderer` when a node has non-empty `watches`.

**Key files:**
- [sdk/lib/src/state/watch_builder.dart](sdk/lib/src/state/watch_builder.dart)

**Entry point:** `WatchBuilder(watches: [...], builder: ...)`.

**Conformance fixtures:** [03_state_watches.json](schema/fixtures/render/03_state_watches.json),
[22_template_params_watches.json](schema/fixtures/render/22_template_params_watches.json).

**Status:** stable.

### ValueResolver (Dart mirror)

**What it does:** Client-side twin of the engine `ValueResolver`. Resolves
static / state / info / request / event / transform / conditional / tween /
tweenSequence values against the current client state. Shares transform
and BoolExpr semantics with the engine.

**Key files:**
- [sdk/lib/src/state/value_resolver.dart](sdk/lib/src/state/value_resolver.dart)

**Entry point:** `ValueResolver.resolve(value)`, `resolveToString(value)`,
`PipeTransformRegistry` for custom transforms.

**Status:** stable.

### ActionExecutor

**What it does:** Dispatches serialized actions (Navigate, SetState,
ServerAction, Sequential, Parallel, Conditional, ShowSnackbar,
CopyToClipboard, OpenUrl, Share, etc.) by matching the `type` string to
a handler. 40+ built-ins; plugins can register custom handlers.

**Key files:**
- [sdk/lib/src/state/action_executor.dart](sdk/lib/src/state/action_executor.dart)

**Entry point:** `ActionExecutor.execute(action, context)`.

**Status:** stable.

### ComponentStore

**What it does:** Mutable flat map of `ComponentNode` IDs to nodes.
Supports structural mutations returned by server actions
(`updateComponent`, `deleteComponent`, `addComponent`, `replaceComponent`)
and notifies listeners on every mutation.

**Key files:**
- [sdk/lib/src/state/component_store.dart](sdk/lib/src/state/component_store.dart)

**Entry point:** `componentStore.updateComponent(id, patch)`,
`deleteComponent(id)`, `addComponent(parentId, node)`.

**Status:** stable.

### OrcaClient

**What it does:** HTTP transport for page fetches, nav config, and
server-action round-trips. Hashes the device capability vector and
sends it as a header so the engine can filter unsupported nodes.
Pluggable `http.Client` for testing.

**Key files:**
- [sdk/lib/src/client/orca_client.dart](sdk/lib/src/client/orca_client.dart)

**Entry point:** `OrcaClient.fetchPage(appId, path)`,
`getNavConfig(appId)`, `executeServerAction(action, params)`.

**Status:** stable.

### StaticFlowManager

**What it does:** Caches static flow nav configs and pre-rendered pages
to `SharedPreferences` for offline boot. Hot-path in-memory cache +
cold persistent storage with dynamic path normalization.

**Key files:**
- [sdk/lib/src/client/static_flow_manager.dart](sdk/lib/src/client/static_flow_manager.dart)

**Entry point:** `StaticFlowManager.saveFlowPages(flow, pages)`,
`loadFlowPages(flow)`.

**Status:** stable.

### OfflineSessionStore

**What it does:** Persists session start/end events to
`SharedPreferences` while offline, and replays them to the engine's
monitor endpoint on reconnect for analytics.

**Key files:**
- [sdk/lib/src/client/offline_session_store.dart](sdk/lib/src/client/offline_session_store.dart)

**Entry point:** `OfflineSessionStore.save(record)`,
`load()`, `clear()`.

**Status:** stable.

### OrcaPlugin (plugin contract)

**What it does:** Base class for SDK plugins. A plugin bundles custom
widgets, action handlers, trigger declarations, and optional web-only
stubs. The SDK discovers and registers everything a plugin exports on
boot.

**Key files:**
- [sdk/lib/src/plugins/orca_plugin.dart](sdk/lib/src/plugins/orca_plugin.dart)

**Entry point:** Subclass `OrcaPlugin`, override `registerWidgets`,
`registerActions`, `registerTriggers`.

**Status:** stable.

### OrcaDebug

**What it does:** Opt-in debug mode. Captures state changes, action
dispatches, network requests, and timing; optionally streams events
over a WebSocket to a devtools app on `localhost:6363`. Microtask
batching keeps the hot path cheap.

**Key files:**
- [sdk/lib/src/debug/orca_debug.dart](sdk/lib/src/debug/orca_debug.dart)
- [sdk/lib/src/debug/debug_events.dart](sdk/lib/src/debug/debug_events.dart)
- [sdk/lib/src/debug/dev_tools_client.dart](sdk/lib/src/debug/dev_tools_client.dart)

**Entry point:** `OrcaDebug.init(OrcaDebugConfig(enabled: true))`.

**Status:** beta. Default-off; used in dev builds.

### OrcaTelemetry

**What it does:** Minimal process-lifetime telemetry sink. Deduplicates
and forwards events like "unknown widget type seen" to a consumer-provided
callback. Keeps network noise low while surfacing compatibility gaps.

**Key files:**
- [sdk/lib/src/telemetry/orca_telemetry.dart](sdk/lib/src/telemetry/orca_telemetry.dart)

**Entry point:** `OrcaTelemetry.onEvent = (event) => ...`.

**Status:** beta.

---

## Schema & Wire Contract

The [schema/](schema/) directory is the single crossing point between the
engine, SDK, plugins, and any alternative-language port. Anything on the
wire has a JSON schema and at least one conformance fixture.

### Wire-Format JSON Schema Suite

**What it does:** Eight canonical schemas define every byte that crosses
the wire: component nodes, values, actions, flows, navigation config,
page definitions, page responses, plugin manifests.

**Key files:**
- [schema/component-node.schema.json](schema/component-node.schema.json)
- [schema/value.schema.json](schema/value.schema.json)
- [schema/action.schema.json](schema/action.schema.json)
- [schema/flow-definition.schema.json](schema/flow-definition.schema.json)
- [schema/navigation-config.schema.json](schema/navigation-config.schema.json)
- [schema/page-definition.schema.json](schema/page-definition.schema.json)
- [schema/page-response.schema.json](schema/page-response.schema.json)
- [schema/plugin-manifest.schema.json](schema/plugin-manifest.schema.json)

**Entry point:** Any JSON-Schema-aware tool can validate against these
files; the engine and SDK both codegen types from them.

**Status:** stable.

### Widget Registry Manifest

**What it does:** Language-neutral JSON listing every widget, its
kind/childMode, supported props, and introduction version.
Alternative-language engine ports, plugin validators, and authoring
tools read this manifest instead of parsing TypeScript.

**Key files:**
- [schema/widget-registry.json](schema/widget-registry.json)
- [schema/gen-widget-registry.ts](schema/gen-widget-registry.ts)

**Entry point:** Regenerated by `bun run schema/gen-widget-registry.ts`.

**Status:** stable.

### Conformance Fixture Suite

**What it does:** 23 end-to-end fixtures under
[schema/fixtures/render/](schema/fixtures/render/), each pairing an input
page definition with the exact resolved `ComponentNode[]` output.
Any wire-format change must add a fixture; any downstream consumer
(Dart engine port, SDK renderer, future Go port) runs the full suite as
its regression harness.

**Key files:** [schema/fixtures/render/01_text_static.json](schema/fixtures/render/01_text_static.json)
through [23_regex_replace.json](schema/fixtures/render/23_regex_replace.json).

**Entry point:** Read a fixture, encode the `input`, diff against
`expected`.

**Status:** stable. Coverage: state, transforms, conditionals,
watches, partial resolve, templating, plugin widgets, capability
negotiation, icons, sub-pages, regex.

### Plugin Manifest Schema

**What it does:** Declares what a plugin contributes — custom widgets,
action kinds, value kinds, transforms — so the engine can validate
plugin packages at load time and the SDK knows which capabilities to
advertise.

**Key files:**
- [schema/plugin-manifest.schema.json](schema/plugin-manifest.schema.json)

**Entry point:** Ship a `plugin.json` matching this schema alongside
your plugin package.

**Status:** stable.

### Value Resolution & Transform Pipeline (contract level)

**What it does:** The schema-level specification of value kinds
(`static`, `pageState`, `appState`, `info`, `request`, `event`,
`transform`, `conditional`, `tween`, `tweenSequence`), transform kinds
(string / number / boolean / collection / format), and BoolExpr
operators. The engine and SDK both implement against this spec; drift
is caught by the conformance suite.

**Key files:**
- [schema/value.schema.json](schema/value.schema.json)
- Fixtures [04_transform_chain.json](schema/fixtures/render/04_transform_chain.json),
  [10_template_vars.json](schema/fixtures/render/10_template_vars.json),
  [21_template_params.json](schema/fixtures/render/21_template_params.json),
  [23_regex_replace.json](schema/fixtures/render/23_regex_replace.json).

**Status:** stable.

---

## Plugins

Out-of-tree Flutter plugins under [plugins/](plugins/). Each plugin
registers custom widgets and action handlers via `OrcaPlugin`.

### orca_google_map

Google Maps with server-controlled markers, camera, and pan/zoom event
callbacks. Location: [plugins/orca_google_map/](plugins/orca_google_map/).
**Status:** beta.

### orca_push_notification

FCM token management, permission flow, and server-driven notification
display. Location: [plugins/orca_push_notification/](plugins/orca_push_notification/).
**Status:** beta.

### orca_video_player

Server-driven video playback with play/pause/seek controls and progress
events. Location: [plugins/orca_video_player/](plugins/orca_video_player/).
**Status:** beta.

### orca_voice_recorder

Audio recording with start/stop/pause, amplitude monitoring, and
playback. Location: [plugins/orca_voice_recorder/](plugins/orca_voice_recorder/).
**Status:** beta.

---

## Tooling & Developer Experience

### Dart Engine Port

**What it does:** A full Dart reimplementation of the rendering engine.
Passes all 23 conformance fixtures and is used by the Flutter SDK for
offline pre-rendering and embedded scenarios.

**Key files:** [engine-dart/lib/](engine-dart/lib/), [engine-dart/test/](engine-dart/test/).

**Status:** beta. 100% fixture parity with the Bun engine.

### DevTools Extension

**What it does:** Desktop app (Flutter macOS / Windows / Linux) that
receives the SDK's debug stream over WebSocket and visualizes timeline,
state, actions, network, and errors. Multiple connected SDK instances
show as separate tabs.

**Key files:** [devtools/lib/](devtools/lib/), [devtools/README.md](devtools/README.md).

**Status:** beta.

### CLI

**What it does:** Project scaffolding and plugin management CLI.

**Key files:** [cli/bin/](cli/bin/), [cli/lib/](cli/lib/).

**Status:** beta.

### Example Applications

**What it does:** Reference servers in [examples/server/](examples/server/)
for every major capability:

| Example | What it demonstrates |
|---|---|
| [counter.ts](examples/server/counter.ts) | State + SetState, minimum-viable page |
| [ecommerce.ts](examples/server/ecommerce.ts) | Multi-page nav, cart, checkout |
| [basic-actions.ts](examples/server/basic-actions.ts) | Navigate, CopyToClipboard, OpenUrl |
| [server-actions.ts](examples/server/server-actions.ts) | Server round-trip with response actions |
| [static-flows.ts](examples/server/static-flows.ts) | Offline-capable flows |
| [animations.ts](examples/server/animations.ts) | Tweens and transitions |
| [capability-demo.ts](examples/server/capability-demo.ts) | Fallback policy modes |
| [custom.ts](examples/server/custom.ts) | Custom widget + action registration |

Run all with `task example:dev`. **Status:** stable.

### Astro Documentation Site

**What it does:** Starlight-based docs under [docs-site/](docs-site/)
with getting-started guides, concept walk-throughs, and reference
material. Live at docs.orcagateway.com.

**Key files:** [docs-site/src/content/docs/](docs-site/src/content/docs/).

**Status:** beta. Content filled in as features land.

---

## How this catalog maps to the epic plan

The 23 OSS epics in
[.claude/plans/orcagateway-epics.md](../.claude/plans/orcagateway-epics.md)
each contribute one or more features above. The table below is the
completeness gate — no epic is silently dropped.

| Epic | Title | Primary catalog entries |
|---|---|---|
| 1 | Project Scaffolding | _(repo structure — not a runtime feature)_ |
| 2 | Core Type System | Widget System · Value Objects · Action System |
| 3 | Primitive Components | Widget System |
| 4 | Flatten Pipeline | 4-Stage Page Pipeline · Widget Registry & Codegen |
| 5 | HTTP Server + Page Handler | 4-Stage Page Pipeline · Flows & Routes |
| 6 | Flutter SDK — Component Rendering | ComponentRegistry · ComponentRenderer · OrcaClient |
| 7 | State Management (Elm) | ElmStore · StateManager |
| 8 | Basic Actions | ActionExecutor · Action System |
| 9 | Value Resolver (Server-Side) | Value Resolver |
| 10 | Transformers | Value Resolution & Transform Pipeline |
| 11 | Conditions + Watches | Value Objects · WatchBuilder · ValueResolver (Dart) |
| 12 | ActionGroup | Action System |
| 13 | Server Actions | Server-Side Actions · ComponentStore |
| 14 | Navigation System | Flows & Routes |
| 15 | Cache Layer | Cache Providers (SQLite + Redis) |
| 16 | Auth + Middleware | Middleware Pipeline |
| 17 | Static Flows + Offline | StaticFlowManager · OfflineSessionStore |
| 18 | Monitor System | Monitoring & Observability |
| 19 | Engine Timing Collection | Monitoring & Observability |
| 20 | Flutter SDK Debug Mode | OrcaDebug · OrcaTelemetry |
| 21 | Orca Gateway Dev Tools Desktop App | DevTools Extension |
| 22 | Documentation | Astro Documentation Site |
| 23 | Examples + Launch | Example Applications · CLI |
