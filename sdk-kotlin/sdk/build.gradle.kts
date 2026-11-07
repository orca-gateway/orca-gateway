import com.vanniktech.maven.publish.AndroidSingleVariantLibrary
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// The Android library: the OkHttp transport, the Compose renderer and OrcaApp
// over the pure core. AGP 9 compiles the Kotlin itself (built-in Kotlin).
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.maven.publish)
}

// com.orcagateway:sdk: the release aar with a sources jar. AGP's javadoc jar
// would run Dokka, so the publication gets an empty one instead, as core does.
mavenPublishing {
    configure(AndroidSingleVariantLibrary(variant = "release", sourcesJar = true, publishJavadocJar = false))
    coordinates(artifactId = "sdk")
    pom {
        name.set("Orca Gateway Android SDK")
        description.set(
            "The Orca Gateway Android SDK: renders server-driven Orca pages with " +
                "Jetpack Compose over an OkHttp transport.",
        )
    }
}

val emptyJavadocJar = tasks.register<Jar>("emptyJavadocJar") {
    archiveClassifier.set("javadoc")
}

publishing.publications.withType<MavenPublication>().configureEach {
    artifact(emptyJavadocJar)
}

android {
    namespace = "com.orcagateway.sdk"
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
                test.systemProperty("orca.repoRoot", rootDir.parentFile.absolutePath)
                // -Porca.recordGoldens=true records the goldens instead of comparing them.
                test.systemProperty(
                    "orca.recordGoldens",
                    providers.gradleProperty("orca.recordGoldens").getOrElse("false"),
                )
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
    api(project(":core"))

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    // Flutter's Material icons by name (style/IconNames.kt); R8 drops the unused ones in apps.
    implementation(libs.compose.material.icons.extended)
    implementation(libs.activity.compose)
    implementation(libs.navigation.compose)
    implementation(libs.okhttp)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(kotlin("test-junit"))
    testImplementation(libs.junit4)
    testImplementation(libs.robolectric)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.mockwebserver)
    debugImplementation(platform(libs.compose.bom))
    debugImplementation(libs.compose.ui.test.manifest)
}
