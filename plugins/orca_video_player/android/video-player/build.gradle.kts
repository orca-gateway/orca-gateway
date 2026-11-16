import com.vanniktech.maven.publish.AndroidSingleVariantLibrary
import com.vanniktech.maven.publish.MavenPublishBaseExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// The video player plugin (Flutter's orca_video_player on Android): the
// VideoPlayer widget and its playback actions, an OrcaPlugin for the Kotlin
// SDK. AGP 9 compiles the Kotlin itself (built-in Kotlin), as in the SDK's
// sdk module.
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

// com.orcagateway:orca-video-player: the release aar with a sources jar and
// an empty javadoc jar (no Dokka), as the SDK's modules. The shared POM and
// the Central upload are in gradle.properties.
mavenPublishing {
    configure(AndroidSingleVariantLibrary(variant = "release", sourcesJar = true, publishJavadocJar = false))
    coordinates(artifactId = "orca-video-player")
    pom {
        name.set("Orca Gateway video player")
        description.set(
            "The video player plugin for the Orca Gateway Android SDK: plays, " +
                "controls and reports network video for server-driven Orca pages.",
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
    namespace = "com.orcagateway.plugins.videoplayer"
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
                // The monorepo root, for tests that read plugins/orca_video_player/.
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
    // Used inside only: the player's view (a TextureView in an AndroidView) and
    // its overlay. Nothing needs a runtime permission (INTERNET is granted at
    // install), so no activity-compose.
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
