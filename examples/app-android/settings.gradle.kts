// The counter example on Android, drawn by the Kotlin SDK. It builds the SDK
// from source: the included build ../../sdk-kotlin substitutes the
// com.orcagateway:sdk dependency below, so an SDK change shows up on the next
// build. The version catalog is the SDK's, so both stay on one toolchain.
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
            from(files("../../sdk-kotlin/gradle/libs.versions.toml"))
        }
    }
}

rootProject.name = "orca-counter-android"
includeBuild("../../sdk-kotlin")
include(":app")
