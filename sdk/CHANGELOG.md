# Changelog

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
