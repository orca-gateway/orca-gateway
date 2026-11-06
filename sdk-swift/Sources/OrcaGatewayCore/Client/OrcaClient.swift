import Foundation

/// A failed page request: a status other than 200, or a URL that cannot be
/// built.
public enum OrcaClientError: Error, Equatable, Sendable {
    case http(status: Int, body: String)
    case invalidURL(String)
}

/// Talks to an Orca engine as the iOS SDK: device and capability headers on
/// every request, and the capability handshake on page loads. A port of
/// `sdk/lib/src/client/orca_client.dart` (page fetch only; server actions
/// arrive with the executor in S3).
///
/// The handshake (Epic 25b slice 2, engine/test/caps-412-protocol.test.ts):
/// every request carries `x-orca-caps-hash`. When the server does not know the
/// hash yet it answers 412 `{"error": "caps_vector_unknown"}`; the client then
/// retries exactly once as a POST with the full vector under `_orcaCapsVector`,
/// and the server caches it, so later requests take the fast path. A second
/// 412 is returned to the caller as an error, never retried again.
///
/// `@unchecked Sendable` only because Linux Foundation before Swift 6 does not
/// mark URL Sendable; every stored property is an immutable value or Sendable.
public struct OrcaClient: @unchecked Sendable {
    public var baseURL: URL
    public var appId: String
    /// Sent as `Authorization: Bearer <apiKey>`.
    public var apiKey: String?
    /// Sent as `X-Orca-Env`.
    public var environment: String?
    /// Sent as `x-orca-device-id`.
    public var deviceId: String?
    public var device: DeviceInfo
    public let capabilities: CapabilityVector
    /// `x-orca-caps-hash`: SHA-256 of the canonical vector, computed once.
    public let capsHash: String
    public let transport: HTTPTransport

    public init(
        baseURL: URL, appId: String, apiKey: String? = nil, environment: String? = nil,
        deviceId: String? = nil, device: DeviceInfo = DeviceInfo(),
        capabilities: CapabilityVector = .current,
        transport: HTTPTransport = URLSessionTransport()
    ) {
        self.baseURL = baseURL
        self.appId = appId
        self.apiKey = apiKey
        self.environment = environment
        self.deviceId = deviceId
        self.device = device
        self.capabilities = capabilities
        self.capsHash = capabilities.hash
        self.transport = transport
    }

    /// Every header the client sends, as the Dart `_deviceHeaders` builds them.
    public var headers: [String: String] {
        var h = device.headers
        if let deviceId, !deviceId.isEmpty { h["x-orca-device-id"] = deviceId }
        if let apiKey { h["Authorization"] = "Bearer \(apiKey)" }
        if let environment { h["X-Orca-Env"] = environment }
        h["x-orca-sdk-version"] = capabilities.sdkSemver
        h["x-orca-caps-hash"] = capsHash
        return h
    }

    /// `GET /api/v1/app/{appId}/page/{path}`, or a POST with `{appState}` when
    /// app state is given, with the capability handshake.
    public func fetchPage(_ path: String, appState: [String: JSONValue]? = nil) async throws
        -> PageResponse
    {
        let url = try pageURL(path)
        let response = try await sendWithCapsRetry(url: url, appState: appState)
        guard response.status == 200 else {
            throw OrcaClientError.http(
                status: response.status, body: String(decoding: response.body, as: UTF8.self))
        }
        return try JSONDecoder().decode(PageResponse.self, from: response.body)
    }

    func pageURL(_ path: String) throws -> URL {
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let text = "\(base)/api/v1/app/\(appId)/page/\(trimmed)"
        guard let url = URL(string: text) else { throw OrcaClientError.invalidURL(text) }
        return url
    }

    /// Dart `_sendPageRequestWithCapsRetry`: at most one retry, only for
    /// `caps_vector_unknown`; any other 412 goes back to the caller as is.
    func sendWithCapsRetry(url: URL, appState: [String: JSONValue]?) async throws -> HTTPResponse {
        let base = headers
        let state = (appState?.isEmpty ?? true) ? nil : appState
        var json = base
        json["Content-Type"] = "application/json"

        let first: HTTPRequest
        if let state {
            first = HTTPRequest(
                method: "POST", url: url, headers: json,
                body: try JSONValue.object(["appState": .object(state)]).encoded())
        } else {
            first = HTTPRequest(method: "GET", url: url, headers: base)
        }
        let response = try await transport.send(first)
        guard response.status == 412, response.errorField == "caps_vector_unknown" else {
            return response
        }

        // The retry is always a POST: the vector has to travel in the body.
        var body: [String: JSONValue] = ["_orcaCapsVector": try JSONValue(encoding: capabilities)]
        if let state { body["appState"] = .object(state) }
        return try await transport.send(HTTPRequest(
            method: "POST", url: url, headers: json, body: try JSONValue.object(body).encoded()))
    }
}
