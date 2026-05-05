# Changelog

## 0.1.0 - Unreleased

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
