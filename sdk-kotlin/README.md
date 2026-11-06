# Orca Gateway Android SDK (`sdk-kotlin`)

> [!WARNING]
> **Experimental, not ready yet.** This is the in-progress native Android client for Orca Gateway
> (Epic 23b). It has no UI yet and nothing is published. Use the Flutter SDK
> ([`orca_gateway`](https://github.com/orca-gateway/orca-gateway/tree/main/sdk)) instead.

The SDK will render the same server-driven pages as the Flutter and iOS SDKs, from the same Bun
engine and the same wire format ([`schema/`](https://github.com/orca-gateway/orca-gateway/tree/main/schema)).
Widget names on the wire stay Flutter's (`Column`, `Row`, `Text`); the Compose layer will map them
to Material 3.

## Layout

| Module | What | Platforms |
|---|---|---|
| `core` | Wire models (`ComponentNode`, `Value`, `Action`, `PageResponse`), `ValueResolver` (9 Value kinds, 31 transforms, 13 BoolExpr ops), `ElmStore` with page and app scopes, the action executor with effects as data, the render tree, the generated capability vector. kotlinx.serialization only. Artifact `com.orcagateway:sdk-core`. | JVM 17+, Android |
| `sdk` | Compose renderer, views and adapters (slice S7 onward). Artifact `com.orcagateway:sdk`. | Android |

Build: Gradle 9 through the committed wrapper, Kotlin 2.4, any JDK 17 or later.

## Status by slice

| Slice | Content | State |
|---|---|---|
| S6 | Pure core: models, resolver, store, executor, caps vector, Linux CI | this package |
| S7 | `sdk` module: `OrcaClient` with the 412 caps handshake, Compose renderer, 15 core widgets, counter app | planned |
| S8 | Navigation, system and server adapters, DevTools | planned |
| S9 | Degrade policies and the 426 page, ten more widgets, theme hooks | planned |
| S10 | `0.1.0-alpha.1` on Maven Central | planned |

## Tests

```bash
task sdk-kotlin:test        # or: cd sdk-kotlin && ./gradlew :core:test
```

The tests read the conformance fixtures from `../schema/fixtures/` at run time (render fixtures,
their `resolved` maps, action fixtures), the same files the engine, the Flutter SDK and the Swift SDK
run, so they only run inside the monorepo. CI runs them on Linux for every PR touching `sdk-kotlin/`
or `schema/`.

## Capabilities

`core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt` is generated; do not edit it.
It lists the widgets and action kinds named in [`capabilities.json`](capabilities.json) (each widget
must carry the `android` target in `schema/widget-registry.json`) plus every value kind, transform
and BoolExpr op of the engine. Add a widget or action kind to `capabilities.json` in the same PR
that implements it, then regenerate from the monorepo root:

```bash
bun run schema/gen-native-capabilities.ts
```

## Versioning

`VERSION` holds the SDK version and feeds `sdkSemver` in the capability vector. It is bumped only by
`scripts/release.sh` (from slice S10), never by hand.

## License

[Business Source License 1.1](LICENSE), as the rest of Orca Gateway.
