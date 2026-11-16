#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// Pages that fail first: each ask takes the next of `failures` (a status, or
/// no answer at all, where the transport throws the platform's connection
/// error `URLError(.cannotConnectToHost)`); once they are used up every path
/// is a page with one Text. Every request is kept.
final class FailingPageStub: HTTPTransport, @unchecked Sendable {
    enum Failure {
        case status(Int, body: String)
        case unreachable
    }

    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private var failures: [Failure]

    init(_ failures: [Failure]) {
        self.failures = failures
    }

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    /// Records the request and takes the next failure, if any is left.
    private func record(_ request: HTTPRequest) -> Failure? {
        lock.lock()
        defer { lock.unlock() }
        _requests.append(request)
        return failures.isEmpty ? nil : failures.removeFirst()
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        switch record(request) {
        case .status(let status, let body):
            return HTTPResponse(status: status, body: Data(body.utf8))
        case .unreachable:
            throw URLError(.cannotConnectToHost)
        case nil:
            let name = request.url.path.components(separatedBy: "/page/").last ?? ""
            let page: JSONValue = [
                "pageId": .string(name), "title": .string(name), "state": [],
                "components": [["id": "0", "type": "Text", "kind": "primitive", "childMode": "none",
                                "props": ["data": .string(name)], "children": [], "watches": []]],
            ]
            return HTTPResponse(status: 200, body: try page.encoded())
        }
    }

    var client: OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                   device: DeviceInfo(osVersion: "test"), transport: self)
    }
}

/// A small view inspector: walks a view's stored values as Mirror sees them,
/// with each of the SDK's own views replaced by its body, so a test reads
/// what a view draws (its Texts' strings, its Images' symbol names) without
/// a window.
@MainActor
enum ViewTree {
    /// The first value of type `T` in `root`'s tree.
    static func first<T>(_ type: T.Type, in root: Any) -> T? {
        var found: T?
        walk(root) { value in
            if let match = value as? T { found = match }
            return found == nil
        }
        return found
    }

    /// Every string in `root`'s tree: Text contents, symbol names, keys.
    static func strings(in root: Any) -> [String] {
        var found: [String] = []
        walk(root) { value in
            if let string = value as? String { found.append(string) }
            return true
        }
        return found
    }

    /// Visits `root` and what it holds, depth first, until `visit` says stop.
    private static func walk(_ root: Any, _ visit: (Any) -> Bool) {
        var seen = Set<ObjectIdentifier>()
        func go(_ value: Any, _ depth: Int) -> Bool {
            guard depth < 80 else { return true }
            guard visit(value) else { return false }
            if let view = value as? any View, String(reflecting: type(of: value)).hasPrefix("OrcaGateway.") {
                return go(body(of: view), depth + 1)
            }
            if type(of: value) is AnyClass, !seen.insert(ObjectIdentifier(value as AnyObject)).inserted {
                return true
            }
            var mirror: Mirror? = Mirror(reflecting: value)
            while let current = mirror {
                for child in current.children where !go(child.value, depth + 1) { return false }
                mirror = current.superclassMirror
            }
            return true
        }
        _ = go(root, 0)
    }

    private static func body<V: View>(of view: V) -> Any { view.body }
}

/// C18.2, the screen half: OrcaApp shows Flutter's `buildOrcaError` screen
/// (sdk/lib/src/widgets/orca_error.dart) for a page that failed, a config
/// boot that failed and a plugin conflict: OrcaErrorInfo's title, message
/// and icon, with "Try again" where the app can retry.
@MainActor
final class ErrorScreenTests: XCTestCase {
    static let notFound = "The requested page could not be found."
    static let connection = "Unable to reach the server. Please check your network and server status."
    static let server = "Something went wrong on the server. Please try again later."

    /// The router of an app opening `home` over `stub`, its root loaded.
    func loadedRoot(_ stub: FailingPageStub) async -> (OrcaRouter, OrcaPageLoader) {
        let router = OrcaRouter(client: stub.client, path: "home", system: SystemRecorder().actions())
        let loader = router.loader(for: router.root)
        await loader.loadIfNeeded()
        return (router, loader)
    }

    /// The error screen the app draws for the router's root page.
    func screen(_ router: OrcaRouter) throws -> OrcaErrorView {
        try XCTUnwrap(ViewTree.first(OrcaErrorView.self, in: RoutePage(router: router, route: router.root)),
                      "the page draws no OrcaErrorView")
    }

