// Orca Gateway Android SDK (experimental, Epic 23b). Modules:
//   core  pure Kotlin/JVM: wire models, ValueResolver, ElmStore, the action
//         executor with effects as data, the generated capability vector.
//         Published as com.orcagateway:sdk-core (slice S10).
//   sdk   the Android library: OkHttp transport, Compose renderer, OrcaApp.
//         Published as com.orcagateway:sdk (slice S10).
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
include(":sdk")
