import Foundation
import XCTest

@testable import OrcaGatewayCore

/// A stand-in for the engine's page route with its capability-vector cache,
/// following engine/test/caps-412-protocol.test.ts: a known hash answers 200;
/// an unknown hash answers 412 caps_vector_unknown unless the body carries a
/// vector that hashes to it, which is then cached.
final class StubEngine: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: CapabilityVector] = [:]
    private var _requests: [HTTPRequest] = []
    /// When false the stub behaves like an engine without negotiation.
    var negotiates = true
    /// Refuse every vector (the engine's case E: hash and vector disagree).
    var refuseVectors = false
    /// Answer every request with this instead (a non-caps 412, a 500).
    var forced: HTTPResponse?
    let page: Data

    init(page: Data) { self.page = page }

    /// NSLock.withLock is missing from older Linux Foundation releases.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    var requests: [HTTPRequest] { locked { _requests } }
    func cached(_ hash: String) -> CapabilityVector? { locked { cache[hash] } }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        locked {
            _requests.append(request)
            if let forced { return forced }
            guard negotiates, let hash = request.headers["x-orca-caps-hash"] else {
                return HTTPResponse(status: 200, body: page)
            }
            if cache[hash] != nil { return HTTPResponse(status: 200, body: page) }
            if let body = request.body, let json = try? JSONValue.decode(body),
                case .object = json["_orcaCapsVector"],
                let vector = try? json["_orcaCapsVector"].decode(CapabilityVector.self),
                !refuseVectors, vector.hash == hash
            {
                cache[hash] = vector
                return HTTPResponse(status: 200, body: page)
            }
            return HTTPResponse(
                status: 412,
                body: Data(#"{"error":"caps_vector_unknown","hash":"\#(hash)"}"#.utf8))
        }
    }
}

final class OrcaClientTests: XCTestCase {
    let base = URL(string: "http://localhost:8080")!

    func counterPage() throws -> Data {
        try Fixtures.data("sdk-swift/Tests/Pages/counter-home.json")
    }

    func client(_ stub: StubEngine, device: DeviceInfo = DeviceInfo()) -> OrcaClient {
        OrcaClient(baseURL: base, appId: "counter", device: device, transport: stub)
    }

    // MARK: T2.1 the handshake, cases A to E of caps-412-protocol

    func testA_ServerWithoutNegotiationAnswersTheFirstGet() async throws {
        let stub = StubEngine(page: try counterPage())
        stub.negotiates = false
        let page = try await client(stub).fetchPage("home")
        XCTAssertEqual(page.pageId, "home")
        XCTAssertEqual(stub.requests.map(\.method), ["GET"])
    }

    func testB_C_UnknownHashThenOneRetryWithTheVector() async throws {
        let stub = StubEngine(page: try counterPage())
        let c = client(stub)
        let page = try await c.fetchPage("home")
        XCTAssertEqual(page.components.count, 16)

        let requests = stub.requests
        XCTAssertEqual(requests.map(\.method), ["GET", "POST"])
        XCTAssertEqual(requests[0].url.absoluteString, "http://localhost:8080/api/v1/app/counter/page/home")
        XCTAssertNil(requests[0].body)
        XCTAssertEqual(requests[1].url, requests[0].url)
        XCTAssertEqual(requests[1].headers["x-orca-caps-hash"], c.capsHash)
        XCTAssertEqual(requests[1].headers["Content-Type"], "application/json")
        let body = try JSONValue.decode(requests[1].body ?? Data())
        assertJSONEqual(body["_orcaCapsVector"], try JSONValue(encoding: CapabilityVector.current))
        XCTAssertTrue(body["appState"].isNull)
        XCTAssertEqual(stub.cached(c.capsHash), .current)
    }

    func testD_KnownHashTakesTheFastPath() async throws {
        let stub = StubEngine(page: try counterPage())
        let c = client(stub)
        _ = try await c.fetchPage("home")
        _ = try await c.fetchPage("home")
        XCTAssertEqual(stub.requests.map(\.method), ["GET", "POST", "GET"])
    }

    func testE_ASecond412IsNeverRetried() async throws {
        let stub = StubEngine(page: try counterPage())
        stub.refuseVectors = true
        do {
            _ = try await client(stub).fetchPage("home")
            XCTFail("a refused vector must surface as an error")
        } catch OrcaClientError.http(let status, let body) {
            XCTAssertEqual(status, 412)
            XCTAssertTrue(body.contains("caps_vector_unknown"))
        }
        XCTAssertEqual(stub.requests.count, 2)
    }

