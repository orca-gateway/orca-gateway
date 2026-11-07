# 09 · Implementation · native-sdk-s10

## Front page

### In one breath
group 3 of 3 · tasks: 3 green, 0 blocked · cases: 15 of 15 green · core 113, sdk 127, lint 0
S10.5 CI: "SDK Kotlin Publish" signs and releases both on the tag, then checks them on Central.
S10.1b SDK: compose, OkHttp, coroutines are `api`; README apps get compose ui 1.11.2, not 1.0.1.
S10.6 docs: User_Actions Maven steps plus a first-release Step 6, CLAUDE.md's row 10, a page.
Signing rehearsed with a throwaway key: 10 of 10 signatures verified. Nothing published or pushed.
S10.6 took two fixes after review (one past the one-rework rule; both one-line doc fixes).

### New for you
nothing new

### Trade-offs
5 auto-decided: OkHttp and coroutines `api` (your rule), poll timing (memory), 3 small ones.

### Questions for you
1. Last group: `A` approves stage 09; stage 10 then pushes feat/native-sdk-s10, opens the PR
   (Auto-fix off) and reads its CI once. (default: yes)
2. Copy the Android docs page into your checkout (I can't write there; command in the appendix).
   (default: you copy it)
3. Read the docs I changed outside the repo: User_Actions "Maven Central publishing" Steps 1-6,
   CLAUDE.md's release section. (default: ok)

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

### Group 3
Started on "A" at gate 09 group 2 (2026-11-07): question 1 "go", question 2 "yes" added S10.1b
(the rule recorded with it: types in a library's public API are api dependencies). Commits, one per
code task: S10.1b 830927a, S10.5 52097b2. S10.6 changes no repo file (three workspace files and a
gitignored page). Nothing pushed.

#### Task S10.5 · Tag-triggered Central Portal publish workflow
Files: `.github/workflows/sdk-kotlin-publish.yml` (new)
Cases: M11 → green (each run block rehearsed as bash) · red first: release.sh names the workflow,
which did not exist · baseline unchanged (a clone's build: core 113, sdk 127, lint 0) · YAML parses.
Changed: "SDK Kotlin Publish" on an `sdk-kotlin-v*` tag or by hand with a tag; job `publish`: tag
format, checkout of the tag, VERSION == X, the four secrets (missing ones named), HEAD on repo1 for
both POMs (both there: upload skipped; one: "a half release" error), JDK 17, only the PRIVATE KEY
BLOCK of SIGNING_KEY exported inside the step, `publishAndReleaseToMavenCentral`; job `verify`: a
fresh runner polls repo1 (60 s, up to 45 min), then `bash scripts/maven-verify.sh <repo1> X` (M12).
Rehearsals: good, bad-format and mismatched tags; 0, 2 and 4 secrets set; okhttp as a stand-in for
"already there"; a throwaway .asc (public block first): 10 artifacts, 10 .asc, "verified=10 bad=0";
a public-only key → "SIGNING_KEY holds no PRIVATE KEY BLOCK"; no key text or password in any log.
Decisions: verify checks out the tag, sparse; poll timing as step env (memory "mirror-script-shared").
Review fit: pass
Review quality: pass

#### Task S10.1b · The SDK's public API dependencies as `api`
Files: `sdk-kotlin/sdk/build.gradle.kts`
Cases: M16 (new: an app on the README's path compiles against the SDK's compose) → green · red
first: the staged POM had ui, foundation, okhttp, coroutines-android as `runtime`; the scratch app's
compile classpath took `compose.ui:ui:1.0.1` through activity-compose 1.10.1 · baseline unchanged.
Audit of the public API (javap, then Kotlin visibility): `api` = compose BOM, ui (`Modifier`,
`Color`, `Shape`), foundation (`BorderStroke`, `PaddingValues`), okhttp (`OkHttpTransport(OkHttpClient)`),
coroutines-android (`OrcaPageModel.fire` returns `Job?`); `implementation` = material3, icons,
activity-compose, navigation-compose (only internal or private uses). Green: the POM imports the BOM
and lists those in `compile`; the scratch app gets ui 1.11.2 by the BOM; maven-verify PASS; the
example app assembles. Downloads: 2 kotlin-stdlib-common metadata files (~2.4 KB).
Decisions: okhttp and coroutines by your rule (memory "sdk-compose-api-deps"); compose runtime comes
through ui's api.
Review fit: pass
Review quality: pass

#### Task S10.6 · Release docs (main session, outside the repo)
Files: `/Users/amrebada/workspace/orca-gateway/docs/User_Actions.md`, `…/CLAUDE.md`,
`…/.claude/plans/orcagateway-epics.md`, `docs-site/docs/guides/android-sdk.mdx` (new, gitignored)
Cases: M14 → done. User_Actions "Maven Central publishing": both packages and the workflow named,
"before the first Android SDK release (slice S10, task 23b.27e)"; any sign-in method, DNS verifies
(F1); the .asc's two blocks, kept (F2); the secrets page link and a copy hint; Step 6: JAVA_HOME and
ANDROID_HOME, `bash scripts/release.sh`, 10, Return, y, watch "SDK Kotlin Publish", what failure
means. CLAUDE.md: row 10, "1-10", the pre-bump checks, the Gradle validation, the push order, a
pre-req bullet (F10). Epic row 23b.27e: "S10: built, PR next" (stage 10 puts the PR link there).
Page "Android SDK (alpha)" (sidebar 8), as the iOS page. Backups in the session scratchpad.
Review fit: (1) Step 6 said Android Studio gives a Java release.sh finds (it doesn't), fixed: export
JAVA_HOME to its `jbr` (checked here: Java 25.0.4); (2) `pbcopy < orca-release-key.asc` had no
folder, fixed: Step 3 saves it in the home folder, Step 5 reads `~/orca-release-key.asc`. Two fixes
by the main session (a docs task), the second past the one-rework rule; fit pass.
Review quality: pass

#### Copy the docs page (question 2)
From your `open-source` folder:
`cp .claude/worktrees/keen-leakey-4c4de7/docs-site/docs/guides/android-sdk.mdx docs-site/docs/guides/`
Your `docs-site/sidebars.ts` lists neither ios-sdk nor android-sdk (08 F9); if it lists guides by
hand, add both.

### Test run
Group 1: `cd sdk-kotlin && ./gradlew build publishAllPublicationsToStagingRepository --console=plain
--rerun-tasks`: BUILD SUCCESSFUL; core 113, sdk 127, 0 failures, 0 skipped; lint "No issues found";
staging repo: sdk-core jar and sdk aar, each with -sources, -javadoc, .pom, .module and checksums.
Every changed file sits in its task's `Files`.
Group 2: `cd sdk-kotlin && ./gradlew build --console=plain`: BUILD SUCCESSFUL (82 of 83 tasks up to
date after the implementers' own builds; group 2 changed no build input but a settings comment);
core 113, sdk 127, 0 failures; lint "No issues found". `git status`: release.sh (S10.2); maven-verify.sh,
sdk-kotlin.yml, settings.gradle.kts, README.md (S10.4); nothing else.
Group 3: `cd sdk-kotlin && ./gradlew build --console=plain`: BUILD SUCCESSFUL (after S10.1b's own
build); core 113, sdk 127, 0 failures; lint "No issues found". `git status`: build.gradle.kts
(S10.1b), sdk-kotlin-publish.yml (S10.5); nothing else in the repo.

### Blocked
none

### Not done
none. M12 (the verify job against Central on your real tag) stays unplanned, as 08 says: the job
exists and its body was rehearsed. Group 1's two unowned lines went to S10.4 (question 2, "yes").

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
Group 3: the tag workflow runs only on an `sdk-kotlin-v*` tag (after the merge, from your release
run); it needs the four secrets of User_Actions Step 5 and fails naming any missing one. The sdk
POM now carries compose (BOM), okhttp and coroutines in compile scope: a change visible to apps,
none yet (nothing is published). The epic row's PR link and the docs page copy wait for stage 10.
