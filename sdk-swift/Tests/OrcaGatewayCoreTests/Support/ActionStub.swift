import Foundation

@testable import OrcaGatewayCore

/// The engine's `/action` route, replaying canned answers by action id: an
/// `actions` entry answers 200 `{actions}`, an `error` entry answers 400
/// `{error}`, and an id with no entry answers 500. That matches the Dart
/// fixture runner's `_StubClient`. A `raw` entry is sent back exactly as given.
final class ActionStub: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private let responses: [String: JSONValue]
    private let raw: [String: HTTPResponse]

    init(_ responses: [String: JSONValue], raw: [String: HTTPResponse] = [:]) {
        self.responses = responses
        self.raw = raw
    }

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    /// Synchronous, so the lock is never held across a suspension point.
    private func record(_ request: HTTPRequest) {
        lock.lock()
        _requests.append(request)
        lock.unlock()
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        record(request)
        let body = try JSONValue.decode(request.body ?? Data())
        let id = body["action"].stringValue ?? ""
        if let response = raw[id] { return response }
        guard case .object(let stub)? = responses[id] else {
            return Self.json(500, ["error": .string("no stubbed response for \"\(id)\"")])
        }
        if case .string(let error)? = stub["error"] { return Self.json(400, ["error": .string(error)]) }
        return Self.json(200, ["actions": stub["actions"] ?? .array([])])
    }

    static func json(_ status: Int, _ body: [String: JSONValue]) -> HTTPResponse {
        HTTPResponse(status: status, body: (try? JSONValue.object(body).encoded()) ?? Data())
    }

    static func client(_ transport: HTTPTransport) -> OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app", transport: transport)
    }
}
