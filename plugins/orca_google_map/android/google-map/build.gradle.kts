import com.vanniktech.maven.publish.AndroidSingleVariantLibrary
import com.vanniktech.maven.publish.MavenPublishBaseExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// The map plugin (Flutter's orca_google_map on Android): the GoogleMap widget
// and its moveCamera action on Google's Maps Compose, an OrcaPlugin for the
// Kotlin SDK. AGP 9 compiles the Kotlin itself (built-in Kotlin), as in the
// SDK's sdk module.
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.maven.publish)
}

group = "com.orcagateway"
version = rootDir.resolve("VERSION").readText().trim()

// The SDK's own version: the included build ../../../sdk-kotlin substitutes
// it from source, and the published POM names this Maven Central artifact.
val sdkVersion = rootDir.resolve("../../../sdk-kotlin/VERSION").readText().trim()

// Google's Maps Compose (Apache 2.0, github.com/googlemaps/android-maps-compose),
// the one library outside the SDK's catalog, so its version lives here. It
// brings play-services-maps from Google's Maven repository. 8.3.0 is its newest
// release that compiles at the SDK's compileSdk 36: 8.3.1 and later need 37.
val mapsComposeVersion = "8.3.0"

// com.orcagateway:orca-google-map: the release aar with a sources jar and
// an empty javadoc jar (no Dokka), as the SDK's modules. The shared POM and
// the Central upload are in gradle.properties.
mavenPublishing {
    configure(AndroidSingleVariantLibrary(variant = "release", sourcesJar = true, publishJavadocJar = false))
    coordinates(artifactId = "orca-google-map")
    pom {
        name.set("Orca Gateway Google map")
        description.set(
            "The map plugin for the Orca Gateway Android SDK: draws, moves and " +
                "reports a Google map with markers for server-driven Orca pages.",
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
    namespace = "com.orcagateway.plugins.googlemap"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    testOptions {
        unitTests {
            // Robolectric reads the merged manifest and resources.
            isIncludeAndroidResources = true
            all { test ->
                // The monorepo root, for tests that read plugins/orca_google_map/.
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
    // In the public API: the plugin is an OrcaPlugin, its widget a WidgetBuilder.
    api("com.orcagateway:sdk:$sdkVersion")
    // Used inside only: the GoogleMap composable, its camera state, properties,
    // UI settings and markers. The plugin never asks for location (the app does,
    // as with google_maps_flutter), so no activity-compose.
    implementation("com.google.maps.android:maps-compose:$mapsComposeVersion")
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)

    testImplementation(kotlin("test-junit"))
    testImplementation(libs.junit4)
    testImplementation(libs.robolectric)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.kotlinx.coroutines.test)
    debugImplementation(platform(libs.compose.bom))
    debugImplementation(libs.compose.ui.test.manifest)
}
