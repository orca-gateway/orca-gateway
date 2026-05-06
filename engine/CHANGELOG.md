# Changelog

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
