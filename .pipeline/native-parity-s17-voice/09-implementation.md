# 09 · Implementation · native-parity-s17-voice

## Front page

### In one breath
group 1 of 4 · tasks: 5 green, 0 blocked · cases: 5 of 18 green · cli dart test: 38 pass
T1 Voice schema: the yaml describes Flutter's widget, 3 triggers, 9 actions; a test pins it.
T2 --types-only: the CLI writes the props, params and trigger types alone; full stubs unchanged.
T3 Ignore files: the pub archive leaves out ios/ and android/; both lanes' build outputs ignored.
T4 Android package: a Gradle build on the SDK's wrapper and catalog, publishable to Maven.
T16 (added): TS string action params take a Value, so the demo can play the saved path.

### New for you
nothing new

### Trade-offs
2 auto-decided: T16 added to group 1 (minor) · the Gradle project named orca-voice-recorder

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 2 (Swift package, Kotlin types, the /voice demo page)? (default: go)

## Appendix

### Group 1
#### T1 · Voice schema block; no-schema test retargeted (e1505b9)
Files: plugins/orca_voice_recorder/orca_plugin.yaml · cli/test/plugin_generate_test.dart ·
cli/test/voice_recorder_schema_test.dart (new)
Cases: C17.5/yaml → green (cli 36 with T2's tests; analyze clean; the 3 new tests red first; 8 hand mutations of
the yaml each caught; the moved C16.6 test green before and after)
Changed: the yaml gains `schema:` in google_map's format: VoiceRecorder (recorderId string, showAmplitude boolean
default true), triggers onAmplitudeChange, onStateChange, onRecordingComplete (declared, never fired, said in its
description), the 9 actions with Flutter's params, required, defaults, scope enum page|app; the new test parses it
with the CLI's parser and checks it against voice_recorder_plugin.dart's source names, reads, types and defaults;
the C16.6 no-schema case writes its own temp manifest.
Decisions: trigger payloads in an `event_data:` block the parser ignores · no `format` param on startRecording
(Flutter reads none, V3) · triggers in Flutter's registration order
Review fit: pass · Review quality: pass

#### T2 · CLI --types-only; full stubs byte-identical (e25299e, c9aa4d5 rework)
Files: cli/lib/src/commands/plugin_generate.dart · cli/lib/src/generators/swift_generator.dart ·
cli/lib/src/generators/kotlin_generator.dart · cli/test/swift_generator_test.dart · cli/test/kotlin_generator_test.dart
Cases: C17.5/gen → green (6 new tests; the 4 --types-only tests red first; the 2 byte-for-byte pins green before
the change, as pins of today's output)
Changed: `--types-only` writes `<Pascal>Types.swift` / `.kt` with the props, params and trigger names and no plugin
stub; the Swift types file imports only OrcaGateway (no SwiftUI, no #if), the Kotlin one only ResolvedNode,
JsonValue, JsonObject; outside the suite the full stubs match the old generator for 5 manifests, and the voice
types compile in Swift 5/6 with warnings as errors and in Kotlin with explicitApi and warnings as errors.
Decisions: no schema writes nothing, as TS · `--lang ts` ignores the flag · the Swift types build on Linux too
Review fit: pass · Review quality: the Kotlin import block checked typesOnly in four places, fixed (c9aa4d5)

#### T3 · Pub archive and git ignore native dirs (2a37b78)
Files: plugins/orca_voice_recorder/.pubignore (new) · plugins/orca_voice_recorder/.gitignore (new)
Cases: P-pub → green (`flutter pub publish --dry-run` and `git check-ignore`: red first with dummy files, the
archive listed android/ and ios/; green: CHANGELOG, LICENSE, README, lib/, orca_plugin.yaml, pubspec.yaml; the dry
run's warning and hint as before)
Changed: .pubignore leaves /ios/ and /android/ out and repeats .gitignore's entries; .gitignore ignores .build/,
.swiftpm/, Package.resolved, .gradle/, .kotlin/, local.properties; tracked package files stay tracked.
Decisions: build/ left to the root .gitignore (covers git and pub) · /ios/ and /android/ anchored to the package
Review fit: pass · Review quality: pass

#### T4 · Android Gradle package on SDK toolchain (3c5a5b2)
Files: plugins/orca_voice_recorder/android/settings.gradle.kts · gradle.properties · VERSION · gradlew (a symlink to
../../../sdk-kotlin/gradlew) · voice-recorder/build.gradle.kts (all new)
Cases: P-pkg/K → green (`./gradlew build --continue` on the empty module with sdk-kotlin's :sdk built from source;
explicitApi, warnings as errors, minSdk 24, JVM 17 each shown failing a throwaway file; the staged POM depends on
com.orcagateway:sdk:0.1.0-alpha.1)
Changed: the SDK's catalog and includeBuild("../../../sdk-kotlin"); an Android library com.orcagateway.plugins
.voicerecorder published as com.orcagateway:orca-voice-recorder at VERSION 0.1.0-alpha.1; the sdk as api, Compose
and activity-compose as implementation; the SDK's test set (junit4, robolectric, compose ui-test, coroutines-test).
Decisions: the Gradle project is orca-voice-recorder, so an includeBuild substitutes it with no rule (T14) ·
group, version, staging repo and signing in the module file (no root build file planned) · the sdk as api
Review fit: pass · Review quality: pass

#### T16 · TS string action params take a Value (452ef2c; added at 09)
Files: cli/lib/src/generators/typescript_generator.dart · cli/test/typescript_generator_test.dart (new)
Cases: C17.3/ts → green (cli 38; both new tests red first on `path: string;`; engine 795 unchanged)
Changed: a plain string action param is `Value | string`, as numbers and booleans are `Value | T`; enums, widget
props, objects, arrays and the JSON unchanged; the tests pin one whole inline output and the voice yaml's
`PlayRecording(path: Value | string, ...)`.
Decisions: every plain string param, state-key params included (Flutter resolves strings as values) ·
examples/server/orca_google_map.ts not regenerated
Review fit: pass · Review quality: pass

Why T16 (decision ts-string-action-params-take-values): T1 found that the TS generator typed string action params as
plain `string`, while Flutter resolves them as values (`executor.resolveString`). The /voice page of group 2 must
play the path stopRecording saved in page state; a cast or a hand-built action would bypass the generated classes.
A minor plan change under the standing rule: one S task in group 1, T7 now depends on it, C17.3/ts its case.
Group 2's T7 also gains examples/server/README.md (its plugin-file row), a doc row.

### Test run
Group 1, on feat/native-parity-s17-voice after T1-T4 and T16 (before T2's rework):
`cd cli && dart test` 38 pass · `dart analyze` no issues · `cd engine && bun test` 795 pass, 0 fail ·
`cd sdk && flutter test` 485 pass · `flutter analyze` no issues · `cd sdk-swift && swift build --build-tests &&
swift test` core 523, SwiftUI 433, 0 failures, 0 compiler warnings · `cd sdk-kotlin && ./gradlew build --continue`
core 535, sdk 586, 0 failures · `cd plugins/orca_voice_recorder/android && ./gradlew build --continue` BUILD
SUCCESSFUL (no tests yet) · `bun run schema/gen-widget-registry.ts` and `gen-native-capabilities.ts`: no diff.
After T2's rework (c9aa4d5, kotlin_generator.dart only): `cd cli && dart test` 38 pass · `dart analyze` no issues;
the full and types-only Kotlin output for the voice and google_map yamls identical before and after (`diff -r`).

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing yet (the release rows, the mirror repo and its secret come with group 3)
