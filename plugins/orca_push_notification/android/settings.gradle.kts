// The push notification plugin for the Orca Gateway Android SDK, its own
// package (versioned in VERSION, published as com.orcagateway:orca-push-notification).
// It builds on the SDK's toolchain: ./gradlew is a link to the SDK's wrapper,
// the version catalog is the SDK's, and the included build ../../../sdk-kotlin
// substitutes the com.orcagateway:sdk dependency, so inside the monorepo the
// plugin compiles against the SDK's source. The published POM names the
// Maven Central artifact at sdk-kotlin/VERSION. Firebase Cloud Messaging and
// the Play services it brings come from Google's Maven repository.
pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
        google()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        mavenCentral()
        google()
    }
    versionCatalogs {
        create("libs") {
            from(files("../../../sdk-kotlin/gradle/libs.versions.toml"))
        }
    }
}

rootProject.name = "orca-push-notification-android"
includeBuild("../../../sdk-kotlin")
include(":push-notification")
// The module's project takes the artifact's name: a build that includes this
// one (examples/app-android) substitutes com.orcagateway:orca-push-notification
// by group and project name, not by the publication's artifactId.
project(":push-notification").name = "orca-push-notification"
