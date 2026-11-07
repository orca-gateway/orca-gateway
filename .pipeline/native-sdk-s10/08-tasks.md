# 08 · Tasks · native-sdk-s10

## Front page

### In one breath
tasks: 6 in 3 groups · widest group: 2 · cases: 14 of 15 placed (M12 runs on your real tag)
S10 is 23b.27e: the Android alpha on Maven Central, com.orcagateway:sdk-core and :sdk 0.1.0-alpha.1.
Group 1: Gradle publishes both artifacts (POMs, sources, signing); READMEs get the alpha banner.
Group 2: release.sh gains sdk-kotlin (10, `maven`: it tags, CI publishes); a scratch-app check.
Group 3: the tag-triggered publish workflow; your docs (User_Actions, CLAUDE.md, docs-site page).
Done: a scratch Gradle app builds on a local staging repo now, and on Central after you release.

### New for you
1. Publishing a library to Maven Central → learning/maven-central-portal.md

### Trade-offs
1 needs you: the publish plugin: vanniktech 0.33.0 (cached, untested on AGP 9), or plain
  maven-publish + signing + the Portal's upload API (no plugin, more code).
1 needs you: Central releases automatically once the upload validates, or you click Publish.
2 auto-decided: CI passes only the key's private block; the example keeps building from source.

### Questions for you
1. Commands: `cd sdk-kotlin && ./gradlew build --console=plain`, lint inside. (default: as found)
2. Commits: one per task on feat/native-sdk-s10; nothing pushed before stage 10. (default: per task)
3. One gate per group? (default: yes, 3 gates)
4. needs: com.vanniktech.maven.publish 0.33.0, cached; if it fails on AGP 9, I ask. (default: yes)
5. Central releases automatically, then a verify job builds a scratch app. (default: yes)
6. The docs-site page goes in this worktree (gitignored); you copy it over. (default: yes)
7. Before your release run you do the Sonatype steps: DNS TXT, key, token, 4 secrets. (default: yes)

## Appendix

### Where S10 comes from
Epic row 23b.27e: "Maven Central (S10): `release.sh` `maven` publisher, tag-triggered Central
Portal workflow, docs-site page, README, Sonatype steps in `User_Actions.md`", done when
"`com.orcagateway:sdk:0.1.0-alpha.1` resolves from a clean Gradle project". Namespace
`com.orcagateway` by DNS TXT on orcagateway.com (native-sdk-s6 gate 08, question 3, "A"); two
artifacts, `sdk-core` (module `core`, JVM) and `sdk` (module `sdk`, Android). Swift's S5 is the
reference (`.pipeline/native-sdk-s5/`: release.sh `mirror` publisher, tag-triggered workflow with a
verify job, README install section). S10 started on the default "go" accepted at native-sdk-s9
gate 12 (A); stages 01-07 skipped as covered by native-sdk. Branch feat/native-sdk-s10 from main
738b78f, with S9's closing notes cherry-picked.

### Cases (from row 23b.27e, after Swift's T5.x)
- M1 release.sh in a throwaway clone lists 10 `sdk-kotlin 0.1.0-alpha.1 (maven)`; 1-9 keep their
  numbers.
- M2 untagged 0.1.0-alpha.1: Return, n, r, P (aborted at "Proceed?") give keep (default),
  alpha.2, 0.1.0, 0.1.1; once the tag exists, k is refused.
- M3 n: VERSION and Generated.kt `sdkSemver` read alpha.2; `./gradlew build` plus the staging
  publish pass; a failing build reverts both files.
- M4 no JDK 17+ or no Android SDK (`ANDROID_HOME`/`local.properties`): release.sh stops before any
  bump.
- M5 a clone with a local bare origin, keep confirmed: nothing committed, HEAD tagged
  `sdk-kotlin-v0.1.0-alpha.1`, pushed after the registry packages and before devtools.
- M6 both publications to a staging file repo: `com/orcagateway/sdk-core/<X>` (jar) and
  `com/orcagateway/sdk/<X>` (aar), each with sources jar, javadoc jar, POM and .module.
- M7 each POM: name, description, url, BSL 1.1, scm, developers; sdk's POM and .module depend on
  `com.orcagateway:sdk-core:<X>`, not `core`.
