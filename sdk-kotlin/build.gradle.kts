import com.vanniktech.maven.publish.MavenPublishBaseExtension

plugins {
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.maven.publish) apply false
}

// A local Maven repo both artifacts publish to with
// `./gradlew publishAllPublicationsToStagingRepository`, for checks before Central.
val stagingRepo = layout.buildDirectory.dir("staging-repo")

// The coordinates a consumer resolves (Maven Central from slice S10), and what
// examples/app-android substitutes with these projects in its composite build.
subprojects {
    group = "com.orcagateway"
    version = rootDir.resolve("VERSION").readText().trim()

    // The shared POM and the Central upload are in gradle.properties; each
    // module sets its platform, artifactId, name and description.
    pluginManager.withPlugin("com.vanniktech.maven.publish") {
        extensions.configure<PublishingExtension> {
            repositories.maven {
                name = "staging"
                url = uri(stagingRepo)
            }
        }
        // Signed only when a key is given (the release workflow), so local
        // builds and pull-request CI publish unsigned.
        if (providers.gradleProperty("signingInMemoryKey").isPresent) {
            extensions.configure<MavenPublishBaseExtension> { signAllPublications() }
        }
    }
}
