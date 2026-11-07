# 09 · Implementation · native-sdk-s10

## Front page

### In one breath
group 2 of 3 · tasks: 2 green, 0 blocked · cases: 12 of 14 green · core 113, sdk 127, lint 0
S10.2 release.sh: sdk-kotlin is package 10; it checks JDK 17+ and an Android SDK before any bump.
S10.4 CI: a scratch app takes com.orcagateway only from the staged publication, runs and builds.
release.sh rehearsed in throwaway clones (local origin only): keep, next, a failed build, order.
Gradle fetched 10 old androidx jars from Google's Maven for the scratch app (cache, no install).
The scratch app found a gap in the SDK's compose dependencies (question 2). Nothing pushed.

### New for you
nothing new

### Trade-offs
1 needs you: compose as `api` in sdk (apps get it) vs `implementation` (apps add the BOM).
6 auto-decided: one codegen run, AGP's SDK lookup, JDK 17 leg only, `bash` in CI (memory), 2 more.

### Questions for you
1. Next: group 3: S10.5 the Maven Central workflow on the tag, S10.6 the release docs (me)?
   (default: go)
2. OrcaApp's `modifier` and OrcaTheme's Shape, Color, BorderStroke, PaddingValues are compose
   types, but sdk publishes compose as `implementation`: an app with only activity-compose compiles
   against compose ui 1.0.1. Make compose ui and foundation `api` (BOM too) as S10.1b in group 3?
   (default: yes)

## Appendix

### Group 1
Commits, one per task: S10.1 67a3191, S10.3 6b50b14. Nothing pushed.

#### Task S10.1 · Publish both artifacts
Files: `sdk-kotlin/gradle/libs.versions.toml`, `sdk-kotlin/build.gradle.kts`,
`sdk-kotlin/core/build.gradle.kts`, `sdk-kotlin/sdk/build.gradle.kts`, `sdk-kotlin/gradle.properties`
Cases: M6, M7, M8, M15 → green · red first: `publishAllPublicationsToStagingRepository` "not found"
· baseline unchanged (core 113, sdk 127, lint 0; the example's assembleDebug builds the SDK from source).
Changed: com.vanniktech.maven.publish 0.33.0; core → `com.orcagateway:sdk-core` (KotlinJvm, sources,
empty javadoc), sdk → `com.orcagateway:sdk` (release variant, sources, an empty javadoc jar), sdk's
POM and .module depend on sdk-core; POM url, BSL 1.1, scm, developer orca-gateway; Central with
automatic release; a `staging` repo, `./gradlew publishAllPublicationsToStagingRepository` →
`sdk-kotlin/build/staging-repo`. M8: a throwaway BouncyCastle key (no gpg here), all 10 signatures
verified, a tampered POM failed; no key, 0 `.asc`. Key passed as the private block only, never printed.
Decisions: an empty Jar for sdk's javadoc (AGP's needs Dokka, not cached); POM and Central mode in
gradle.properties; signAllPublications() only when `signingInMemoryKey` is set.
Review fit: pass
Review quality: pass

#### Task S10.3 · Alpha banner, install section, READMEs
Files: `sdk-kotlin/README.md`, `README.md`, `examples/app-android/README.md`
Cases: M13 → done · red first: none (docs); every claim checked against a file (API in the snippet,
minSdk 24, coordinates, the composite build, 25 widgets); the release, tag and workflow names come
from the 08 plan and land in S10.2 and S10.5.
Changed: alpha banner; Install (google(), mavenCentral(), `com.orcagateway:sdk:0.1.0-alpha.1`,
minSdk 24, Compose, `setContent { OrcaApp(client, path = "home") }`, sdk-core for the JVM); S9 done,
S10 this package; Versioning via release.sh and the tag workflow; root README lists `sdk-kotlin/`;
the example README: alpha on Maven Central, the example still builds from source.
Decisions: the root README's intro still names only Flutter (Swift's alpha is missing there too);
the snippet is OrcaApp's minimal form from its KDoc.
Review fit: pass
Review quality: the Versioning section repeated release.sh's prompt (a third copy; Swift's README
has none), fixed: the sentence ends at "never by hand." (a fresh implementer; quality pass)

### Group 2
Started on "A" at gate 09 group 1 (2026-11-07); its question 2 ("yes") gave S10.4 the
`settings.gradle.kts` header and the README Tests line. Commits, one per task: S10.2 a9d349e,
S10.4 6d26eba. Nothing pushed.

#### Task S10.2 · release.sh `maven` publisher for sdk-kotlin
Files: `scripts/release.sh`
Cases: M1-M5 → green · red first: the old script lists 1-9 and rejects `10` ("index out of range:
10") · baseline unchanged (the clone's build: core 113, sdk 127, lint 0; shellcheck: only its 3 old
SC2005 notes; `/bin/bash -n` on bash 3.2). Throwaway clones pushing only to a local bare origin.
M1 `10) sdk-kotlin 0.1.0-alpha.1 (maven)`, 1-9 unchanged. M2 Return/n/r/P → alpha.1 (keep), alpha.2,
0.1.0, 0.1.1; with the tag, `k` refused ("already tagged; pick n, r, M, m or P"). M3 n: only VERSION
and Generated.kt in the commit (alpha.2), Generated.swift no diff, staging repo at alpha.2; a broken
OrcaCore.kt: ":core:compileKotlin FAILED … file changes reverted", tree clean. M4 no SDK, a missing
SDK dir, a real JDK 11 (JAVA_HOME and PATH), no java: each stops at "Checking logins...". M5 keep:
"nothing to commit … tagging HEAD", tag on the origin; order engine, sdk, sdk-swift, sdk-kotlin, devtools.
Decisions: one codegen run listing both native files; AGP's SDK lookup order; `10)` keeps `%d)`.
Review fit: pass
Review quality: pass

