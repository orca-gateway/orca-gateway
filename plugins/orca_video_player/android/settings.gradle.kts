// The video player plugin for the Orca Gateway Android SDK, its own package
// (versioned in VERSION, published as com.orcagateway:orca-video-player).
// It builds on the SDK's toolchain: ./gradlew is a link to the SDK's wrapper,
// the version catalog is the SDK's, and the included build ../../../sdk-kotlin
// substitutes the com.orcagateway:sdk dependency, so inside the monorepo the
// plugin compiles against the SDK's source. The published POM names the
// Maven Central artifact at sdk-kotlin/VERSION.
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

rootProject.name = "orca-video-player-android"
includeBuild("../../../sdk-kotlin")
include(":video-player")
// The module's project takes the artifact's name: a build that includes this
// one (examples/app-android) substitutes com.orcagateway:orca-video-player
// by group and project name, not by the publication's artifactId.
project(":video-player").name = "orca-video-player"
