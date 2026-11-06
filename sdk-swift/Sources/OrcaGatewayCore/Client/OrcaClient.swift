import Foundation

/// A failed page request: a status other than 200, or a URL that cannot be
/// built.
public enum OrcaClientError: Error, Equatable, Sendable {
    case http(status: Int, body: String)
    case invalidURL(String)
    /// A server action answered with a status other than 200. `message` is
    /// the body's `error`, or "Server action failed" (Dart
    /// `OrcaClientException` from `executeAction`).
    case action(status: Int, message: String)
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
        try await fetchPageTimed(path, appState: appState).page
    }

    /// `fetchPage`, plus what it measured for the DevTools `timing` event.
    public func fetchPageTimed(_ path: String, appState: [String: JSONValue]? = nil) async throws
        -> (page: PageResponse, timing: PageLoadTiming)
    {
        let start = OrcaDebug.now()
        let url = try pageURL(path)
        let response = try await sendWithCapsRetry(url: url, appState: appState)
        let received = OrcaDebug.now() - start
        let page: PageResponse
        if response.status == 200 {
            page = try JSONDecoder().decode(PageResponse.self, from: response.body)
        } else if let upgrade = Self.upgradeRequiredPage(response) {
            page = upgrade
        } else {
            throw OrcaClientError.http(
                status: response.status, body: String(decoding: response.body, as: UTF8.self))
        }
        let server = response.headers["x-orca-timing"].flatMap { try? JSONValue.decode(Data($0.utf8)) }
        return (page, PageLoadTiming(
            startMs: start, server: server, responseReceivedMs: received,
            parseCompleteMs: OrcaDebug.now() - start))
    }

    /// The upgrade screen of a 426 (Epic 25b.6): below the app's minimum SDK
    /// version the engine answers `{error, minSdkVersion, clientSdkVersion,
    /// page}`, where `page` is one blocking FallbackPrompt. The page is
    /// rendered like any other, as Flutter does; a 426 without a page, or any
    /// other status, stays an error.
    static func upgradeRequiredPage(_ response: HTTPResponse) -> PageResponse? {
        guard response.status == 426,
              let body = try? JSONValue.decode(response.body),
              case .object = body["page"]
        else { return nil }
        return try? body["page"].decode(PageResponse.self)
    }

    /// `POST /api/v1/app/{appId}/action` with `{action, params?, pageState?,
    /// appState?}`, returning the actions the server sent back (Dart
    /// `executeAction`). Server actions skip the capability handshake: the
    /// engine never checks capabilities on this route and Flutter never
    /// retries one, so neither does Swift.
    ///
    /// Like Dart, the body is read as JSON before the status is checked: a
    /// body that is not JSON throws a decoding error, which a lifecycle's
    /// `onError` sees; a JSON error body throws `OrcaClientError.action`,
    /// which the executor turns into a snackbar.
    public func executeAction(
        _ id: String, params: [String: JSONValue]? = nil,
        pageState: [String: JSONValue]? = nil, appState: [String: JSONValue]? = nil
    ) async throws -> [Action] {
        let url = try endpointURL("action")
        var body: [String: JSONValue] = ["action": .string(id)]
        if let params { body["params"] = .object(params) }
        if let pageState { body["pageState"] = .object(pageState) }
        if let appState { body["appState"] = .object(appState) }
        var headers = self.headers
        headers["Content-Type"] = "application/json"
        let response = try await send(HTTPRequest(
            method: "POST", url: url, headers: headers, body: try JSONValue.object(body).encoded()))
        let json = try JSONValue.decode(response.body)
        guard response.status == 200 else {
            throw OrcaClientError.action(
                status: response.status, message: json["error"].stringValue ?? "Server action failed")
        }
        return try (json["actions"].arrayValue ?? []).map { try $0.decode(Action.self) }
    }

    /// The transport, plus a DevTools `network` event per request and an
    /// `error` event for one that failed or was refused (Dart
    /// `_reportFailedRequest` and `_reportHttpErrorResponse`). The 412 of the
    /// capability handshake is expected, so it is no error.
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard OrcaDebug.isEnabled else { return try await transport.send(request) }
        let start = OrcaDebug.now()
        let url = request.url.absoluteString
        let context = "\(request.method) \(url)"
        let requestHeaders = DevToolsEvent.sanitize(request.headers)
        do {
            let response = try await transport.send(request)
            let ms = OrcaDebug.now() - start
            OrcaDebug.report(.network(
                method: request.method, url: url, statusCode: response.status, durationMs: ms,
                requestSizeBytes: request.body?.count, responseSizeBytes: response.body.count,
                requestHeaders: requestHeaders, responseHeaders: DevToolsEvent.sanitize(response.headers),
                phases: [.init("wait", ms)]))
            let handshake = response.status == 412 && response.errorField == "caps_vector_unknown"
            if response.status >= 400, !handshake {
                OrcaDebug.report(.error(
                    message: "HTTP \(response.status) \(request.url.path)",
                    stackTrace: String(decoding: response.body, as: UTF8.self), context: context))
            }
            return response
        } catch {
            let ms = OrcaDebug.now() - start
            OrcaDebug.report(.network(
                method: request.method, url: url, statusCode: 0, durationMs: ms,
                requestSizeBytes: request.body?.count, requestHeaders: requestHeaders,
                phases: [.init("wait", ms)]))
            OrcaDebug.report(.error(message: "Network request failed: \(error)", context: context))
            throw error
        }
    }

    func pageURL(_ path: String) throws -> URL {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return try endpointURL("page/\(trimmed)")
    }

    /// `{baseURL}/api/v1/app/{appId}/{rest}`, with any trailing slash of the
    /// base URL dropped.
    func endpointURL(_ rest: String) throws -> URL {
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        let text = "\(base)/api/v1/app/\(appId)/\(rest)"
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
        let response = try await send(first)
        guard response.status == 412, response.errorField == "caps_vector_unknown" else {
            return response
        }

        // The retry is always a POST: the vector has to travel in the body.
        var body: [String: JSONValue] = ["_orcaCapsVector": try JSONValue(encoding: capabilities)]
        if let state { body["appState"] = .object(state) }
        return try await send(HTTPRequest(
            method: "POST", url: url, headers: json, body: try JSONValue.object(body).encoded()))
    }
}

/// What a page fetch measured, for the DevTools `timing` event: the engine's
/// `x-orca-timing` header and the client's marks, in milliseconds from the
/// request start. The page view adds the render marks.
public struct PageLoadTiming: Sendable {
    /// When the request started, on `OrcaDebug.now()`'s clock.
    public let startMs: Double
    public var server: JSONValue?
    public var responseReceivedMs: Double
    public var parseCompleteMs: Double

    /// Milliseconds since the request started.
    public func elapsed() -> Double { OrcaDebug.now() - startMs }

    public func event(pageId: String, path: String, renderStartMs: Double, renderCompleteMs: Double,
                      firstFrameMs: Double) -> DevToolsEvent {
        .timing(pageId: pageId, path: path, server: server, client: .init(
            responseReceivedMs: responseReceivedMs, parseCompleteMs: parseCompleteMs,
            renderStartMs: renderStartMs, renderCompleteMs: renderCompleteMs, firstFrameMs: firstFrameMs))
    }
}
