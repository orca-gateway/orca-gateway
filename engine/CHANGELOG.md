# Changelog

## 0.2.4 - 2026-05-07

### Fixed

- **Critical**: every page rendered as an empty container (`Scaffold` with no slots, `Column` with no children, etc.). Root cause was a bundler-level dual-package hazard: each entry point (`./core`, `./components`, `./types`, `./middlewares`) was built as a standalone bundle that inlined its own copy of `MultiChildLayout`, `StructureWidget`, and other base classes from `widget.ts`. Same source file → distinct class identities at runtime → the encoder's `widget instanceof MultiChildLayout` checks failed across entry-point boundaries, so children and slots were silently dropped from every encoded tree. Fixed by switching to a single `bun build` invocation with `--splitting`, which extracts shared internals into a chunk that every entry point references — restoring single-identity for `widget.ts` classes across the package.

## 0.2.3 - 2026-05-07

### Added

- New `@orca-gateway/engine/middlewares` public export. Re-exports `corsMiddleware`, `loggingMiddleware`, `recoveryMiddleware`, `authMiddleware`, and `rateLimitMiddleware`. Previously these lived only in `src/middlewares/` and consumers had to reach into source.

### Fixed

- **Critical**: closing the dual-package hazard. Showcase and other consumers that mixed source-path imports (`../../open-source/engine/src/...`) with published-package imports (`@orca-gateway/engine/...`) hit silent `instanceof` mismatches in the encoder — widget classes from the published package failed `instanceof MultiChildLayout` against the engine's local-source class identity, so children were dropped from every rendered page. The middleware export removes the last reason a server consumer would need to import from source.

## 0.2.2 - 2026-05-07

### Fixed

- Re-export `MaterialIcons` (icon-name string union) from `@orca-gateway/engine/types`. The type lived in `src/types/icons.ts` but was never re-exported through the public barrel, so consumers couldn't reach it via the published package. The icons module itself is unchanged — only the public surface widens.

## 0.2.1 - 2026-05-07

### Fixed

- Add a root `"."` export so `import { ... } from "@orca-gateway/engine"` resolves correctly. The 0.2.0 publish only exposed `./core`, `./types`, and `./components` subpaths, leaving bare imports unresolvable. The root barrel re-exports `core` + `components`; `types` remains under its subpath because `Transform` collides between `types` (wire-format) and `components` (widget class).

## 0.2.0 - 2026-05-06

### Changed

- The npm package now ships a built `dist/` artifact instead of raw TypeScript source. JS is bundled per entry point and minified (variable names mangled, dead code eliminated, whitespace stripped); `.d.ts` declarations are emitted in full so consumers retain end-to-end type safety.
- `exports` map updated to use conditional exports (`types` + `import` per entry).
- `prepublishOnly` script now runs the build automatically.

### Fixed

- `SliverAppBar` private fields are now correctly typed as `Valueable<T>` instead of raw primitives, so `V.pageState` / `V.transform` values are no longer silently coerced when the encoder serializes them.
- `RedisCache.socket` definite-assignment annotation under TypeScript `strict` mode.

## 0.1.0 - 2026-05-05

Initial release.
