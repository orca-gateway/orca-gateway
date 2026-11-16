import com.vanniktech.maven.publish.AndroidSingleVariantLibrary
import com.vanniktech.maven.publish.MavenPublishBaseExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// The push notification plugin (Flutter's orca_push_notification on Android):
// the permission, token, local notification and topic actions on Firebase
// Cloud Messaging and NotificationManagerCompat, an OrcaPlugin for the Kotlin
// SDK. AGP 9 compiles the Kotlin itself (built-in Kotlin), as in the SDK's
// sdk module. It has no widget, so no Compose compiler plugin; that plugin is
// what puts the catalog's Kotlin Gradle plugin on the other plugins' build
// classpath, so here kotlin-jvm does it, not applied: without it AGP 9.0.1
// compiles with its own Kotlin 2.2.10, which cannot read the SDK's 2.4 classes.
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.maven.publish)
}

group = "com.orcagateway"
version = rootDir.resolve("VERSION").readText().trim()

// The SDK's own version: the included build ../../../sdk-kotlin substitutes
// it from source, and the published POM names this Maven Central artifact.
val sdkVersion = rootDir.resolve("../../../sdk-kotlin/VERSION").readText().trim()

// Google's Firebase Cloud Messaging (Apache 2.0, github.com/firebase/firebase-android-sdk),
// the one library outside the SDK's catalog, so its version lives here. It
// brings firebase-common, firebase-installations and the Play services it
// runs on from Google's Maven repository. 26.0.2 (Firebase BoM 35.2.0) is its
// newest release; its AAR asks for minSdk 24 and no compileSdk above 36. The
// google-services Gradle plugin is the app's, not applied here.
val firebaseMessagingVersion = "26.0.2"

// com.orcagateway:orca-push-notification: the release aar with a sources jar
// and an empty javadoc jar (no Dokka), as the SDK's modules. The shared POM
// and the Central upload are in gradle.properties.
mavenPublishing {
    configure(AndroidSingleVariantLibrary(variant = "release", sourcesJar = true, publishJavadocJar = false))
    coordinates(artifactId = "orca-push-notification")
    pom {
        name.set("Orca Gateway push notification")
        description.set(
            "The push notification plugin for the Orca Gateway Android SDK: asks for " +
                "permission, reads the FCM token, shows local notifications and " +
                "subscribes to topics for server-driven Orca pages.",
        )
    }
}

val emptyJavadocJar = tasks.register<Jar>("emptyJavadocJar") {
    archiveClassifier.set("javadoc")
}

// A local Maven repo to publish to with
// `./gradlew publishAllPublicationsToStagingRepository`, for checks before Central.
publishing {
    publications.withType<MavenPublication>().configureEach {
        artifact(emptyJavadocJar)
    }
    repositories.maven {
        name = "staging"
        url = uri(rootProject.layout.buildDirectory.dir("staging-repo"))
    }
}

// Signed only when a key is given (the release workflow), so local builds
// and pull-request CI publish unsigned.
if (providers.gradleProperty("signingInMemoryKey").isPresent) {
    extensions.configure<MavenPublishBaseExtension> { signAllPublications() }
}

android {
    namespace = "com.orcagateway.plugins.pushnotification"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests {
            // Robolectric reads the merged manifest and resources.
            isIncludeAndroidResources = true
            all { test ->
                // The monorepo root, for tests that read plugins/orca_push_notification/.
                test.systemProperty("orca.repoRoot", rootDir.resolve("../../..").canonicalPath)
                test.testLogging {
                    events("failed")
                    exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
                }
            }
        }
    }
}

kotlin {
    explicitApi()
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
        allWarningsAsErrors.set(true)
    }
}

dependencies {
    // In the public API: the plugin is an OrcaPlugin, initialize takes a ComponentActivity.
    api("com.orcagateway:sdk:$sdkVersion")
    api(libs.activity.compose)
    // Used inside only: the token, topics and the messaging service.
    implementation("com.google.firebase:firebase-messaging:$firebaseMessagingVersion")

    testImplementation(kotlin("test-junit"))
    testImplementation(libs.junit4)
    testImplementation(libs.robolectric)
    testImplementation(libs.kotlinx.coroutines.test)
}
