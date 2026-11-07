---
topic: maven-central-portal
status: new
first_seen: native-sdk-s10/08 2026-11-07
seen: native-sdk-s10/08
---
# Publishing to Maven Central (Central Portal)

**Concept**  Maven Central is where Gradle finds Android and Java libraries by default. You upload a
signed bundle (jar or aar, POM, sources, javadoc, .asc signatures) for a namespace you own.

**Why here**  Android apps add `mavenCentral()` already; one line, `com.orcagateway:sdk:<X>`, then works.

**When not**  Private or internal libraries: a company repo or GitHub Packages is simpler.

**Tiny example**  CI on tag sdk-kotlin-v0.1.0-alpha.1: ./gradlew publishAndReleaseToMavenCentral
(with the token and the signing key from secrets); minutes later repo1.maven.org serves it.

**Go deeper**  https://central.sonatype.org/publish/publish-portal-gradle/ · docs/User_Actions.md
