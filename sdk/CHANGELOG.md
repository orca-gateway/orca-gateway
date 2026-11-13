# Changelog

## Unreleased

### Breaking

- The SDK now uses the standalone `material_ui` package instead of the framework's own Material library (`material.dart`), which Flutter 3.50 deprecates. Its Material types are distinct from the framework's, so `OrcaMaterialAppConfig.theme`, `darkTheme`, `highContrastTheme`, `highContrastDarkTheme`, `themeMode` and the deprecated `OrcaApp.theme` now take material_ui's `ThemeData` and `ThemeMode`. A `ThemeData` from the old library no longer fits there.
- The SDK now needs Dart 3.13 and Flutter 3.47 or later, the floor that `material_ui` 1.11.0 sets.
- To upgrade a host app, run `dart fix --apply --code=migrate_design_widgets`. It rewrites the imports to `package:material_ui/material_ui.dart`. If it does not add the dependency, add `material_ui: ^1.11.0` to your pubspec yourself.
- If your app passes `GlobalMaterialLocalizations` or `GlobalCupertinoLocalizations` from `flutter_localizations` in `localizationsDelegates`, take them from `material_ui` and `cupertino_ui` instead. `GlobalMaterialLocalizations.delegates` covers the Flutter, Material and Cupertino strings.
- Widgets that still import the old library, in a plugin or a package, no longer get the app's theme or its Material localizations: they see the default theme. Until they migrate, wrap them in `MaterialUiCompatibilityBridge` from `material_ui`. For the whole app, set `OrcaMaterialAppConfig.builder` to `(context, child) => MaterialUiCompatibilityBridge(child: child!)`, and OrcaApp applies it to every screen. The SDK does not add the bridge itself: `material_ui` marks it deprecated, as a temporary migration aid, and it carries over only the color scheme, text theme, platform and visual density.

## 0.3.3 - 2026-11-06

### Added

- The renderer reports each unknown widget type it draws to Orca DevTools as a `FallbackPrompt` warning, once per type per session (Epic 23b). The events the SDK sends DevTools now follow `schema/devtools-events.schema.json`: `OrcaDebug.envelope`, `DevToolsClient.deviceInfoPayload` and `DebugErrorEvent.fallbackPrompt` build them, and a conformance test compares each against the fixtures in `schema/fixtures/devtools/`.

### Fixed

- Below an app's minimum SDK version the engine answers 426 with a blocking update page. `fetchPage` now returns that page, so the app draws "Update required" instead of failing. A 426 without a page, and every other error status, still throws `OrcaClientException`.
- A `Scaffold` page, or one whose root is a scroll view, now fits under the warn-policy fallback banner. Flutter threw "RenderCustomMultiChildLayoutBox object was given an infinite size", because the wrapping `Column` gave the page unbounded height. The page now gets the space left under the banner, and the banner alone takes the top inset. In unbounded height, such as a sub-page inside a scroll view, the plain `Column` is kept as before.

## 0.3.2 - 2026-11-06

### Added

- `OrcaAnalytics`, a batched client-side event emitter (Epic 47.4). It flushes when it reaches `batchSize` events (20) or every `flushInterval` (10 s), and flushes once more on dispose. A failed send is queued again; the queue holds at most `maxBuffer` events (500) and drops the oldest. `OrcaClient.sendEvents` posts a batch to the events endpoint, best-effort.
- An anonymous device id on every request, as `x-orca-device-id` (Epic 48). At startup, `OrcaApp` reads a stable per-install id: `identifierForVendor` on iOS, `ANDROID_ID` on Android. It does this even when session tracking is off. `OrcaClient.setDeviceId` sets the id directly. If the platform lookup fails, no header is sent.
- `OrcaWebStub`, a branded placeholder for widgets that have no Flutter Web implementation, such as a map, a video surface or a recorder (Epic 38.5). Plugins register it in their `webStubs` map. It fills the slot the real widget would take, so the layout stays stable on web.
- `ActionExecutor.onEffect`, an optional sink (Epic 23b). Before performing an effect, the executor reports it there as data, as `ActionEffect(type, payload)`: a navigation push, a snackbar, a URL launch or a server call. The cross-SDK action fixtures in `schema/fixtures/actions/` assert against these effects. Without a sink, the executor behaves exactly as before.

### Fixed

- `TV.formatDate(...)` now formats on Flutter. The capability vector advertised it, but no transform was registered under that name, so the input passed through unchanged. It reads an ISO string, or a number as epoch milliseconds in UTC, then substitutes the `yyyy`, `MM`, `dd`, `HH`, `mm` and `ss` tokens. Input it cannot parse comes back unchanged.
- Dotted state keys, such as `theme.color`, now resolve in `ValueResolver` and re-render through `WatchBuilder`.
- `flutter analyze` passes on Flutter 3.41 and later. The SDK keeps `ReorderableListView.onReorder`, which 3.41 deprecated, because its replacement `onReorderItem` does not exist on the 3.24 floor, and the deprecation is now ignored.

## 0.3.1 - 2026-10-16

### Fixed

- `CircularProgressIndicator` now honours `value` (0.0–1.0, drawn from 12 o'clock over a faint
  track) and `strokeWidth`. Previously it always painted the same fixed arc. Without `value` it
  keeps the indeterminate arc it drew before.
- `closeDialog` pops exactly one sheet and never the page underneath it. A double tap (two
  queued `closeDialog`s) or a stray `closeDialog` used to pop the page, and with a single page
  left GoRouter asserted "popped the last page off of the stack" (black screen).
- `closeDialog` and `refetchPage` now request the frame they wait for. After a plain
  `GestureDetector` tap nothing else repaints, so a sheet stayed open and a refetched page did
  not appear until some unrelated frame (e.g. a scroll).

## 0.2.0 - 2026-05-06

Version-aligned release with engine 0.2.0. No SDK source changes.

## 0.1.0 - 2026-05-05

### Added

- `OrcaApp` and `OrcaPage` widgets for server-driven UI rendering
- `OrcaClient` for engine HTTP communication
- Elm-style state management (`ElmStore`, `StateManager`)
- Value resolver mirroring engine `V.*` expressions
- Action executor with 20+ built-in action handlers
- Component registry with 40+ default builders
- `WatchBuilder` for selective widget rebuilds based on state watches
- Navigation handling with `go_router` integration
- Static flow support with offline session storage
- Capability negotiation and safe degradation (FallbackPrompt)
- Animation system (`AnimationRegistry`, tween support)
- Plugin contract (`OrcaPlugin`) with merge conflict detection
- Debug infrastructure (`OrcaDebug`, telemetry, timing)
