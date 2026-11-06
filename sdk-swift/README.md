# Orca Gateway iOS SDK (`sdk-swift`)

> [!WARNING]
> **Experimental, not ready yet.** This is the in-progress native iOS client for Orca Gateway
> (Epic 23b). The API is unstable, only a walking skeleton is planned for the first alpha, and it
> is not suitable for production use. Use the Flutter SDK ([`sdk/`](../sdk/)) instead.

The SDK renders the same server-driven pages as the Flutter SDK, from the same Bun engine and the
same wire format (`schema/`). Widget names on the wire stay Flutter's (`Column`, `Row`, `Text`);
the SwiftUI layer maps them to native views.

## Layout

| Target | What | Platforms |
|---|---|---|
| `OrcaGatewayCore` | Wire models (`ComponentNode`, `Value`, `Action`, `PageResponse`), `ValueResolver` (9 Value kinds, 31 transforms, 13 BoolExpr ops), `ElmStore` with page and app scopes, effects as data, the generated capability vector. Foundation only. | iOS 16+, macOS 13+, Linux |
| `OrcaGateway` | SwiftUI renderer, views and adapters (slice S2 onward). Re-exports the core. | iOS 16+, macOS 13+ |

Minimum: Swift tools 5.9 (Xcode 15+), iOS 16.

## Status by slice

| Slice | Content | State |
|---|---|---|
| S1 | Pure core: models, resolver, store, caps vector, Linux CI | this package |
| S2 | `OrcaClient` with the 412 caps handshake, renderer, 15 core widgets, counter page | next |
| S3 | Action executor (12 kinds), navigation, system and server adapters | planned |
| S4 | Degrade policies, FallbackPrompt, six more widgets | planned |
| S5 | `0.1.0-alpha.1` on the read-only `orca-gateway-swift` mirror | planned |

## Tests

```bash
task sdk-swift:test        # or: cd sdk-swift && swift test
```

The tests read the conformance fixtures from `../schema/fixtures/` at run time (render fixtures,
their `resolved` maps, action fixtures), the same files the engine and the Flutter SDK run, so
they only run inside the monorepo. CI runs them on Linux for every PR touching `sdk-swift/` or
`schema/`.

## Capabilities

`Sources/OrcaGatewayCore/Capabilities/Generated.swift` is generated; do not edit it. It lists the
widgets and action kinds named in [`capabilities.json`](capabilities.json) (each widget must carry
the `ios` target in `schema/widget-registry.json`) plus every value kind, transform and BoolExpr op
of the engine. Add a widget or action kind to `capabilities.json` in the same PR that implements
it, then regenerate:

```bash
bun run schema/gen-native-capabilities.ts
```

## Versioning

`VERSION` holds the SDK version and feeds `sdkSemver` in the capability vector. It is bumped only
by `scripts/release.sh` (from slice S5), never by hand.
