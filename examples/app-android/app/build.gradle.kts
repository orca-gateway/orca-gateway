import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    // Google's google-services Gradle plugin (Apache 2.0, github.com/google/play-services-plugins),
    // the app side of the push plugin's Firebase Cloud Messaging: it turns app/google-services.json
    // into the resources Firebase starts from. On the build classpath here, applied below.
    id("com.google.gms.google-services") version "4.6.0" apply false
}

// Only with the user's Firebase file, app/google-services.json, which is git-ignored. Without it
// the app builds and runs: local notifications work, and the push plugin's token and topic actions
// fail, Firebase not being set up.
if (file("google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}

// The Google map's Maps API key: GOOGLE_MAPS_ANDROID_API_KEY in local.properties,
// which is git-ignored, so the key is never committed. Empty when absent.
val googleMapsApiKey: String = rootDir.resolve("local.properties")
    .takeIf { it.isFile }
    ?.let { file -> Properties().apply { file.inputStream().use { load(it) } } }
    ?.getProperty("GOOGLE_MAPS_ANDROID_API_KEY")
    .orEmpty()

android {
    namespace = "com.orcagateway.examples.counter"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.orcagateway.examples.counter"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        // The manifest's com.google.android.geo.API_KEY.
        manifestPlaceholders["GOOGLE_MAPS_ANDROID_API_KEY"] = googleMapsApiKey
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
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
        allWarningsAsErrors.set(true)
    }
}

// The SDK's own version, so the included build's project is the one resolved.
val sdkVersion = rootDir.resolve("../../sdk-kotlin/VERSION").readText().trim()

// The voice recorder's own version, read the same way, for its included build.
val voiceRecorderVersion = rootDir.resolve("../../plugins/orca_voice_recorder/android/VERSION").readText().trim()

// The video player's own version, read the same way, for its included build.
val videoPlayerVersion = rootDir.resolve("../../plugins/orca_video_player/android/VERSION").readText().trim()

// The Google map's own version, read the same way, for its included build.
val googleMapVersion = rootDir.resolve("../../plugins/orca_google_map/android/VERSION").readText().trim()

// The push notification's own version, read the same way, for its included build.
val pushNotificationVersion = rootDir.resolve("../../plugins/orca_push_notification/android/VERSION").readText().trim()

dependencies {
    implementation("com.orcagateway:sdk:$sdkVersion")
    implementation("com.orcagateway:orca-voice-recorder:$voiceRecorderVersion")
    implementation("com.orcagateway:orca-video-player:$videoPlayerVersion")
    implementation("com.orcagateway:orca-google-map:$googleMapVersion")
    implementation("com.orcagateway:orca-push-notification:$pushNotificationVersion")
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.material3)
    implementation(libs.activity.compose)
}
