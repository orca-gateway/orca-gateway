import Foundation

/// What `preload` gives the host (Dart `PreloadResult`).
public enum PreloadResult: Equatable, Sendable {
    /// The config to boot with: the saved one or one fetched just now.
    case success(NavConfig)
    /// `/version` asked for an app update: the host shows its force-update
    /// screen.
    case forceUpdate
}

/// The boot is offline (`/version` failed) and no earlier online boot saved a
/// config. Its text is Flutter's, exact.
public struct OfflineBootError: Error, Equatable, Sendable, CustomStringConvertible, LocalizedError {
    /// The error; it carries nothing else.
    public init() {}

    /// "No network and no cached config available".
    public var description: String { "No network and no cached config available" }

    /// The same text, for `localizedDescription`.
    public var errorDescription: String? { description }
}

/// Get the config to boot with, a port of Flutter's `OrcaApp.preload`
/// (sdk/lib/src/widgets/orca_app.dart): the version check against the saved
/// flow versions, then
/// - forceUpdate: `.forceUpdate`;
/// - offline (any `/version` failure): the saved config, else
///   `OfflineBootError`;
/// - fresh: the saved config with no `/config` request; with none saved,
///   `/config` is fetched and saved;
/// - stale: the whole `/config` is fetched and saved again.
///
/// Saving a fetched config keeps its body text and `cache.cacheStaticFlows`
/// it. A `/config` failure is thrown as the client's error, with no fallback
/// to the saved config, as in Flutter. A host can await this during its own
/// splash and then boot with the config and the same `cache`.
public func preload(client: OrcaClient, cache: StaticFlowManager) async throws -> PreloadResult {
    // Dart reads the saved versions beside the request; a read that fails
    // makes the check offline, whatever the server says.
    let local = try? cache.getLocalVersions()
    let outcome = await VersionChecker(client: client).check(localVersions: local ?? [:])
    switch local == nil ? .offline : outcome.result {
    case .forceUpdate:
        return .forceUpdate
    case .offline:
        guard let saved = try cache.loadConfig() else { throw OfflineBootError() }
        return .success(saved)
    case .fresh:
        if let saved = try cache.loadConfig() { return .success(saved) }
        return .success(try await fetchAndSave(client: client, cache: cache))
    case .stale:
        return .success(try await fetchAndSave(client: client, cache: cache))
    }
}

private func fetchAndSave(client: OrcaClient, cache: StaticFlowManager) async throws -> NavConfig {
    let config = try await client.fetchConfig()
    cache.saveConfigRaw(try config.rawBody ?? String(decoding: config.raw.encoded(), as: UTF8.self))
    cache.cacheStaticFlows(config)
    return config
}