- M8 a throwaway key (an .asc with both blocks) in the in-memory signing properties: every file
  gets an `.asc` gpg verifies; no key: `build` and the staging publish pass unsigned.
- M9 `scripts/maven-verify.sh <url> 0.1.0-alpha.1`: a clean Gradle project takes `com.orcagateway`
  only from `<url>` (exclusiveContent); a JVM module prints `sdkSemver 0.1.0-alpha.1` through
  sdk-core; an Android module calling `OrcaApp` assembles.
- M10 a PR touching `sdk-kotlin/`: SDK Kotlin CI stages the publication and runs M9 on it.
- M11 `sdk-kotlin-publish.yml` ("SDK Kotlin Publish") on a `sdk-kotlin-v<X>` tag or by hand with a
  tag: checks the tag and VERSION == X; reads exactly MAVEN_CENTRAL_USERNAME,
  MAVEN_CENTRAL_PASSWORD, SIGNING_KEY, SIGNING_PASSWORD and names any missing one; signs and
  releases both artifacts in one deployment; skips the upload when X is already on Central.
- M12 the real tag: the verify job on a fresh runner waits for repo1.maven.org, then M9 passes
  against Central at exactly X (23b.27e's acceptance).
- M13 the PR: `sdk-kotlin/README.md` alpha banner and Install (`google()`, `mavenCentral()`,
  `implementation("com.orcagateway:sdk:0.1.0-alpha.1")`, minSdk 24, `OrcaApp`), S10 row "this
  package", Versioning without "from S10"; root README lists `sdk-kotlin/`;
  `examples/app-android/README.md` says the alpha is published and the example builds from source.
- M14 main session: User_Actions Maven entry "before S10 (23b.27e)" plus a Step 6 (release.sh, 10,
  Return, y, watch "SDK Kotlin Publish"); CLAUDE.md release table gains sdk-kotlin and says
  "1-10"; epic row 23b.27e "S10 PR"; docs-site page "Android SDK (alpha)" with copy steps.
- M15 with the plugin applied: `./gradlew build` and the example's `:app:assembleDebug` hold the
  baseline (core 113, sdk 127, lint 0), the example still building the SDK from source.

### Groups
Paths from the repo root unless they start with `/Users/`.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | S10.1 | Publish both artifacts (needs: com.vanniktech.maven.publish 0.33.0) | `sdk-kotlin/gradle/libs.versions.toml`, `sdk-kotlin/build.gradle.kts`, `sdk-kotlin/core/build.gradle.kts`, `sdk-kotlin/sdk/build.gradle.kts`, `sdk-kotlin/gradle.properties` | M6, M7, M8, M15 | M | none |
| 1 | S10.3 | Alpha banner, install section, READMEs | `sdk-kotlin/README.md`, `README.md`, `examples/app-android/README.md` | M13 | M | none |
| 2 | S10.2 | release.sh `maven` publisher for sdk-kotlin | `scripts/release.sh` | M1-M5 | S | S10.1 |
| 2 | S10.4 | Scratch consumer script, PR CI step | `scripts/maven-verify.sh` (new), `.github/workflows/sdk-kotlin.yml` | M9, M10 | S | S10.1 |
| 3 | S10.5 | Tag-triggered Central Portal publish workflow | `.github/workflows/sdk-kotlin-publish.yml` (new) | M11 | S | S10.1, S10.4 |
| 3 | S10.6 | Outside the repo, main session: release docs | `/Users/amrebada/workspace/orca-gateway/docs/User_Actions.md`, `/Users/amrebada/workspace/orca-gateway/CLAUDE.md`, `/Users/amrebada/workspace/orca-gateway/.claude/plans/orcagateway-epics.md`, `docs-site/docs/guides/android-sdk.mdx` (new, gitignored, in this worktree) | M14 | M | S10.2 |

### Order, and why each boundary
- 1 → 2: release.sh's validation and maven-verify.sh both run S10.1's staging publish and use its
  coordinates (`sdk-core`, `sdk`). S10.3 needs nothing.
- 2 → 3: the workflow's verify job calls `scripts/maven-verify.sh` (S10.4) and S10.1's Central and
  signing tasks; User_Actions Step 6 quotes release.sh's prompt (S10.2). The workflow name and the
  four secret names are fixed here, so S10.6 runs beside S10.5.

### Seams
none: every file has one task. `libs.versions.toml` is S10.1's (maven-verify.sh only reads it).

### Findings while planning
F1 The User_Actions Maven entry says "before slice S6 (task 23b.27)" and "the workflow added in
   task 23b.27" (now S10 / 23b.27e); it has no first-release step as the iOS section's Step 5;
   its Step 1 hints that GitHub sign-in eases verification, but `com.orcagateway` is verified only
   by Step 2's DNS TXT.
F2 SIGNING_KEY is "the full contents of orca-release-key.asc", which can hold the public block
   before the private one; Gradle's in-memory signing reads one block, so the workflow passes only
   the PRIVATE KEY BLOCK, and M8 tests a file with both.
F3 Plugin risk: the cache holds vanniktech 0.33.0 (and its central-portal 0.33.0), no Dokka. It
   predates AGP 9 (built-in Kotlin, no kotlin-android plugin to detect) and Gradle 9.7. S10.1
   declares the platforms explicitly (KotlinJvm; AndroidSingleVariantLibrary "release") and ships
   empty javadoc jars, which Central accepts. If 0.33.0 fails: a newer vanniktech (a download) or
   plain maven-publish + signing + the Portal upload API (trade-off 1).
F4 Module `core` publishes as `sdk-core`, so its artifactId is set explicitly (M7).
   `examples/app-android` uses `includeBuild("../../sdk-kotlin")`, substituting by group:name
   (`com.orcagateway:sdk`), so it keeps building from source untouched.
F5 release.sh's `[k]eep` covers a VERSION never tagged (S5). Gaps: the ORDER loop would put
   `maven` in the registry pass (it joins the CI-tag pass, before devtools); selecting 9 and 10
   runs `gen-native-capabilities.ts` twice (harmless; deduplicated).
F6 `gen-native-capabilities.ts` writes both vectors: a Kotlin bump rewrites Generated.swift too (no
   diff unless sdk-swift's VERSION changed).
F7 Validation is a full Android build (minutes); a throwaway clone has no `local.properties`, so
   the rehearsal sets ANDROID_HOME and M4 checks for it first.
F8 Central versions cannot be republished; a release reaches repo1.maven.org minutes to ~30 min
   later. The workflow skips an upload already there; the verify job polls with a timeout
   (trade-off 2: automatic release, or a Publish click in the Portal).
F9 docs-site: writes to your main checkout are blocked (S5 09 F1), so the page goes in this
   worktree's gitignored docs-site and you copy it; your `docs-site/sidebars.ts` lists neither
   ios-sdk nor android-sdk.
F10 Doc gaps: root README's Architecture lists `sdk-swift/` but not `sdk-kotlin/`;
   `examples/app-android/README.md` line 5 says "Nothing is published yet"; CLAUDE.md says "1-9".
F11 Swift's first mirror run failed on an EXIT trap in a root container (S5 12); the Maven
   workflow runs Gradle on the runner, no container, no traps.

### Done when
test: `cd sdk-kotlin && ./gradlew build --console=plain` (compile with warnings as errors, core and
sdk tests, lint) · lint: inside that build (`:sdk:lintDebug`) · typecheck: none · baseline: BUILD
SUCCESSFUL, core 113 and sdk 127 tests green, lint 0 issues, 2026-11-07 (main 738b78f, run with
`--rerun-tasks`). Plus the scripts' own rehearsals (M1-M5 in a throwaway clone, M9 on a staging
repo), whose output goes into the digests.

### Not planned
- M12: the Central verify runs only on your real tag, after the PR merges (as T5.1 did); S10.5
  builds the job and M9 rehearses its body. I never publish.
- Yours, not cases: the release run, the DNS TXT record, the key, the token and the four secrets
  (I never create secrets). Also out: moving `examples/app-android` onto the published artifact (as
  app-ios, S5 F8), and 23b.33 (after S10).

### Commits on feat/native-sdk-s10 (conventional, per task on your yes to question 2)
1. chore(pipeline): native-sdk-s9 closed (done, cherry-picked from S9)
2. chore(pipeline): native-sdk-s10 stage 08
3. one `feat(…)`/`ci(…)`/`docs(…)` commit per task, in group order; S10.6 changes no repo file
4. chore(pipeline): stage 09 onward

### Not in S10
Releasing (yours, with release.sh). 23b.33. A public builder hook. The DevTools compression reply.
