# Orca Engine

The SDUI engine — a Bun/TypeScript HTTP server that builds and serves server-driven UI pages.

## Architecture

Every page runs through the **4-stage pipeline** (see `src/core/pipeline.ts`):

1. **`getInfoData(ctx)`** — fetch async/external data
2. **`getState(ctx)`** — declare initial page state
3. **`render(ctx, infoData)`** — build a widget tree using `.new()` factories
4. **`flatten(widget)`** — encode into flat `ComponentNode[]` wire format

## Directory Structure

```
src/
  core/       → Engine, pipeline, encoder, cache, value resolver
  types/      → Widget, Value, Action, Node type definitions
  components/ → 80+ built-in widget classes (layout/, structure/, input/, button/, primitive/)
  middlewares/→ Auth, CORS, rate limiting, logging, recovery
  server.ts   → Entry point
```

## Key Concepts

- **Widgets** use static `.new()` factories: `Column.new({ children: [...] })`
- **Values** are reactive expressions: `V.static()`, `V.pageState()`, `V.transform()`
- **Actions** are serialized event handlers: `Navigate`, `SetState`, `ServerAction`
- **Schema** in `../schema/` is the wire format contract between engine and SDK

## Commands

```bash
bun run dev          # Dev server with hot reload
bun test             # Run tests
bun run build        # Production build
```