    /// Waits until `done` holds, a second at most.
    private func eventually(_ done: () -> Bool) async throws {
        var waited = 0
        while !done(), waited < 100 {
            waited += 1
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let finished = done()
        XCTAssertTrue(finished, "timed out")
    }

    // MARK: the view alone

    func testC18_2_EachKindDrawsItsTitleMessageAndIcon() throws {
        let decoding = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad"))
        let cases: [(Error, OrcaErrorInfo.Kind, String, String, String)] = [
            (OrcaClientError.http(status: 401, body: ""), .unauthorized, "Unauthorized",
             "Invalid or missing API key. Please check your configuration.", "lock"),
            (OrcaClientError.http(status: 403, body: ""), .forbidden, "Forbidden",
             "You do not have permission to access this resource.", "nosign"),
            (OrcaClientError.http(status: 404, body: ""), .notFound, "Not Found", Self.notFound, "magnifyingglass"),
            (OrcaClientError.http(status: 429, body: ""), .tooManyRequests, "Too Many Requests",
             "Please slow down and try again in a moment.", "speedometer"),
            (OrcaClientError.http(status: 503, body: ""), .server, "Server Error", Self.server, "icloud.slash"),
            (OrcaClientError.http(status: 418, body: ""), .status, "Error", "Failed to fetch page: 418",
             "exclamationmark.circle"),
            (decoding, .configuration, "Configuration Error",
             "Invalid value in configuration. Please check your setup.", "gearshape"),
            (URLError(.cannotConnectToHost), .connection, "Connection Failed", Self.connection, "wifi.slash"),
            (CocoaError(.fileNoSuchFile), .unknown, "Something Went Wrong",
             "An unexpected error occurred. Please try again.", "exclamationmark.circle"),
        ]
        for (error, kind, title, message, symbol) in cases {
            let view = OrcaErrorView(error: error)
            XCTAssertEqual(view.info.kind, kind, "\(error)")
            XCTAssertEqual(OrcaErrorView.symbol(kind), symbol)
            let drawn = ViewTree.strings(in: view)
            for shown in [title, message, symbol] {
                XCTAssertTrue(drawn.contains(shown), "\(kind) does not draw \(shown): \(drawn)")
            }
            XCTAssertFalse(drawn.contains("Try again"), "\(kind): no retry was given")
            #if canImport(UIKit)
            XCTAssertNotNil(UIImage(systemName: symbol), "no SF Symbol \(symbol)")
            #elseif canImport(AppKit)
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), "no SF Symbol \(symbol)")
            #endif
            let renderer = ImageRenderer(content: view.frame(width: 390, height: 500))
            XCTAssertNotNil(renderer.cgImage, "\(kind) draws")
        }

