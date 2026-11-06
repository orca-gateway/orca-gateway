# 09 · Implementation · native-sdk-s6

## Front page

### In one breath
S6 is built on feat/native-sdk-s6: 5 code commits after the S5 close commits; nothing pushed.
sdk-kotlin/core ports Swift's pure core to Kotlin: models, resolver, store, executor, render tree.
82 JUnit tests pass on JDK 21 and 25; every render and action fixture is green (T6.1, T6.2).
Against the compiled Swift core, 147,000 random cases agree but 13, each explained in the appendix.
Also in: the Kotlin caps vector (the engine's hash), CI on JDK 17 and 21, sdk 0.3.3's changelog.

### New for you
Nothing new.

### Trade-offs
1 auto-decided: parallel action groups run on stdlib coroutines; no kotlinx.coroutines dependency.
  Effects inside one group may come in another order than on iOS; the state and effect set match.
2 auto-decided: where Swift departs from Dart (6 corners, appendix), Kotlin copies Swift.
3 auto-decided: Java 17 bytecode built by JDK 21 or 25 here (no JDK 17 on this Mac); CI runs 17.
4 auto-decided: one port commit, not the four planned: state and render need each other to build.

### Questions for you
1. Swift and Kotlin both differ from Dart in 6 corners, e.g. contains("") is false, 4.0 prints 4.
   Fix both SDKs to Dart, a fixture per corner, in a later slice? (default: yes, after S10)
2. Push and open the S6 PR at stage 10? It carries the S5 close commits too. (default: yes)
3. After merge: S7, the Compose UI, on the Pixel 3a emulator. (default: when you say go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Tasks, status and evidence
| # | Status | Evidence |
|---|---|---|
| S6.1 | done | `sdk-kotlin/`: Gradle 9.7.1 wrapper, version catalog (Kotlin 2.4.0, kotlinx.serialization 1.12.0), module `core` (Kotlin/JVM, `explicitApi()`, warnings as errors, Java 17 bytecode through `jvmTarget` 17 and `-Xjdk-release=17`), `VERSION` `0.1.0-alpha.1`, `capabilities.json` (no widgets, the 15 action kinds Swift advertises), README with the experimental banner, LICENSE. Commit b290ff3 |
| S6.2 | done | `json/` `JsonValue`; `models/` `ComponentNode`, `PageResponse`, `Value` (9 kinds), `BoolExpr` (13 ops), `Action` (28 kinds, `custom:*` and unknown kinds kept verbatim), hand-written `KSerializer`s over `JsonElement` (`Wire.kt`). T6.1.1: ModelRoundTripTest 6 (the 24 render fixtures decode and re-encode JSON-equal) and PropertyTest 10 (a seeded SplitMix64 generator, decode(encode(x)) == x). Commit 2d5f7de |
| S6.3 | done | `resolver/` `ValueResolver` and the 31 transforms with Dart's null rules; `json/DartFormat` (Dart's number and date text); `json/SwiftText` (Swift's string rules). T6.1.2 ResolverFixtureTest 2 (every fixture's `resolved` map); T6.1.3 TransformTest 6; T6.1.4 BoolExprTest 10. Commit 2d5f7de |
| S6.4 | done | `state/ElmStore`: page and app scopes, dotted keys, notifications only to subscribers whose watched values changed, plain listeners, `subscribe` returns an `AutoCloseable`. T6.1.5 ElmStoreTest 9. Commit 2d5f7de |
| S6.5 | done | `state/ActionReducer`, `state/ActionExecutor` (the 15 advertised kinds plus the server-only `replaceComponent`, effects as data through `onEffect`, platform work through `perform`), `state/UrlPolicy`, `render/PageRenderer` and `render/ComponentMutation`; `client/ActionClient` is the one call serverAction needs (S7's OkHttp client implements it). T6.2: ActionFixtureTest 4 (all 15 action fixtures, state and effects), ActionExecutorTest 11, RenderTreeTest 8, ComponentMutationTest 8. Commit 2d5f7de |
| S6.6 | done | `gen-native-capabilities.ts` emits `Generated.kt` from `sdk-kotlin/capabilities.json` and `VERSION`, checking each widget's `android` target; Swift's output is byte-identical. `schema.yml` diffs it. T6.1.6: CapabilitiesTest 7, the hash equals `capsHash`, and Swift's kinds assertions (the listed kinds are wire kinds; the executor runs them plus `replaceComponent`; value kinds and BoolExpr ops equal the models'). Commit 37a7de8 |
| S6.7 | done | Taskfile `sdk-kotlin:test`, `sdk-kotlin:build`, `sdk-kotlin:gen`; `.github/workflows/sdk-kotlin.yml` (ubuntu, Temurin 17 and 21, `gradle/actions/setup-gradle@v4` for the cache and wrapper check, `./gradlew :core:build`, test reports uploaded on failure). `sdk/CHANGELOG.md` 0.3.3: the DevTools FallbackPrompt warning and builders, the 426 page from `fetchPage`, the Scaffold fit under the warn banner. Commits f42782b, 827cb6a |

### Test results
| Where | Result |
|---|---|
| `t sdk-kotlin:build` (JDK 25) | 82 tests, 0 failures, 0 skipped, no warnings |
| `./gradlew :core:build --rerun-tasks --no-build-cache` (JDK 21) | green in 20 s; classes are major version 61 (Java 17) |
| Per file, Swift vs Kotlin | round trip 6/6, properties 10/10, resolver fixtures 2/2, transforms 6/6, BoolExpr 10/10, store 9/9, action fixtures 4/4, executor 11/11, render tree 8/8, mutations 8/8 |
| `bun run schema/codegen.ts`, `gen-native-capabilities.ts`, `gen-widget-registry.ts` | no drift |
| Workflow YAML and Taskfile | parse (Bun's YAML; no actionlint here) |

Left out on purpose: in ActionExecutorTest's server-action test, the HTTP method, URL, content type
and `x-orca-caps-hash` and `x-orca-platform` header assertions belong to `OrcaClient` (S7). A
comment says so; the request body and single-call assertions stay.

### Kotlin against the compiled Swift core (the 147,000 cases)
A throwaway harness compiled Swift's core with `swiftc` and fed both cores the same random inputs
(in the session scratchpad, `diff/`). I compared the saved outputs:
- DartFormat, 12,011 doubles: identical.
- Resolver, 80,000 random Value, Transform and BoolExpr expressions: identical.
- Model decoding, 40,000 Action, Value and ComponentNode cases with wrong types mixed in: identical
  (29,251 fail to decode in both).
- Action sequences through ElmStore and ActionExecutor, 15,000: 13 differ. 9 differ only in the
  order of effects inside a `parallel` group (trade-off 1). 4 hit a number corner:
  `-9223372036854775808.0` decodes as a Long in Kotlin and a Double in Swift.

### Deliberate Kotlin differences from Swift
- API shape: sealed classes and data classes for enums; 64-bit numbers are `Long`; serializers work
  with kotlinx `Json` only; `subscribe` returns an `AutoCloseable` (no `deinit` on the JVM).
- `async` becomes `suspend` (stdlib only). A cancelled lifecycle rethrows and skips onError and
  onComplete; Swift runs onError on cancellation.
- Server actions: `ActionClient.executeAction` and `OrcaActionException(status, message)` stand in
  for `OrcaClient` and `OrcaClientError.action`; the snackbar on refusal is the same.
- DevTools reporting is left out with a comment at each spot (S8).
- `WidgetRegistry` defaults to `GeneratedCapabilities.widgets`, empty until S7, so tests build a
  registry from the manifest.
- URLs use `java.net.URI` (stricter than Foundation's `URL`); regex uses `java.util.regex` with
  Unicode classes where the platform has them; dates use `GregorianCalendar` in UTC like Foundation.
- `12345678901234567.5` rounds to ...568 in Kotlin and ...567 in Swift.

### Swift against Dart (question 1)
Kotlin follows Swift, so both native SDKs differ from Flutter here; no fixture covers these:
1. `contains("")` is false (Dart: true).
2. `contains`, `startsWith`, `eq` and `split("")` compare whole characters with canonical
   equivalence (Dart: UTF-16 code units).
3. An empty regex pattern is rejected (Dart accepts it).
4. Regex `\d` and `\w` match Unicode digits and letters (Dart: ASCII only).
5. A JSON `4.0` reads as an int, so `toString` gives "4" where Dart gives "4.0".
6. `lowercase` skips the final-sigma rule (Dart applies it).
Also seen in Swift only: a NaN inside a typed model becomes null silently through `try?`, and a
cancelled lifecycle runs onError (Kotlin rethrows; Dart futures cannot be cancelled).

### Findings worth remembering
- F1 No JDK 17 on this Mac; the bytecode target does the job without a toolchain download, and CI
  runs JDK 17 itself.
- F2 `state` and `render` import each other, so the core lands as one commit, not the four 08
  planned.
- F3 The port was done by a subagent from the Swift sources and tests, then reviewed here: the
  executor, store, client interface and CapabilitiesTest read in full, the counts and builds rerun,
  and the differential outputs compared again.

### For ship (stage 10) to know
Nothing deploys and nothing is published: sdk-kotlin joins `release.sh` only in S10. Push the
branch and open the PR. CI on the PR: SDK Kotlin (new; JDK 17 and 21), Schema (Generated.kt
drift), SDK Swift and SDK Swift UI (the PR touches `schema/`), SDK (`sdk/CHANGELOG.md`), Engine
if its paths match. The branch also carries the S5 close commits 7402b4c and 90aee26.
