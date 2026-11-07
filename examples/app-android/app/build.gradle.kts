import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.orcagateway.examples.counter"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.orcagateway.examples.counter"
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
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
        allWarningsAsErrors.set(true)
    }
}

// The SDK's own version, so the included build's project is the one resolved.
val sdkVersion = rootDir.resolve("../../sdk-kotlin/VERSION").readText().trim()

dependencies {
    implementation("com.orcagateway:sdk:$sdkVersion")
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.material3)
    implementation(libs.activity.compose)
}
