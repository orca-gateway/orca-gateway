# 09 · Implementation · native-sdk-s10

## Front page

### In one breath
group 1 of 3 · tasks: 2 green, 0 blocked · cases: 5 of 14 green · core 113, sdk 127, lint 0
S10.1 Publishing: Gradle stages sdk-core (jar) and sdk (aar), full POMs; signs only with a key.
S10.3 READMEs: the Android SDK says alpha, with an Install section; root and example READMEs too.
vanniktech 0.33.0 works on AGP 9, so the plugin question is closed; nothing was downloaded.

### New for you
nothing new

### Trade-offs
5 auto-decided: empty javadoc jars, POM in gradle.properties, sign only with a key, two of docs.

### Questions for you
1. Next: group 2: S10.2 release.sh gains sdk-kotlin, S10.4 the scratch-app check in PR CI?
   (default: go)
2. S10.4 also updates two lines no task owns: settings.gradle.kts still says "experimental",
   and the README's Tests line gains the new CI step? (default: yes)

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

### Test run
Group 1: `cd sdk-kotlin && ./gradlew build publishAllPublicationsToStagingRepository --console=plain
--rerun-tasks`: BUILD SUCCESSFUL; core 113, sdk 127, 0 failures, 0 skipped; lint "No issues found";
staging repo: sdk-core jar and sdk aar, each with -sources, -javadoc, .pom, .module and checksums.
Every changed file sits in its task's `Files`.

### Blocked
none

### Not done
none. Two lines no task owns (question 2): `sdk-kotlin/settings.gradle.kts`'s header still calls the
SDK "experimental" and names "(slice S10)"; the README's Tests section does not yet mention S10.4's
CI step.

### For ship (stage 10) to know
The build now applies com.vanniktech.maven.publish 0.33.0 (from the Gradle cache; CI downloads it
from the Gradle Plugin Portal). `./gradlew publishAllPublicationsToStagingRepository` writes
`sdk-kotlin/build/staging-repo`. The Central tasks `publishAndReleaseToMavenCentral` and
`publishToMavenCentral` read `mavenCentralUsername`/`mavenCentralPassword` and the in-memory signing
properties (S10.5 maps the four secrets to them).
