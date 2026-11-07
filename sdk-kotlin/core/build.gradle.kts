import com.vanniktech.maven.publish.JavadocJar
import com.vanniktech.maven.publish.KotlinJvm
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.maven.publish)
}

// com.orcagateway:sdk-core: the jar with a sources jar and an empty javadoc jar (no Dokka).
mavenPublishing {
    configure(KotlinJvm(javadocJar = JavadocJar.Empty(), sourcesJar = true))
    coordinates(artifactId = "sdk-core")
    pom {
        name.set("Orca Gateway Kotlin SDK core")
        description.set(
            "The pure Kotlin/JVM core of the Orca Gateway Android SDK: wire models, " +
                "value resolution, state store and action executor.",
        )
    }
}

// Java 17 bytecode, so the Android module (S7) and Android apps can use it.
// Built with whatever JDK 17+ runs Gradle; no toolchain download.
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    explicitApi()
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
        freeCompilerArgs.add("-Xjdk-release=17")
        allWarningsAsErrors.set(true)
    }
}

dependencies {
    api(libs.kotlinx.serialization.json)
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
    // The tests read the conformance fixtures from the monorepo's schema/.
    systemProperty("orca.repoRoot", rootDir.parentFile.absolutePath)
    testLogging {
        events("failed")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
}
