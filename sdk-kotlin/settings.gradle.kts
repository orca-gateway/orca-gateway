// Orca Gateway Android SDK (experimental, Epic 23b). Modules:
//   core  pure Kotlin/JVM: wire models, ValueResolver, ElmStore, the action
//         executor with effects as data, the generated capability vector.
//         Published as com.orcagateway:sdk-core (slice S10).
//   sdk   the Android library with the Compose renderer (slice S7 onward).
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
}

rootProject.name = "orca-gateway-kotlin"
include(":core")
