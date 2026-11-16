package com.orcagateway.core.client

import com.orcagateway.core.models.NavConfig

/**
 * What [preload] gives the host. Ports Dart `PreloadResult`
 * (sdk/lib/src/widgets/orca_app.dart); Swift twin `PreloadResult`.
 */
public sealed class PreloadResult {
    /** The app may start with [config]: the saved one or the one just fetched. */
    public data class Success(public val config: NavConfig) : PreloadResult()

    /** `/version` said forceUpdate: the host shows its force-update screen. */
    public data object ForceUpdate : PreloadResult()
}

/**
 * [preload] could not reach the server and no config is saved. Its message
 * is Flutter's, exactly. Swift twin `OfflineBootError`.
 */
public class OfflineBootException : Exception("No network and no cached config available")

/**
 * The boot of an app with offline support, which a host can await itself
 * (during its own splash) before it shows the app. Ports Dart
 * `OrcaApp.preload` (sdk/lib/src/widgets/orca_app.dart); Swift twin
 * `preload(client:cache:)`.
 *
 * The [VersionChecker] runs against [cache]'s saved versions (saved
 * versions that cannot be read count as offline, as in Dart's check), then:
 * - force update: [PreloadResult.ForceUpdate];
 * - offline (any `/version` failure): the saved config, else
 *   [OfflineBootException];
 * - fresh: the saved config with no `/config` request; with none saved,
 *   `/config` is fetched and saved as when stale;
 * - stale: the whole `/config` is fetched, its text saved and its static
 *   flows cached ([StaticFlowManager.cacheStaticFlows]).
 *
 * A failed `/config` request is thrown as the client threw it, with no
 * fallback to the saved config, as in Dart. Cancellation goes up.
 */
public suspend fun preload(client: OrcaClient, cache: StaticFlowManager): PreloadResult {
    val local = runCatching { cache.getLocalVersions() }
    val outcome = VersionChecker(client).check(local.getOrDefault(emptyMap()))
    return when (if (local.isFailure) VersionCheckResult.Offline else outcome.result) {
        VersionCheckResult.ForceUpdate -> PreloadResult.ForceUpdate
        VersionCheckResult.Offline -> PreloadResult.Success(cache.loadConfig() ?: throw OfflineBootException())
        VersionCheckResult.Fresh -> cache.loadConfig()?.let { PreloadResult.Success(it) } ?: fetchAndSave(client, cache)
        VersionCheckResult.Stale -> fetchAndSave(client, cache)
    }
}

/** `/config`, then its text and static flows into [cache] (Dart's two fire-and-forget saves, awaited here). */
private suspend fun fetchAndSave(client: OrcaClient, cache: StaticFlowManager): PreloadResult {
    val config = client.fetchConfig()
    cache.saveConfigRaw(config.rawBody ?: config.raw.encoded())
    cache.cacheStaticFlows(config)
    return PreloadResult.Success(config)
}