#### Task S10.4 · Scratch consumer script, PR CI step
Files: `scripts/maven-verify.sh` (new, 100755), `.github/workflows/sdk-kotlin.yml`,
`sdk-kotlin/settings.gradle.kts` (header), `sdk-kotlin/README.md` (Tests line)
Cases: M9, M10 → green · red first: an empty repo dir and version 0.0.0 both fail "Could not find
com.orcagateway:sdk-core:<v>. Searched in … file:<repo>/…", one location only (exclusiveContent
holds) · baseline unchanged. Green: the CI step's exact command (GITHUB_WORKSPACE = the worktree)
after the staging publish: `sdkSemver 0.1.0-alpha.1`, `:android:assembleDebug` BUILD SUCCESSFUL,
"PASS maven-verify: …". YAML parses (ruby). Not exercised: a jar whose sdkSemver differs.
Changed: a scratch project in mktemp (removed on exit), com.orcagateway only from <repo>, the SDK's
catalog, sdk-kotlin/gradlew; `jvm` prints `CapabilityVector.current.sdkSemver`; `android` is the
README's install example; CI's JDK 17 leg stages, then runs it; header "an alpha published on Maven Central".
Decisions: JDK 17 leg only; the run-time read (the const would be inlined); `bash scripts/maven-verify.sh`
(memory "mirror-script-shared"); needs you: compose deps (question 2).
Review fit: pass
Review quality: the CI step ran the script without `bash` (needs the executable bit; Swift's mirror
uses `bash scripts/swift-mirror.sh`), fixed: `bash scripts/maven-verify.sh …` (a fresh implementer; quality pass)

#### The compose question (question 2)
`sdk/build.gradle.kts` declares the compose BOM, ui, foundation and material3 as `implementation`, so
the published POM/.module list them runtime-only. But the public API uses compose types: `OrcaApp(…,
modifier: Modifier)`, and `OrcaButtonStyle` holds `Shape`, `Color` (ui-graphics), `BorderStroke`,
`PaddingValues` (foundation); `LocalOrcaTheme` is a runtime `CompositionLocal`. An app that follows the
README (sdk plus activity-compose, no BOM) compiles against whatever activity-compose 1.10.1 pulls in
(compose ui 1.0.1, runtime 1.7.0); it assembles, but the app sees old compose APIs at compile time.
Yes: `api(platform(libs.compose.bom))`, `api(libs.compose.ui)`, `api(libs.compose.foundation)` in S10.1's
file, as task S10.1b in group 3 (maven-verify.sh then proves the README path gets current compose).
No: leave it; the README tells apps to add the compose BOM themselves.

#### Downloads (S10.4's green run)
For the scratch app's compile classpath (decision above), Gradle fetched from Google's Maven into
~/.gradle: compose ui-geometry, ui-graphics, ui-text, ui-unit 1.0.1; runtime-android and
runtime-saveable-android 1.7.0; annotation-experimental 1.4.0; lifecycle-runtime-ktx and
lifecycle-viewmodel-ktx 2.6.2; savedstate-ktx 1.2.1. Libraries only; nothing installed or run.

### Test run
Group 1: `cd sdk-kotlin && ./gradlew build publishAllPublicationsToStagingRepository --console=plain
--rerun-tasks`: BUILD SUCCESSFUL; core 113, sdk 127, 0 failures, 0 skipped; lint "No issues found";
staging repo: sdk-core jar and sdk aar, each with -sources, -javadoc, .pom, .module and checksums.
Every changed file sits in its task's `Files`.
Group 2: `cd sdk-kotlin && ./gradlew build --console=plain`: BUILD SUCCESSFUL (82 of 83 tasks up to
date after the implementers' own builds; group 2 changed no build input but a settings comment);
core 113, sdk 127, 0 failures; lint "No issues found". `git status`: release.sh (S10.2); maven-verify.sh,
sdk-kotlin.yml, settings.gradle.kts, README.md (S10.4); nothing else.

### Blocked
none

### Not done
none. Group 1's two unowned lines (the settings header, the README Tests line) went to S10.4 on
question 2's "yes".

### For ship (stage 10) to know
The build now applies com.vanniktech.maven.publish 0.33.0 (from the Gradle cache; CI downloads it
from the Gradle Plugin Portal). `./gradlew publishAllPublicationsToStagingRepository` writes
`sdk-kotlin/build/staging-repo`. The Central tasks `publishAndReleaseToMavenCentral` and
`publishToMavenCentral` read `mavenCentralUsername`/`mavenCentralPassword` and the in-memory signing
properties (S10.5 maps the four secrets to them).
Group 2: release.sh's option 10 needs a JDK 17+ and an Android SDK on the releasing machine
(`ANDROID_HOME` or `sdk-kotlin/local.properties`); its validation is a full Gradle build (minutes).
Its tag push names `.github/workflows/sdk-kotlin-publish.yml` (S10.5); until that lands, a
sdk-kotlin tag starts nothing. SDK Kotlin CI's JDK 17 leg now also stages the publication and runs
`bash scripts/maven-verify.sh` (about a minute more). The workspace CLAUDE.md release section
("numbered 1-9", no sdk-kotlin row) is S10.6's.
