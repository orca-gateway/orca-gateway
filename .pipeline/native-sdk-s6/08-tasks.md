# 08 · Tasks · native-sdk-s6

## Front page

### In one breath
S6 starts the Android SDK. 23b.27 is as big as Swift's S1 to S5, so I propose S6 to S10, a PR each.
S6 is the Kotlin core with no Android in it: Gradle, models, resolver, store, executor, caps vector.
Done: every render and action fixture passes in JUnit on ubuntu, as in the Swift core (T6.1, T6.2).
Also in S6's PR: the S5 close commits and the sdk/CHANGELOG 0.3.3 entry (S5 gate 12, question 3).

### New for you
Nothing new.

### Trade-offs
1 needs you: split 23b.27 into S6 core, S7 Compose UI, S8 adapters, S9 degrade and widgets, S10
  Maven Central. Default: yes. Alternative: one PR for all of 23b.27.
2 needs you: the executor joins this core slice (Swift added it in S3), so all pure logic ships and
  tests together on the JVM. Default: yes. Alternative: as Swift, executor in S8.
3 needs you: two artifacts, com.orcagateway:sdk-core (JVM, this slice) and com.orcagateway:sdk
  (Android and Compose, from S7). Default: yes. Alternative: one Android artifact for all.
4 auto-decided (memory, Swift S1): hand-written serializers; seeded property tests, no test library.
5 auto-decided: Kotlin 2.4 (cached here), JVM toolchain 17, JUnit 5, Gradle 9.7.1 wrapper committed.

### Questions for you
1. Epic plan: 23b.27 becomes 23b.27a to 23b.27e, one row per slice? (default: yes, outside the repo)
2. The build fetches the Kotlin plugin and libraries from Maven Central, most cached. (default: ok)
3. S10 publishes under com.orcagateway, verified by a DNS TXT on orcagateway.com. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Where S6 comes from
`.pipeline/native-sdk/08-tasks.md` line 64: 23b.27 "`sdk-kotlin/`: repeat 23b.9 to 23b.24 with Gradle,
kotlinx.serialization, Compose M3; Maven Central publisher; Sonatype steps in `User_Actions.md`", with
"PR 7+ = 23b.27 (S6, likely split per layer)" (line 68). Stage 05: two native cores, Kotlin decodes with
kotlinx.serialization, adapters use OkHttp and NavHost. Stage 07: T6 repeats T1 to T4 in Kotlin, JUnit
on ubuntu for the core, Compose UI tests with Robolectric, the same fixture files.

