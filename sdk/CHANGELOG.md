# Changelog

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