    func testOther412sPassThroughWithoutARetry() async throws {
        let stub = StubEngine(page: try counterPage())
        stub.forced = HTTPResponse(status: 412, body: Data(#"{"error":"precondition_failed"}"#.utf8))
        do {
            _ = try await client(stub).fetchPage("home")
            XCTFail("expected an error")
        } catch OrcaClientError.http(let status, _) {
            XCTAssertEqual(status, 412)
        }
        XCTAssertEqual(stub.requests.count, 1)
    }

    func testAppStateGoesInThePostBodyOfBothAttempts() async throws {
        let stub = StubEngine(page: try counterPage())
        _ = try await client(stub).fetchPage("home", appState: ["user": "amr"])
        let requests = stub.requests
        XCTAssertEqual(requests.map(\.method), ["POST", "POST"])
        assertJSONEqual(try JSONValue.decode(requests[0].body ?? Data()), ["appState": ["user": "amr"]])
        let retry = try JSONValue.decode(requests[1].body ?? Data())
        assertJSONEqual(retry["appState"], ["user": "amr"])
        XCTAssertFalse(retry["_orcaCapsVector"].isNull)
    }

    func testServerErrorsCarryStatusAndBody() async throws {
        let stub = StubEngine(page: Data())
        stub.forced = HTTPResponse(status: 500, body: Data("boom".utf8))
        do {
            _ = try await client(stub).fetchPage("home")
            XCTFail("expected an error")
        } catch let error as OrcaClientError {
            XCTAssertEqual(error, .http(status: 500, body: "boom"))
        }
    }

    func testPageURLJoinsBaseAndPathWithOneSlash() throws {
        let c = OrcaClient(
            baseURL: URL(string: "http://h:1/")!, appId: "a", transport: StubEngine(page: Data()))
        XCTAssertEqual(try c.pageURL("/shop/cart").absoluteString, "http://h:1/api/v1/app/a/page/shop/cart")
    }

    // MARK: T2.2 headers

    func testHeadersMatchTheFlutterClient() throws {
        let device = DeviceInfo(
            osVersion: "Version 18.5 (Build 22F77)",
            screenWidth: 393, screenHeight: 852, pixelDensity: 3,
            safeTop: 59, safeBottom: 34, safeLeft: 0, safeRight: 0,
            locale: "en_US", timezone: "GMT+2")
        var c = client(StubEngine(page: Data()), device: device)
        c.apiKey = "demo-key"
        c.environment = "staging"
        c.deviceId = "device-1"
        XCTAssertEqual(c.headers, [
            "x-orca-platform": "iOS",
            "x-orca-os-version": "Version 18.5 (Build 22F77)",
            "x-orca-screen-width": "393",
            "x-orca-screen-height": "852",
            "x-orca-pixel-density": "3.0",
            "x-orca-safe-top": "59",
            "x-orca-safe-bottom": "34",
            "x-orca-safe-left": "0",
            "x-orca-safe-right": "0",
            "x-orca-locale": "en_US",
            "x-orca-timezone": "GMT+2",
            "x-orca-device-id": "device-1",
            "Authorization": "Bearer demo-key",
            "X-Orca-Env": "staging",
            "x-orca-sdk-version": GeneratedCapabilities.sdkSemver,
            "x-orca-caps-hash": GeneratedCapabilities.capsHash,
        ])
    }

    func testFractionalSizesRoundLikeDart() {
        let h = DeviceInfo(screenWidth: 390.5, pixelDensity: 2.625, safeTop: 47.33).headers
        XCTAssertEqual(h["x-orca-screen-width"], "391")
        XCTAssertEqual(h["x-orca-pixel-density"], "2.6")
        XCTAssertEqual(h["x-orca-safe-top"], "47")
        XCTAssertNil(h["x-orca-screen-height"])
        XCTAssertEqual(h["x-orca-platform"], "iOS")
    }

    func testEmptyDeviceIdIsNotSent() {
        var c = client(StubEngine(page: Data()))
        c.deviceId = ""
        XCTAssertNil(c.headers["x-orca-device-id"])
        XCTAssertNil(c.headers["Authorization"])
    }
}
