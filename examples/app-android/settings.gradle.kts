// The counter example on Android, drawn by the Kotlin SDK. It builds the SDK
// from source: the included build ../../sdk-kotlin substitutes the
// com.orcagateway:sdk dependency below, so an SDK change shows up on the next
// build. The version catalog is the SDK's, so both stay on one toolchain.
// The voice recorder plugin comes from source the same way: the included build
// ../../plugins/orca_voice_recorder/android substitutes
// com.orcagateway:orca-voice-recorder. That build includes ../../../sdk-kotlin
// itself, the same directory as ours, so Gradle keeps one SDK build and the
// plugin compiles against the same SDK source as the app.
// The video player plugin likewise: ../../plugins/orca_video_player/android
// substitutes com.orcagateway:orca-video-player and includes the same
// ../../../sdk-kotlin, so the app and both plugins share the one SDK build.
// Its directory is also called android, and Gradle names an included build
// after its directory, so it takes its root project's name instead: two
// builds may not share the build path :android.
// The Google map plugin the same way: ../../plugins/orca_google_map/android
// substitutes com.orcagateway:orca-google-map on the same ../../../sdk-kotlin,
// under its root project's name for the same reason.
// The push notification plugin the same way too:
// ../../plugins/orca_push_notification/android substitutes
// com.orcagateway:orca-push-notification on the same ../../../sdk-kotlin,
// under its root project's name.
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
includeBuild("../../plugins/orca_voice_recorder/android")
includeBuild("../../plugins/orca_video_player/android") { name = "orca-video-player-android" }
includeBuild("../../plugins/orca_google_map/android") { name = "orca-google-map-android" }
includeBuild("../../plugins/orca_push_notification/android") { name = "orca-push-notification-android" }
include(":app")
