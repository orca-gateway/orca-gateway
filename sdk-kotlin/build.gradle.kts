plugins {
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.android.library) apply false
}

// The coordinates a consumer resolves (Maven Central from slice S10), and what
// examples/app-android substitutes with these projects in its composite build.
subprojects {
    group = "com.orcagateway"
    version = rootDir.resolve("VERSION").readText().trim()
}
