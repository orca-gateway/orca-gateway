# Orca Gateway

[![Engine CI](https://github.com/orca-gateway/orca-gateway/actions/workflows/engine.yml/badge.svg)](https://github.com/orca-gateway/orca-gateway/actions/workflows/engine.yml)
[![SDK CI](https://github.com/orca-gateway/orca-gateway/actions/workflows/sdk.yml/badge.svg)](https://github.com/orca-gateway/orca-gateway/actions/workflows/sdk.yml)
[![License](https://img.shields.io/badge/license-BSL--1.1-blue.svg)](LICENSE)

**Orca Gateway** is the open-source server-driven UI engine behind [Orca Gateway Premium](https://orcagateway.com) - control your entire Flutter app from the server: navigation, screens, state, actions, and offline behavior. No app store releases required.

## Features

Orca Gateway ships as a server-driven UI engine plus a native Flutter SDK, with
a shared JSON-schema wire contract and 23 conformance fixtures pinning the
renderer's behavior. The full feature inventory - 13 engine, 14 SDK, 5 wire
contract, 4 plugins, 5 tooling items - with file references, entry points, and
maturity status is in **[FEATURES.md](FEATURES.md)**.

At a glance: server-driven navigation · native Flutter rendering (no
WebViews) · 80+ built-in widgets · reactive `V.*` / `Expr.*` value system ·
21 action kinds including server round-trips · pluggable SQLite / Redis
caching · offline-capable static flows · `OrcaPlugin` contract for custom
widgets · capability negotiation with three fallback modes · DevTools
extension.

## Architecture

```
engine/    → Bun (TypeScript) - SDUI engine, HTTP API, 4-stage page pipeline
sdk/       → Flutter package - renders server-driven UI natively
schema/    → JSON Schema definitions, codegen, conformance fixtures
plugins/   → Out-of-tree Flutter plugins (maps, video, voice, push)
examples/  → Example server implementations + Flutter app
cli/       → CLI tooling for plugin management
devtools/  → Flutter DevTools extension
docs-site/ → Astro documentation site
```

## Quick Start

```bash
# Start infrastructure (PostgreSQL)
task docker:up

# Start engine dev server
task engine:dev

# Run all tests
task test:all
```

## Prerequisites

- [Bun](https://bun.sh) >= 1.0
- [Flutter](https://flutter.dev) >= 3.0
- [Task](https://taskfile.dev) >= 3.0
- Docker & Docker Compose

## Examples

The `examples/server/` directory contains working server implementations:

| Example            | Description                                        |
| ------------------ | -------------------------------------------------- |
| `counter.ts`       | Basic counter with state management                |
| `ecommerce.ts`     | Product listing with cart and checkout flow         |
| `animations.ts`    | Tween animations and transitions                   |
| `basic-actions.ts` | Navigate, SetState, CopyToClipboard, OpenUrl       |
| `server-actions.ts`| Server-side action handlers with round-trips        |
| `static-flows.ts`  | Offline-capable static flow definitions             |
| `capability-demo.ts`| Capability negotiation and safe degradation        |
| `custom.ts`        | Custom widget and action registration               |

Run examples with `task example:dev` (starts both server and Flutter app).

## Community

- [Contributing](CONTRIBUTING.md) - how to set up, test, and submit PRs
- [Code of Conduct](CODE_OF_CONDUCT.md) - community guidelines
- [Security Policy](SECURITY.md) - reporting vulnerabilities
- [Changelog](CHANGELOG.md) - version history

## License

[Business Source License 1.1](LICENSE)

Copyright (c) 2026 Amr Ebada . admin@orcagateway.com