        var retried = 0
        let withRetry = OrcaErrorView(error: URLError(.notConnectedToInternet)) { retried += 1 }
        XCTAssertTrue(ViewTree.strings(in: withRetry).contains("Try again"))
        withRetry.retry?()
        XCTAssertEqual(retried, 1)
    }

    // MARK: through the app

    func testC18_2_APageAnswering404ShowsNotFoundWithTryAgain() async throws {
        let stub = FailingPageStub([.status(404, body: "no page here")])
        let (router, loader) = await loadedRoot(stub)
        guard case .failed(let message) = loader.phase else { return XCTFail("not failed: \(loader.phase)") }
        XCTAssertEqual(message, "HTTP 404: no page here", "the phase's message is as before")
        XCTAssertEqual(loader.error as? OrcaClientError, .http(status: 404, body: "no page here"))

        let screen = try screen(router)
        XCTAssertEqual(screen.info.title, "Not Found")
        XCTAssertNotNil(screen.retry)
        let drawn = ViewTree.strings(in: screen)
        for shown in ["Not Found", Self.notFound, "Try again", "magnifyingglass"] {
            XCTAssertTrue(drawn.contains(shown), "missing \(shown): \(drawn)")
        }
        XCTAssertFalse(drawn.contains("Could not load this page"))
        XCTAssertEqual(stub.requests.count, 1)
    }

    func testC18_2_401_403_429And503ShowTheirOwnScreens() async throws {
        let screens: [(Int, String, String)] = [
            (401, "Unauthorized", "Invalid or missing API key. Please check your configuration."),
            (403, "Forbidden", "You do not have permission to access this resource."),
            (429, "Too Many Requests", "Please slow down and try again in a moment."),
            (503, "Server Error", Self.server),
        ]
        for (status, title, message) in screens {
            let (router, loader) = await loadedRoot(FailingPageStub([.status(status, body: "down")]))
            guard case .failed("HTTP \(status): down") = loader.phase else {
                XCTFail("\(status): not failed as before: \(loader.phase)")
                continue
            }
            let drawn = ViewTree.strings(in: try screen(router))
            for shown in [title, message, "Try again"] {
                XCTAssertTrue(drawn.contains(shown), "\(status) does not draw \(shown): \(drawn)")
            }
        }
    }

    func testC18_2_AnUnreachableServerShowsConnectionFailed() async throws {
        let (router, loader) = await loadedRoot(FailingPageStub([.unreachable]))
        guard case .failed(let message) = loader.phase else { return XCTFail("not failed: \(loader.phase)") }
        XCTAssertEqual(message, URLError(.cannotConnectToHost).localizedDescription)
        XCTAssertEqual((loader.error as? URLError)?.code, .cannotConnectToHost)
        let drawn = ViewTree.strings(in: try screen(router))
        for shown in ["Connection Failed", Self.connection, "Try again", "wifi.slash"] {
            XCTAssertTrue(drawn.contains(shown), "missing \(shown): \(drawn)")
        }
    }

    func testC18_2_ARetryAfterAFailureLoadsThePage() async throws {
        let stub = FailingPageStub([.unreachable])
        let (router, loader) = await loadedRoot(stub)
        XCTAssertNotNil(loader.error)
        let retry = try XCTUnwrap(try screen(router).retry)

        retry()
        try await eventually {
            if case .loaded = loader.phase { return true }
            return false
        }
        guard case .loaded(let model) = loader.phase else { return XCTFail("not loaded: \(loader.phase)") }
        XCTAssertEqual(model.page.pageId, "home")
        XCTAssertNil(loader.error, "a reload clears the error")
        XCTAssertNotNil(ViewTree.first(OrcaPageView.self, in: RoutePage(router: router, route: router.root)),
                        "the page, not the error screen")
        XCTAssertEqual(stub.requests.count, 2)
    }

    func testC18_2_AConfigBootFailingWith500ShowsServerErrorAndRetries() async throws {
        let stub = BootStub(config: [
            "initialRoute": "/welcome",
            "flows": [["name": "main", "routes": [["path": "welcome"]]]],
        ], configFailures: 1)
        let boot = OrcaAppBoot(client: BootStub.client(stub), path: nil, system: SystemRecorder().actions(),
                               onRouteChanged: nil)
        await boot.startIfNeeded()
        guard case .failed("HTTP 500: config is down") = boot.phase else {
            return XCTFail("not failed as before: \(boot.phase)")
        }
        XCTAssertEqual(boot.error as? OrcaClientError, .http(status: 500, body: "config is down"))

        let screen = try XCTUnwrap(ViewTree.first(OrcaErrorView.self, in: AppBootContent(boot: boot)))
        let drawn = ViewTree.strings(in: screen)
        for shown in ["Server Error", Self.server, "Try again", "icloud.slash"] {
            XCTAssertTrue(drawn.contains(shown), "missing \(shown): \(drawn)")
        }
        XCTAssertFalse(drawn.contains("Could not start the app"))

        try XCTUnwrap(screen.retry)()
        try await eventually {
            if case .ready = boot.phase { return true }
            return false
        }
        XCTAssertNil(boot.error, "a retry clears the error")
        XCTAssertEqual(stub.configRequests.count, 2)
        XCTAssertEqual(stub.pageRequests.count, 0)
    }

    func testC18_2_APluginConflictShowsSomethingWentWrongWithTheConflictAndNoRetry() async throws {
        let message = #"Widget type "ColoredBadge" from plugin "b" conflicts with plugin "a"."#
        let stub = FailingPageStub([])
        let boot = OrcaBootModel(enableOffline: false, store: MemoryKeyValueStore(), failure: message)
        var built = false
        let gate = OrcaBootView(boot: boot, client: stub.client) {
            let _ = { built = true }()
            Text("page")
        }

        let screen = try XCTUnwrap(ViewTree.first(OrcaErrorView.self, in: gate))
        XCTAssertEqual(screen.info.kind, .unknown)
        XCTAssertNil(screen.retry, "a conflict stays one")
        let drawn = ViewTree.strings(in: screen)
        for shown in ["Something Went Wrong", message, "exclamationmark.circle"] {
            XCTAssertTrue(drawn.contains(shown), "missing \(shown): \(drawn)")
        }
        XCTAssertFalse(drawn.contains("An unexpected error occurred. Please try again."),
                       "the conflict's own message replaces the default one")
        XCTAssertFalse(drawn.contains("Try again"))
        XCTAssertFalse(built, "no page is built")
        XCTAssertEqual(stub.requests.count, 0, "nothing is fetched")
    }
}
#endif
