#!/usr/bin/env bash
#
# Checks a Maven publication of the Android SDK the way an app sees it
# (slice S10): com.orcagateway:sdk-core and com.orcagateway:sdk at <version>,
# resolved from <repo> alone, with nothing built from this repository's
# sources. A scratch Gradle project outside the repository takes the
# com.orcagateway group only from <repo> (exclusiveContent; no includeBuild,
# no mavenLocal), and everything else from Google's repository and Maven
# Central, so a missing artifact, POM or Gradle module file fails here.
#
#   bash scripts/maven-verify.sh <repo> <version>
#
#   <repo>     a Maven repository: file:///…/sdk-kotlin/build/staging-repo
#              (pull-request CI, after publishAllPublicationsToStagingRepository),
#              https://repo1.maven.org/maven2/ (after a release), or a plain
#              directory path.
#   <version>  the version both artifacts must be at.
#
# The scratch project has two modules:
#   jvm      a Kotlin/JVM application on sdk-core; it runs and must print
#            exactly `sdkSemver <version>`.
#   android  an Android app on sdk whose activity shows OrcaApp, as the
#            README's install section says; it must assemble (debug).
#
# Gradle is this repository's wrapper (sdk-kotlin/gradlew), and the plugin
# and library versions are the SDK's own catalog, so the check needs nothing
# the SDK build did not. Environment: ANDROID_HOME (or ANDROID_SDK_ROOT), the
# Android SDK the app builds with.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLEW="$REPO_ROOT/sdk-kotlin/gradlew"
CATALOG="$REPO_ROOT/sdk-kotlin/gradle/libs.versions.toml"

die() { printf "error: %s\n" "$*" >&2; exit 1; }
say() { printf "==> %s\n" "$*"; }

# Cleanup never decides the outcome (see scripts/swift-mirror.sh).
WORK=""
cleanup() {
  if [[ -n "$WORK" ]]; then
    rm -rf "$WORK" 2>/dev/null || true
  fi
}
trap cleanup EXIT

[[ $# -eq 2 ]] || die "usage: $0 <repo-url-or-dir> <version>"
REPO_URL=$1
VERSION=$2

# A plain path becomes a file URL; a URL is taken as it is.
if [[ ! "$REPO_URL" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
  [[ -d "$REPO_URL" ]] || die "no such directory: $REPO_URL"
  REPO_URL="file://$(cd "$REPO_URL" && pwd)"
fi

ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[[ -n "$ANDROID_SDK" ]] \
  || die "set ANDROID_HOME (or ANDROID_SDK_ROOT) to an Android SDK: the android module assembles an app"
[[ -d "$ANDROID_SDK" ]] || die "the Android SDK $ANDROID_SDK is not a directory"

# The repository and version go in as Gradle properties, so the scratch
# build files below are fixed text.
gradle() {
  "$GRADLEW" -p "$WORK" --console=plain \
    -PorcaRepo="$REPO_URL" -PorcaVersion="$VERSION" "$@"
}

WORK=$(mktemp -d)
mkdir -p "$WORK/gradle" \
  "$WORK/jvm/src/main/kotlin" \
  "$WORK/android/src/main/kotlin/com/example/mavenverify"
cp "$CATALOG" "$WORK/gradle/libs.versions.toml"
printf "sdk.dir=%s\n" "$ANDROID_SDK" >"$WORK/local.properties"
printf "org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8\n" >"$WORK/gradle.properties"

cat >"$WORK/settings.gradle.kts" <<'KTS'
pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
        google()
    }
}

// com.orcagateway comes from the repository under test and from nowhere else.
val orcaRepo = providers.gradleProperty("orcaRepo").get()

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        exclusiveContent {
            forRepository { maven { name = "orcaUnderTest"; url = uri(orcaRepo) } }
            filter { includeGroup("com.orcagateway") }
        }
        mavenCentral()
        google()
    }
}

rootProject.name = "maven-verify"
include(":jvm")
include(":android")
KTS

cat >"$WORK/build.gradle.kts" <<'KTS'
plugins {
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
KTS

cat >"$WORK/jvm/build.gradle.kts" <<'KTS'
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.jvm)
    application
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

application {
    mainClass.set("MainKt")
}

dependencies {
    implementation("com.orcagateway:sdk-core:${providers.gradleProperty("orcaVersion").get()}")
}
KTS

# GeneratedCapabilities.sdkSemver is a constant the compiler would copy in;
# CapabilityVector.current reads it from the sdk-core jar at run time.
cat >"$WORK/jvm/src/main/kotlin/Main.kt" <<'KT'
import com.orcagateway.core.capabilities.CapabilityVector

fun main() {
    println("sdkSemver ${CapabilityVector.current.sdkSemver}")
}
KT

cat >"$WORK/android/build.gradle.kts" <<'KTS'
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.example.mavenverify"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.mavenverify"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

dependencies {
    implementation("com.orcagateway:sdk:${providers.gradleProperty("orcaVersion").get()}")
    implementation(libs.activity.compose)
}
KTS

cat >"$WORK/android/src/main/AndroidManifest.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="Maven verify">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
XML

# The README's install example.
cat >"$WORK/android/src/main/kotlin/com/example/mavenverify/MainActivity.kt" <<'KT'
package com.example.mavenverify

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.client.OkHttpTransport
import java.net.URI

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val client = OrcaClient(
            baseUrl = URI("https://orca.example.com"),
            appId = "counter",
            apiKey = "demo-key",
            transport = OkHttpTransport(),
        )
        setContent { OrcaApp(client, path = "home") }
    }
}
KT

say "Running a JVM app on com.orcagateway:sdk-core:$VERSION from $REPO_URL"
output=$(gradle --quiet :jvm:run)
printf "%s\n" "$output"
printed=$(printf "%s\n" "$output" | grep '^sdkSemver ' | tail -1 || true)
[[ "$printed" == "sdkSemver $VERSION" ]] \
  || die "sdk-core $VERSION from $REPO_URL prints '${printed:-nothing}', not 'sdkSemver $VERSION'"

say "Assembling an Android app on com.orcagateway:sdk:$VERSION from $REPO_URL"
gradle :android:assembleDebug
apk="$WORK/android/build/outputs/apk/debug/android-debug.apk"
[[ -f "$apk" ]] || die "the android module assembled, but there is no $apk"

say "PASS maven-verify: com.orcagateway $VERSION from $REPO_URL: sdk-core prints $printed, sdk assembles an app calling OrcaApp"
