import Foundation

/// The engine's answer to `/version`: each static flow's version, and whether
/// the app must be updated before it may run. The Dart `VersionResponse`
/// (sdk/lib/src/models/page_response.dart): `flows` is required,
/// `forceUpdate` is false when absent.
public struct VersionResponse: Decodable, Equatable, Sendable {
    public var flows: [String: Int]
    public var forceUpdate: Bool

    public init(flows: [String: Int], forceUpdate: Bool = false) {
        self.flows = flows
        self.forceUpdate = forceUpdate
    }

    private enum CodingKeys: String, CodingKey {
        case flows, forceUpdate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        flows = try c.decode([String: Int].self, forKey: .flows)
        forceUpdate = try c.decodeIfPresent(Bool.self, forKey: .forceUpdate) ?? false
    }
}

extension OrcaClient {
    /// `GET /api/v1/app/{appId}/version` with the client's headers, the Dart
    /// `fetchVersion` (sdk/lib/src/client/orca_client.dart). Any status but
    /// 200 throws `OrcaClientError.http` with the status and body.
    public func fetchVersion() async throws -> VersionResponse {
        let response = try await send(HTTPRequest(method: "GET", url: try endpointURL("version"), headers: headers))
        guard response.status == 200 else {
            throw OrcaClientError.http(
                status: response.status, body: String(decoding: response.body, as: UTF8.self))
        }
        return try JSONValue.decode(response.body).decode(VersionResponse.self)
    }
}

/// What a version check found (Dart `VersionCheckResult`,
/// sdk/lib/src/client/version_checker.dart).
public enum VersionCheckResult: Sendable {
    /// Every flow matches the local versions.
    case fresh
    /// Some flows have another version on the server.
    case stale
    /// The server demands an app update.
    case forceUpdate
    /// The server could not be asked or gave no usable answer.
    case offline
}

/// A version check's result and, when stale, the flows that differ, sorted
/// by name (Dart `VersionCheckOutcome`).
public struct VersionCheckOutcome: Equatable, Sendable {
    public var result: VersionCheckResult
    public var staleFlows: [String]

    public init(result: VersionCheckResult, staleFlows: [String] = []) {
        self.result = result
        self.staleFlows = staleFlows
    }
}

/// Compares the server's flow versions with the local ones, a port of
/// `VersionChecker` in sdk/lib/src/client/version_checker.dart. The caller
/// passes the local versions (Dart reads them from its StaticFlowManager).
///
/// Where it differs from Dart: the stale flows are sorted by name; Dart keeps
/// the server's order, and nothing depends on it.
public struct VersionChecker: Sendable {
    public let client: OrcaClient

    public init(client: OrcaClient) {
        self.client = client
    }

    /// `forceUpdate` first; then every remote flow whose local version
    /// differs (a flow missing locally counts) makes the outcome stale; none
    /// is fresh. Any failure (network, a non-200, a body that does not
    /// decode) is offline.
    public func check(localVersions: [String: Int]) async -> VersionCheckOutcome {
        let remote: VersionResponse
        do {
            remote = try await client.fetchVersion()
        } catch {
            return VersionCheckOutcome(result: .offline)
        }
        if remote.forceUpdate { return VersionCheckOutcome(result: .forceUpdate) }
        let stale = remote.flows.filter { localVersions[$0.key] != $0.value }.keys.sorted()
        return stale.isEmpty
            ? VersionCheckOutcome(result: .fresh)
            : VersionCheckOutcome(result: .stale, staleFlows: stale)
    }
}
