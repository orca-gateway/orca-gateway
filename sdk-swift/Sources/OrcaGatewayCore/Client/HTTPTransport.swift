import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One HTTP request as OrcaClient builds it. `@unchecked` only because Linux
/// Foundation before Swift 6 does not mark the (immutable, value-type) URL
/// Sendable.
public struct HTTPRequest: Equatable, @unchecked Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?

    public init(method: String, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

/// One HTTP response; header names are lowercased.
public struct HTTPResponse: Equatable, Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// `error` of a `{"error": "..."}` body, or nil (Dart `_parseErrorField`).
    public var errorField: String? {
        guard let json = try? JSONValue.decode(body) else { return nil }
        return json["error"].stringValue
    }
}

/// The seam between OrcaClient and the network, so the handshake and headers
/// are tested against a stub on any platform.
public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

/// The production transport. URLSession decodes gzip and brotli responses
/// itself, which the engine sends when asked.
public struct URLSessionTransport: HTTPTransport, @unchecked Sendable {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        // dataTask plus a continuation: the async URLSession API is missing
        // from older Linux Foundation releases.
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: urlRequest) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                var headers: [String: String] = [:]
                for (name, value) in http.allHeaderFields {
                    headers[String(describing: name).lowercased()] = String(describing: value)
                }
                continuation.resume(returning: HTTPResponse(
                    status: http.statusCode, headers: headers, body: data ?? Data()))
            }
            task.resume()
        }
    }
}
