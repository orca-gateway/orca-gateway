# Changelog

All notable changes to Orca Gateway will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - Unreleased

### Added

- Server-driven UI engine (Bun/TypeScript) with 4-stage page pipeline
- Flutter SDK with Elm-style state management and component rendering
- Widget system with 80+ built-in components (layout, structure, input, button, primitive)
- Value expression system (`V.static`, `V.pageState`, `V.appState`, `V.transform`, `V.conditional`, `V.tween`)
- Action system (Navigate, SetState, ServerAction, Sequential, Parallel, Conditional, etc.)
- JSON Schema definitions for wire format contract
- Widget registry codegen (TypeScript + JSON manifest)
- Conformance fixture suite for cross-implementation validation
- Plugin system (`OrcaPlugin` contract) with official plugins:
  - `orca_google_map` — Google Maps integration
  - `orca_push_notification` — Push notification handling
  - `orca_video_player` — Video playback
  - `orca_voice_recorder` — Audio recording
- Pluggable cache layer (SQLite default, Redis optional)
- Middleware system (auth, CORS, rate limiting, logging)
- Offline support with static flows and session sync
- Capability negotiation with safe degradation
- DevTools extension for component inspection
- CLI for plugin management
- Docker support (multi-stage Dockerfile, Compose for Postgres)
- CI workflows for engine and SDK
- Astro documentation site
