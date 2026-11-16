# 09 · Implementation · native-parity-s17-voice

## Front page

### In one breath
group 2 of 4 · tasks: 3 green, 0 blocked · cases: 9 of 18 green · engine bun test: 800 pass
T5 Swift package: OrcaVoiceRecorder on sdk-swift by path here, the mirror once split out.
T6 Kotlin types: the generated props, params and triggers compile under the SDK's strict flags.
T7 Demo page: /voice records, stops into page state and plays the saved path.
Both drift tests regenerate the types and fail on any byte that differs from the yaml's.

### New for you
nothing new

### Trade-offs
2 auto-decided: keep T5's manifest test · examples/server typing left as the map's (follow-up)

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 3 (both recorders, release.sh, mirror and Maven CI)? (default: go)

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

### Group 2
#### T5 · SwiftPM package with generated props types (ff5c782, 37732f5 rework)
Files: plugins/orca_voice_recorder/ios/Package.swift · VERSION · Sources/OrcaVoiceRecorder/Generated/
OrcaVoiceRecorderTypes.swift · Tests/OrcaVoiceRecorderTests/VoiceRecorderPropsTests.swift (all new) ·
cli/test/voice_recorder_swift_props_test.dart (new)
Cases: P-pkg/S, C17.5/S → green (swift test 6, 0 warnings from a clean build; xcodebuild build and test on the
iOS 18.5 simulator, 5 there: the manifest test is macOS only; cli 40; red first: no Package.swift, an empty target,
"No types at …")
Changed: tools 5.9, iOS 16 / macOS 13 as the SDK; package, product and module OrcaVoiceRecorder; the SDK dependency
chosen from `Context.packageDirectory`: ../../../sdk-swift by path in the monorepo, else orca-gateway-swift
from 0.1.0-alpha.2 (the first release that can carry the step 16 plugin API; the header says sdk-swift goes first);
VERSION 0.1.0-alpha.1; the types file is the CLI's --types-only output; the tests pin the props, the three
trigger names and the nine actions' params; the drift test regenerates and names the command on a difference.
Decisions: a `swift package dump-package` test of both manifest branches, kept (auto-decided, minor: the only check
of the mirror branch before a release) · the test target lists OrcaGateway explicitly · a Value-typed `path`
reads nil from the params type, so T8 resolves path, recorderId and position from the raw action, as Flutter
Review fit: pass · Review quality: the manifest test read SwiftPM's internal URL encoding (remote[0].urlString), fixed (37732f5)

#### T6 · Kotlin generated props, params, drift test (e6f410f)
Files: plugins/orca_voice_recorder/android/voice-recorder/src/main/kotlin/com/orcagateway/plugins/voicerecorder/
OrcaVoiceRecorderTypes.kt (new) · the same path under src/test/: VoiceRecorderPropsTest.kt (new) ·
cli/test/voice_recorder_kotlin_props_test.dart (new)
Cases: C17.5/K → green (the plugin's Gradle build, VoiceRecorderPropsTest 7/7; the drift test 1/1; red first:
"Unresolved reference 'VoiceRecorderProps'", "No types at …")
Changed: the types file is the generator's output, unedited, and compiles under explicitApi and warnings as errors
(no generator fix); the test pins exactly recorderId and showAmplitude, absent props null, Flutter's three
triggers, the nine actions' param names and types; the drift test runs --types-only --package
com.orcagateway.plugins.voicerecorder in a temp dir and compares the one file written byte for byte.
Decisions: "exactly" by plain Java reflection (no kotlin-reflect) · plain JUnit (no Android API) · raw actions as
"custom:<name>", as sdk-kotlin's GeneratedPluginTest
Review fit: pass · Review quality: pass

#### T7 · Demo /voice page in custom app (1d541d4)
Files: examples/server/orca_voice_recorder.ts (new) · examples/server/custom.ts · examples/server/README.md ·
engine/test/voice-demo.test.ts (new)
Cases: C17.3/page → green (5 new tests, red first: /voice 404, no button; engine 800 = 795 + 5)
Changed: the CLI's TS output for the yaml with its two imports pointed at ../../engine/src/types (the header says
so and how to regenerate); home gains "Go to Voice Page"; /voice holds a VoiceRecorder (recorderId "demo"), Start,
Stop (pathKey voicePath, durationKey voiceDuration) and Play (`V.pageState("voicePath")`) from the generated
classes, and Texts of both keys; the test renders /voice and /home through the engine and pins the node, the
actions' params, the Texts' watches and the buttons.
Decisions: the home button copies the map's `Custom("navigate", { path })` · pathKey/durationKey plain strings
(Flutter reads them `as String?`) · examples/server is outside the engine's tsconfig; its tsc errors (11 → 24) are
of two kinds already there (`Custom("<name>")` vs `custom:${string}`, generated actions vs CustomAction): left
as orca_google_map.ts is, a follow-up (auto-decided, minor; decision ts-generated-actions-vs-custom-type)
Review fit: pass · Review quality: pass

### Test run
Group 1, on feat/native-parity-s17-voice after T1-T4 and T16 (before T2's rework):
`cd cli && dart test` 38 pass · `dart analyze` no issues · `cd engine && bun test` 795 pass, 0 fail ·
`cd sdk && flutter test` 485 pass · `flutter analyze` no issues · `cd sdk-swift && swift build --build-tests &&
swift test` core 523, SwiftUI 433, 0 failures, 0 compiler warnings · `cd sdk-kotlin && ./gradlew build --continue`
core 535, sdk 586, 0 failures · `cd plugins/orca_voice_recorder/android && ./gradlew build --continue` BUILD
SUCCESSFUL (no tests yet) · `bun run schema/gen-widget-registry.ts` and `gen-native-capabilities.ts`: no diff.
After T2's rework (c9aa4d5, kotlin_generator.dart only): `cd cli && dart test` 38 pass · `dart analyze` no issues;
the full and types-only Kotlin output for the voice and google_map yamls identical before and after (`diff -r`).

Group 2, after T5-T7: `cd cli && dart test` 40 pass · `dart analyze` no issues · `cd engine && bun test` 800 pass,
0 fail · `cd sdk && flutter test` 485 pass · `flutter analyze` no issues · sdk-swift core 523, SwiftUI 433, 0
failures, 0 compiler warnings · sdk-kotlin core 535, sdk 586 · `cd plugins/orca_voice_recorder/ios && swift build
--build-tests && swift test` 6 pass, 0 warnings · `xcodebuild test -scheme OrcaVoiceRecorder` on the iOS 18.5
simulator 5 pass, TEST SUCCEEDED · `cd plugins/orca_voice_recorder/android && ./gradlew build --continue` 7 pass ·
the generators leave no diff.
After T5's rework (37732f5, the test file only): the Swift package's swift test 6 pass, 0 warnings.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing yet (the release rows, the mirror repo and its secret come with group 3)
