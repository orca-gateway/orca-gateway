import Foundation
import XCTest

@testable import OrcaGatewayCore

/// C15.1 (core part): the version response a forceUpdate is read from, the
/// `/version` request, and the outcomes the boot acts on. The VersionResponse
/// and fetchVersion cases port sdk/test/version_checker_test.dart; the
/// outcomes follow sdk/lib/src/client/version_checker.dart.
final class VersionCheckerTests: XCTestCase {
    let base = URL(string: "http://localhost:8080")!

    func client(_ transport: HTTPTransport) -> OrcaClient {
        OrcaClient(baseURL: base, appId: "testapp", apiKey: "k", deviceId: "dev-1", transport: transport)
    }

    /// An engine that answers every request with `status` and `body`.
    func engine(_ body: String, status: Int = 200) -> StubEngine {
        let stub = StubEngine(page: Data())
        stub.forced = HTTPResponse(status: status, body: Data(body.utf8))
        return stub
    }

    func check(_ transport: HTTPTransport, local: [String: Int] = [:]) async -> VersionCheckOutcome {
        await VersionChecker(client: client(transport)).check(localVersions: local)
    }

    // MARK: VersionResponse and fetchVersion (version_checker_test.dart)

    func testC15_1_versionResponseParsesFlowVersions() throws {
        let json = #"{"flows": {"homeFlow": 3, "profileFlow": 1}}"#
        let response = try JSONValue.decode(Data(json.utf8)).decode(VersionResponse.self)
        XCTAssertEqual(response.flows["homeFlow"], 3)
        XCTAssertEqual(response.flows["profileFlow"], 1)
        XCTAssertFalse(response.forceUpdate, "an absent forceUpdate is false")
    }

    func testC15_1_versionResponseParsesForceUpdate() throws {
        let json = #"{"flows": {"main": 2}, "forceUpdate": true}"#
        let response = try JSONValue.decode(Data(json.utf8)).decode(VersionResponse.self)
        XCTAssertEqual(response, VersionResponse(flows: ["main": 2], forceUpdate: true))
    }

    func testC15_1_fetchVersionGetsTheVersionRouteWithTheClientHeaders() async throws {
        let stub = engine(#"{"flows": {"homeFlow": 1}}"#)
        let c = client(stub)
        let result = try await c.fetchVersion()
        XCTAssertEqual(result, VersionResponse(flows: ["homeFlow": 1], forceUpdate: false))
        XCTAssertEqual(stub.requests.count, 1)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.url.absoluteString, "http://localhost:8080/api/v1/app/testapp/version")
        XCTAssertEqual(request.headers, c.headers)
        XCTAssertNil(request.body)
    }

    func testC15_1_fetchVersionThrowsTheHttpErrorOnNon200() async {
        do {
            _ = try await client(engine("Not Found", status: 404)).fetchVersion()
            XCTFail("a 404 throws")
        } catch {
            XCTAssertEqual(error as? OrcaClientError, .http(status: 404, body: "Not Found"))
        }
    }

    // MARK: VersionChecker outcomes (version_checker.dart)

    func testC15_1_forceUpdateWinsBeforeStaleness() async {
        let outcome = await check(engine(#"{"flows": {"home": 2}, "forceUpdate": true}"#), local: ["home": 1])
        XCTAssertEqual(outcome, VersionCheckOutcome(result: .forceUpdate))
        XCTAssertEqual(outcome.staleFlows, [])
    }

    func testC15_1_matchingVersionsAreFresh() async {
        let outcome = await check(engine(#"{"flows": {"home": 2, "profile": 1}}"#),
                                  local: ["home": 2, "profile": 1, "gone": 9])
        XCTAssertEqual(outcome, VersionCheckOutcome(result: .fresh))
    }

    func testC15_1_differingAndMissingFlowsAreStaleSortedByName() async {
        let outcome = await check(engine(#"{"flows": {"profile": 1, "home": 3, "cart": 1, "about": 4}}"#),
                                  local: ["home": 2, "cart": 1, "about": 4])
        XCTAssertEqual(outcome, VersionCheckOutcome(result: .stale, staleFlows: ["home", "profile"]))
    }

    func testC15_1_aTransportFailureIsOffline() async {
        let outcome = await check(DownTransport())
        XCTAssertEqual(outcome, VersionCheckOutcome(result: .offline))
    }

    func testC15_1_aNon200IsOffline() async {
        let outcome = await check(engine("boom", status: 500))
        XCTAssertEqual(outcome, VersionCheckOutcome(result: .offline))
    }

    func testC15_1_anUndecodableBodyIsOffline() async {
        let notJSON = await check(engine("not json"))
        XCTAssertEqual(notJSON.result, .offline)
        let noFlows = await check(engine(#"{"forceUpdate": true}"#))
        XCTAssertEqual(noFlows.result, .offline, "flows is required, as in Dart")
    }
}
