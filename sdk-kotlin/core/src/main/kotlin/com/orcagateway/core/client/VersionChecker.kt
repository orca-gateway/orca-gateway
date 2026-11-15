package com.orcagateway.core.client

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlin.coroutines.cancellation.CancellationException

/**
 * The engine's answer to `/version`: each static flow's version, and whether
 * the app must be updated before it may run. Ports Dart `VersionResponse`
 * (sdk/lib/src/models/page_response.dart): [flows] is required, [forceUpdate]
 * is false when absent. Swift twin `VersionResponse`.
 */
@Serializable
public data class VersionResponse(
    public val flows: Map<String, Int>,
    public val forceUpdate: Boolean = false,
)

/** Keys the model does not know are skipped, as Dart's `fromJson` and Swift's `Decodable` skip them. */
private val versionJson = Json { ignoreUnknownKeys = true }

/**
 * `GET /api/v1/app/{appId}/version` with the client's headers. Ports Dart
 * `OrcaClient.fetchVersion` (sdk/lib/src/client/orca_client.dart); Swift
 * twin `OrcaClient.fetchVersion`. A 200 decodes as [VersionResponse]; any
 * other status throws [OrcaClientException.Http] with the status and body.
 */
public suspend fun OrcaClient.fetchVersion(): VersionResponse {
    val response = send(HttpRequest("GET", endpointUrl("version"), headers))
    val body = response.body.decodeToString()
    if (response.status != 200) throw OrcaClientException.Http(response.status, body)
    return versionJson.decodeFromString(VersionResponse.serializer(), body)
}

/** What a version check found. Ports Dart `VersionCheckResult` (sdk/lib/src/client/version_checker.dart). */
public enum class VersionCheckResult {
    /** Every flow matches the local versions. */
    Fresh,

    /** Some flows have another version on the server. */
    Stale,

    /** The server demands an app update. */
    ForceUpdate,

    /** The server could not be asked or gave no usable answer. */
    Offline,
}

/**
 * A version check's [result] and, when stale, the flows that differ, sorted
 * by name. Ports Dart `VersionCheckOutcome`; Swift twin `VersionCheckOutcome`.
 */
public data class VersionCheckOutcome(
    public val result: VersionCheckResult,
    public val staleFlows: List<String> = emptyList(),
)

/**
 * Compares the server's flow versions with the local ones. Ports Dart
 * `VersionChecker` (sdk/lib/src/client/version_checker.dart); Swift twin
 * `VersionChecker`. The caller passes the local versions (Dart reads them
 * from its StaticFlowManager).
 *
 * Different from Dart: the stale flows are sorted by name; Dart keeps the
 * server's order, and nothing depends on it.
 */
public class VersionChecker(public val client: OrcaClient) {
    /**
     * [VersionCheckResult.ForceUpdate] first; then every remote flow whose
     * local version differs (a flow missing locally counts) makes the
     * outcome stale; none is fresh. Any failure (network, a non-200, a body
     * that does not decode) is offline. Cancellation still goes up.
     */
    public suspend fun check(localVersions: Map<String, Int>): VersionCheckOutcome {
        val remote = try {
            client.fetchVersion()
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            return VersionCheckOutcome(VersionCheckResult.Offline)
        }
        if (remote.forceUpdate) return VersionCheckOutcome(VersionCheckResult.ForceUpdate)
        val stale = remote.flows.filter { (name, version) -> localVersions[name] != version }.keys.sorted()
        return if (stale.isEmpty()) {
            VersionCheckOutcome(VersionCheckResult.Fresh)
        } else {
            VersionCheckOutcome(VersionCheckResult.Stale, stale)
        }
    }
}
