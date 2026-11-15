import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@testable import OrcaGatewayCore

/// C18.2 (the mapping half): an error becomes the title and message of
/// Flutter's error screen, `buildOrcaError` in
/// sdk/lib/src/widgets/orca_error.dart, one test per branch.
final class OrcaErrorInfoTests: XCTestCase {
    private func assertInfo(
        _ error: Error, _ kind: OrcaErrorInfo.Kind, _ title: String, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let info = OrcaErrorInfo(error)
        XCTAssertEqual(info.kind, kind, file: file, line: line)
        XCTAssertEqual(info.title, title, file: file, line: line)
        XCTAssertEqual(info.message, message, file: file, line: line)
    }

    private let connection = "Unable to reach the server. Please check your network and server status."

    // MARK: A client error with an HTTP status

    func testC18_2_status401IsUnauthorized() {
        assertInfo(OrcaClientError.http(status: 401, body: ""), .unauthorized, "Unauthorized",
                   "Invalid or missing API key. Please check your configuration.")
    }

    func testC18_2_status403IsForbidden() {
        assertInfo(OrcaClientError.http(status: 403, body: ""), .forbidden, "Forbidden",
                   "You do not have permission to access this resource.")
    }

    func testC18_2_status404IsNotFound() {
        assertInfo(OrcaClientError.http(status: 404, body: "Not Found"), .notFound, "Not Found",
                   "The requested page could not be found.")
    }

    func testC18_2_status429IsTooManyRequests() {
        assertInfo(OrcaClientError.http(status: 429, body: ""), .tooManyRequests, "Too Many Requests",
                   "Please slow down and try again in a moment.")
    }

    func testC18_2_status500IsServerError() {
        assertInfo(OrcaClientError.http(status: 500, body: ""), .server, "Server Error",
                   "Something went wrong on the server. Please try again later.")
    }

    func testC18_2_status503IsServerError() {
        assertInfo(OrcaClientError.http(status: 503, body: "busy"), .server, "Server Error",
                   "Something went wrong on the server. Please try again later.")
    }

    func testC18_2_otherStatusKeepsTheClientMessage() {
        assertInfo(OrcaClientError.http(status: 418, body: "teapot"), .status, "Error",
                   "Failed to fetch page: 418")
    }

    // MARK: A server action error with its status

    func testC18_2_actionOtherStatusKeepsItsMessage() {
        assertInfo(OrcaClientError.action(status: 422, message: "Insufficient funds"), .status, "Error",
                   "Insufficient funds")
    }

    func testC18_2_actionWithoutAnErrorFieldKeepsTheDefaultMessage() {
        assertInfo(OrcaClientError.action(status: 400, message: "Server action failed"), .status, "Error",
                   "Server action failed")
    }

    func testC18_2_actionStatusesMapAsPageStatuses() {
        assertInfo(OrcaClientError.action(status: 401, message: "x"), .unauthorized, "Unauthorized",
                   "Invalid or missing API key. Please check your configuration.")
        assertInfo(OrcaClientError.action(status: 403, message: "x"), .forbidden, "Forbidden",
                   "You do not have permission to access this resource.")
        assertInfo(OrcaClientError.action(status: 404, message: "x"), .notFound, "Not Found",
                   "The requested page could not be found.")
        assertInfo(OrcaClientError.action(status: 429, message: "x"), .tooManyRequests, "Too Many Requests",
                   "Please slow down and try again in a moment.")
        assertInfo(OrcaClientError.action(status: 502, message: "x"), .server, "Server Error",
                   "Something went wrong on the server. Please try again later.")
    }

    // MARK: Configuration

    func testC18_2_decodeErrorIsConfigurationError() throws {
        var thrown: Error?
        do { _ = try JSONValue.decode(Data("{not json".utf8)) } catch { thrown = error }
        assertInfo(try XCTUnwrap(thrown), .configuration, "Configuration Error",
                   "Invalid value in configuration. Please check your setup.")
    }

    func testC18_2_modelDecodeErrorIsConfigurationError() throws {
        var thrown: Error?
        do { _ = try JSONValue.decode(Data("[1]".utf8)).decode(VersionResponse.self) } catch { thrown = error }
        assertInfo(try XCTUnwrap(thrown), .configuration, "Configuration Error",
                   "Invalid value in configuration. Please check your setup.")
    }

    func testC18_2_invalidURLIsConfigurationError() {
        assertInfo(OrcaClientError.invalidURL("http://a b"), .configuration, "Configuration Error",
                   "Invalid value in configuration. Please check your setup.")
    }

    // MARK: Transport errors that never reached the server

    func testC18_2_cannotConnectToHostIsConnectionFailed() {
        assertInfo(URLError(.cannotConnectToHost), .connection, "Connection Failed", connection)
    }

    func testC18_2_notConnectedToInternetIsConnectionFailed() {
        assertInfo(URLError(.notConnectedToInternet), .connection, "Connection Failed", connection)
    }

    func testC18_2_cannotFindHostIsConnectionFailed() {
        assertInfo(URLError(.cannotFindHost), .connection, "Connection Failed", connection)
    }

    func testC18_2_networkConnectionLostIsConnectionFailed() {
        assertInfo(URLError(.networkConnectionLost), .connection, "Connection Failed", connection)
    }

    func testC18_2_dnsLookupFailedIsConnectionFailed() {
        assertInfo(URLError(.dnsLookupFailed), .connection, "Connection Failed", connection)
    }

    func testC18_2_noUsableNetworkIsConnectionFailed() {
        assertInfo(URLError(.internationalRoamingOff), .connection, "Connection Failed", connection)
        assertInfo(URLError(.dataNotAllowed), .connection, "Connection Failed", connection)
        assertInfo(URLError(.callIsActive), .connection, "Connection Failed", connection)
    }

    func testC18_2_timeoutIsConnectionFailed() {
        assertInfo(URLError(.timedOut), .connection, "Connection Failed", connection)
    }

    // MARK: Anything else

    func testC18_2_otherURLErrorIsSomethingWentWrong() {
        assertInfo(URLError(.badServerResponse), .unknown, "Something Went Wrong",
                   "An unexpected error occurred. Please try again.")
    }

    func testC18_2_unrelatedErrorIsSomethingWentWrong() {
        struct Unrelated: Error {}
        assertInfo(Unrelated(), .unknown, "Something Went Wrong",
                   "An unexpected error occurred. Please try again.")
    }
}