### Slice plan (trade-off 1)
| Slice | Content (Swift slice it mirrors) | Done when |
|---|---|---|
| S6 core | Gradle build, models, resolver, store, executor, render tree, caps vector, ubuntu CI (S1, plus S3's pure executor) | T6.1, T6.2 green on ubuntu |
| S7 Compose UI | `sdk` Android library: OkHttp `OrcaClient` with the 412 handshake, Compose renderer, the 15 core widgets, `OrcaApp` with NavHost, toast; `examples/app-android` counter on an emulator (S2) | T6.3 green; counter runs on the Pixel 3a API 34 emulator |
| S8 adapters | navigation, system (openUrl, clipboard, share), serverAction POST, DevTools client and its 8 event fixtures; basic-actions and server-actions (S3) | T6.4 green |
| S9 degrade and widgets | FallbackPrompt, the three policies, the 426 page; Icon, Image, Container, Expanded, Spacer, TextField, Stack, Positioned, ClipRRect, GestureDetector; theme hooks (S4) | T6.5 green; capability-demo and native-widgets run |
| S10 publish | `release.sh` `maven` publisher, tag-triggered Central Portal workflow, docs-site page, README, epic rows (S5) | `com.orcagateway:sdk:0.1.0-alpha.1` resolves from a clean Gradle project |

### Tasks for S6
| # | Task | Acceptance criteria |
|---|------|---------------------|
| S6.1 | `sdk-kotlin/` Gradle build: `settings.gradle.kts`, the Gradle 9.7.1 wrapper, version catalog, module `core` (Kotlin/JVM, toolchain 17, kotlinx.serialization plugin), `VERSION` (`0.1.0-alpha.1`), `capabilities.json` (no widgets yet; the executor's 15 action kinds), README with the experimental banner, LICENSE (the BSL 1.1 copy). | `./gradlew :core:build` passes on macOS and ubuntu with no warnings. |
| S6.2 | Models: `JsonValue`, `ComponentNode`, `Value` (9 kinds), `Action` (all 28 kinds plus `custom:*` and unknown kinds kept verbatim, as Swift does), `PageResponse`; hand-written kotlinx.serialization serializers. | T6.1.1: the 24 render fixtures decode and re-encode JSON-equal; a seeded generator checks decode(encode(n)) == n. |
| S6.3 | `ValueResolver`: 9 Value kinds, 31 transforms, 13 BoolExpr ops with the Dart null semantics, and Dart's number and date formatting (Swift's `DartFormat`). | T6.1.2: every fixture's `resolved` map. T6.1.3: the transform table and its properties. T6.1.4: the BoolExpr cases Swift ported from the Dart tests. |
| S6.4 | `ElmStore`: page and app scopes, nested keys, notifications scoped to watched keys, plain listeners (no coroutines in `core`). | T6.1.5: a change notifies only subscribers of that key; app state outlives a page. |
| S6.5 | Executor: `ActionReducer` and `ActionExecutor` for the 15 kinds Swift runs, effects as data, `URLPolicy`, the render tree and `ComponentMutation` (add, update, delete). | T6.2: all 15 `schema/fixtures/actions` cases pass, state and effects; the mutation cases Swift's tests cover. |
| S6.6 | `schema/gen-native-capabilities.ts` also emits `sdk-kotlin/core/.../Generated.kt` from `sdk-kotlin/capabilities.json` and `sdk-kotlin/VERSION`, checking each widget's `android` target; `schema.yml` diffs it like the Swift file. | T6.1.6: the generated vector matches the manifest; the hash equals the engine's canonical hash for the same vector. |
| S6.7 | Taskfile `sdk-kotlin:test`; `.github/workflows/sdk-kotlin.yml` on ubuntu (JDK 17 and 21) for PRs touching `sdk-kotlin/` or `schema/`; `sdk/CHANGELOG.md` gains the missing 0.3.3 entry (S3's DevTools builders, S4's 426 page). | `t sdk-kotlin:test` passes; the workflow runs on the S6 PR. |

### Memory matched
- swift-models-source (S1 gate 08): hand-written Codable, generated decoders later → trade-off 4.
- swift-property-test-lib (S1 gate 08): a seeded generator in the tests, no dependency → trade-off 4.
- s2-executor-scope (S2 gate 08): actions pulled forward from the executor slice when a slice needed
  them → the same direction as trade-off 2, taken further: the whole pure executor moves forward.

### Tests (T6 group)
T6.1 is T1 in Kotlin (T6.1.1 to T6.1.6 above). T6.2 is T3.1 in Kotlin. Swift's core runs 111 tests
in 16 files; S6 ports the 9 files that are pure logic: model round trip, properties, resolver fixtures,
transforms, BoolExpr, store, capabilities, action fixtures and executor, render tree and mutations.
T6.3 to T6.5 belong to S7 to S9.

### CI
New: `sdk-kotlin.yml` (ubuntu, JDK 17 and 21, Gradle cache). `schema.yml` gains the diff of
`Generated.kt`. Nothing else changes; no Android SDK is needed until S7.

### Wire format
Unchanged. S6 reads the existing schema, fixtures and manifest. Generated.kt is a codegen output that
`schema.yml` checks, as Generated.swift is.

### Findings while planning
F1 This Mac has JDK 21 (JetBrains), 25, 18 and 11; the Android SDK with platforms 28 to 36, build-tools
   to 36.0.0, emulator 37.2, and AVDs `Pixel_3a_API_34_extension_level_7_arm64-v8a` and
   `Pixel_9_Pro_XL`. No global `gradle`; the wrapper cache holds 8.9 to 9.7.1.
F2 The Gradle cache already holds Kotlin 2.2.20 to 2.4.0, Compose (ui, material3, foundation), OkHttp,
   kotlinx.serialization and `com.vanniktech.maven.publish`. Robolectric is not cached (S7).
F3 `widget-registry.json` gives every widget the `android` target by default, so Android has no
   orphans; the Kotlin caps vector still lists only what the SDK draws, as Swift's does.
F4 `engine/src/types/platform.ts` already knows `android`; the engine needs no change for S6.
F5 `User_Actions.md` already holds the Sonatype and GPG steps "complete before S6 (23b.27)"; they are
   needed only at S10 (question 3).

### Commits on feat/native-sdk-s6 (conventional)
1. chore(pipeline): native-sdk-s5 gate 10, 11 skipped, stage 12 (done, from S5)
2. chore(pipeline): native-sdk-s5 closed (done, from S5)
3. chore(pipeline): native-sdk-s6 stage 08
4. build(sdk-kotlin): Gradle build and core module skeleton (S6.1)
5. feat(sdk-kotlin): models and serializers (S6.2)
6. feat(sdk-kotlin): value resolver, transforms, BoolExpr (S6.3)
7. feat(sdk-kotlin): ElmStore (S6.4)
8. feat(sdk-kotlin): action executor and render tree (S6.5)
9. feat(schema): Kotlin capability vector (S6.6)
10. ci(sdk-kotlin): Taskfile task and ubuntu workflow; docs(sdk): CHANGELOG 0.3.3 (S6.7)
11. chore(pipeline): stage 09 onward

### Not in S6
Anything Android: the `sdk` module, Compose, OkHttp, the example app, Robolectric (S7 onward). DevTools
events (S8). Publishing (S10).
