# Contributing to Orca Gateway

Thank you for your interest in contributing to Orca Gateway! This guide will help you get started.

## Prerequisites

- [Bun](https://bun.sh) >= 1.0
- [Flutter](https://flutter.dev) >= 3.0
- [Task](https://taskfile.dev) >= 3.0
- Docker & Docker Compose

## Getting Started

```bash
# Clone the repo
git clone https://github.com/orca-gateway/orca-gateway.git
cd open-source

# Start infrastructure (Postgres)
task docker:up

# Start engine dev server
task engine:dev

# Run all tests
task test:all
```

## Monorepo Layout

| Directory    | What it is                                      |
| ------------ | ----------------------------------------------- |
| `engine/`    | Bun/TypeScript SDUI engine and HTTP API          |
| `sdk/`       | Flutter package — renders server-driven UI       |
| `schema/`    | JSON Schema definitions, codegen, fixtures       |
| `plugins/`   | Out-of-tree Flutter plugins (maps, video, etc.)  |
| `examples/`  | Example server + Flutter app                     |
| `docs-site/` | Astro documentation site                         |
| `cli/`       | CLI tooling for plugin management                |
| `devtools/`  | Flutter DevTools extension                       |

## Running Tests

```bash
# All tests
task test:all

# Engine only
task engine:test

# SDK only
task sdk:test

# SDK static analysis
task sdk:analyze

# Single engine test file
cd engine && bun test path/to/file.test.ts

# Single SDK test by name
cd sdk && flutter test test/file_test.dart --name "test name"
```

## Making Changes

### Branch Naming

Use prefixes that describe the change type:

- `feat/` — new feature
- `fix/` — bug fix
- `docs/` — documentation
- `refactor/` — code restructuring
- `test/` — adding or updating tests

### Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(engine): add WebSocket support for live updates
fix(sdk): prevent crash on malformed server response
docs: update README quick start section
```

### Wire Format Changes

If your change touches the wire format (new Value kind, Transform, Action, widget, etc.), you **must** update all 5 sync points:

1. `schema/*.schema.json`
2. `engine/src/types/`
3. `sdk/lib/src/models/`
4. Engine encoder + SDK component renderer
5. `schema/fixtures/render/` — add a conformance fixture

After modifying widgets, regenerate the registry:

```bash
bun run schema/gen-widget-registry.ts
```

### Pull Request Process

1. Fork the repo and create your branch from `main`
2. Make your changes with tests
3. Ensure `task test:all` passes
4. Open a PR with a clear description of the change and motivation
5. Wait for review — all PRs require maintainer approval

### PR Checklist

- [ ] Tests pass (`task test:all`)
- [ ] New features include tests
- [ ] Documentation updated if applicable
- [ ] CHANGELOG entry added for user-facing changes
- [ ] Wire format changes include conformance fixtures

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Report unacceptable behavior to hello@orcagateway.com.

## License

By contributing to Orca Gateway, you agree that your contributions will be licensed under the same license as the project. See [LICENSE](LICENSE) for details.

## Questions?

- Open a [GitHub Discussion](https://github.com/orca-gateway/orca-gateway/discussions) for questions
- Email hello@orcagateway.com for private inquiries
