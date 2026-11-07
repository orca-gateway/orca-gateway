# Orca Gateway Android SDK (`sdk-kotlin`)

> [!WARNING]
> **Experimental, not ready yet.** This is the in-progress native Android client for Orca Gateway
> (Epic 23b). It draws 15 widgets so far and nothing is published. Use the Flutter SDK
> ([`orca_gateway`](https://github.com/orca-gateway/orca-gateway/tree/main/sdk)) instead.

The SDK will render the same server-driven pages as the Flutter and iOS SDKs, from the same Bun
engine and the same wire format ([`schema/`](https://github.com/orca-gateway/orca-gateway/tree/main/schema)).
Widget names on the wire stay Flutter's (`Column`, `Row`, `Text`); the Compose layer will map them
to Material 3.

## Layout

| Module | What | Platforms |
|---|---|---|
| `core` | Wire models (`ComponentNode`, `Value`, `Action`, `PageResponse`), `ValueResolver` (9 Value kinds, 31 transforms, 13 BoolExpr ops), `ElmStore` with page and app scopes, the action executor with effects as data, the render tree, `OrcaClient` with the 412 caps handshake behind an `HttpTransport` interface, the generated capability vector. kotlinx.serialization only. Artifact `com.orcagateway:sdk-core`. | JVM 17+, Android |
| `sdk` | The OkHttp transport, `DeviceInfo.current(context)`, the Compose renderer with the 15 core widgets, `OrcaApp`. Artifact `com.orcagateway:sdk`. | Android 7.0+ (minSdk 24) |

Build: Gradle 9 through the committed wrapper, Kotlin 2.4, AGP 9, any JDK 17 or later, and an
Android SDK with platform 36 (`ANDROID_HOME` or `local.properties`).

## Status by slice

| Slice | Content | State |
|---|---|---|
| S6 | Pure core: models, resolver, store, executor, caps vector, Linux CI | done |
| S7 | `OrcaClient` with the 412 caps handshake, the `sdk` module: Compose renderer, 15 core widgets, `OrcaApp`; the counter app in [`examples/app-android`](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-android) | this package |
| S8 | Navigation, system and server adapters, DevTools | planned |
| S9 | Degrade policies and the 426 page, ten more widgets, theme hooks | planned |
| S10 | `0.1.0-alpha.1` on Maven Central | planned |

## Tests

```bash
task sdk-kotlin:test        # or: cd sdk-kotlin && ./gradlew :core:test :sdk:testDebugUnitTest
```

The core tests read the conformance fixtures from `../schema/fixtures/` at run time (render
fixtures, their `resolved` maps, action fixtures), the same files the engine, the Flutter SDK and
the Swift SDK run, so they only run inside the monorepo. The `sdk` tests run the Compose UI on the
JVM under Robolectric, no emulator, against pages recorded from the example server
(`task sdk-kotlin:record`). CI runs both, plus the example app's build, on Linux for every PR
touching `sdk-kotlin/`, `schema/` or `examples/app-android/`.

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
