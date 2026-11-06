#if canImport(SwiftUI)
import Foundation
import XCTest

@testable import OrcaGateway

/// Pages by path and the `/action` route, for router tests: a page is
/// `{pageId, title, state, components}` with one Text node, and every request
/// is kept so a test can read the app state a fetch carried.
final class PageStub: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private let state: [String: [JSONValue]]
    private let actionBody: String?

    /// `state` gives each path its state definitions; any other path is a
    /// page with none.
    init(state: [String: [JSONValue]] = [:], actionBody: String? = nil) {
        self.state = state
        self.actionBody = actionBody
    }

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    private func record(_ request: HTTPRequest) {
        lock.lock()
        _requests.append(request)
        lock.unlock()
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        record(request)
        let path = request.url.path
        if path.hasSuffix("/action") {
            return HTTPResponse(status: 200, body: Data((actionBody ?? #"{"actions":[]}"#).utf8))
        }
        let name = path.components(separatedBy: "/page/").last ?? ""
        let page: JSONValue = [
            "pageId": .string(name), "title": .string(name),
            "state": .array(state[name] ?? []),
            "components": [["id": "0", "type": "Text", "kind": "primitive", "childMode": "none",
                            "props": ["data": .string(name)], "children": [], "watches": []]],
        ]
        return HTTPResponse(status: 200, body: try page.encoded())
    }

    /// The app state a request carried (a POST body), or nil for a GET.
    static func appState(_ request: HTTPRequest) -> JSONValue? {
        guard request.method == "POST", let body = request.body else { return nil }
        return (try? JSONValue.decode(body))?["appState"]
    }

    static func client(_ stub: PageStub) -> OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                   device: DeviceInfo(osVersion: "test"), transport: stub)
    }
}

/// What a test's system adapters were asked to do.
@MainActor
final class SystemRecorder {
    var opened: [URL] = []
    var copied: [String] = []
    var shared: [[String?]] = []

    func actions(_ policy: OrcaURLPolicy = .standard) -> SystemActions {
        SystemActions(
            open: { self.opened.append($0) }, copy: { self.copied.append($0) },
            share: { self.shared.append([$0, $1]) }, urlPolicy: policy)
    }
}

/// T3.2: navigation through the router, and openUrl, clipboard and share
/// through recording adapters, as the effects a page's actions report.
@MainActor
final class RouterTests: XCTestCase {
    private func router(_ stub: PageStub = PageStub(), _ recorder: SystemRecorder? = nil)
        -> OrcaRouter
    {
        OrcaRouter(client: PageStub.client(stub), path: "home",
                   system: (recorder ?? SystemRecorder()).actions())
    }

    private func loaded(_ router: OrcaRouter, _ route: OrcaRoute) async throws -> OrcaPageModel {
        let loader = router.loader(for: route)
        await loader.loadIfNeeded()
        guard case .loaded(let model) = loader.phase else {
            throw NSError(domain: "RouterTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "page \(route.path) did not load: \(loader.phase)"])
        }
        return model
    }

    func testNavigatePushesReplaceResetsGoBackPops() {
        let router = router()
        let home = router.root
        XCTAssertEqual(home.path, "home")

        router.navigate(to: "/about")
        router.navigate(to: "product")
        XCTAssertEqual(router.stack.map(\.path), ["about", "product"])
        XCTAssertEqual(router.top.path, "product")

        router.goBack()
        XCTAssertEqual(router.stack.map(\.path), ["about"])

        router.navigate(to: "checkout", replace: true)
        XCTAssertEqual(router.root.path, "checkout")
        XCTAssertNotEqual(router.root.id, home.id)
        XCTAssertEqual(router.stack, [])

        router.goBack()
        router.navigate(to: "")
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(router.root.path, "checkout")
    }

    func testTheSamePathTwiceIsTwoPages() {
        let router = router()
        router.navigate(to: "product")
        router.navigate(to: "product")
        XCTAssertEqual(router.stack.count, 2)
        XCTAssertNotEqual(router.stack[0].id, router.stack[1].id)
        XCTAssertFalse(router.loader(for: router.stack[0]) === router.loader(for: router.stack[1]))
        XCTAssertTrue(router.loader(for: router.stack[0]) === router.loader(for: router.stack[0]))
    }

    func testAPoppedRouteLosesItsPage() {
        let router = router()
        router.navigate(to: "about")
        let about = router.stack[0]
        let first = router.loader(for: about)
        router.stack = []  // a back swipe sets the path directly
        XCTAssertFalse(first === router.loader(for: about))
    }

    func testPageActionsDriveTheRouter() async throws {
        let router = router()
        let home = try await loaded(router, router.root)
        await home.run(.navigate(.init(route: "/about")))
        XCTAssertEqual(router.stack.map(\.path), ["about"])

        let about = try await loaded(router, router.stack[0])
        await about.run(.goBack)
        XCTAssertEqual(router.stack, [])

        await home.run(.navigate(.init(path: "checkout", replace: true)))
        XCTAssertEqual(router.root.path, "checkout")
    }

    /// App state is one scope: the next page's fetch carries it, the page
    /// starts from it, and the page revealed by a pop sees later writes.
    func testAppStateIsSharedAcrossPages() async throws {
        let stub = PageStub(state: [
            "home": [["key": "cart", "scope": "app", "initial": 0]],
            "product": [["key": "cart", "scope": "app", "initial": 99],
                        ["key": "qty", "scope": "page", "initial": 1]],
        ])
        let router = router(stub)
        let home = try await loaded(router, router.root)
        XCTAssertNil(PageStub.appState(stub.requests[0]))
        XCTAssertEqual(router.appState, ["cart": 0])

        await home.run(.setState(.init(key: "cart", scope: .app, value: 2)))
        router.navigate(to: "product")
        let product = try await loaded(router, router.stack[0])
        XCTAssertEqual(PageStub.appState(stub.requests[1]), ["cart": 2])
        // The app key was already set, so the page's own initial is ignored.
        XCTAssertEqual(product.store.state.app, ["cart": 2])
        XCTAssertEqual(product.store.state.page, ["qty": 1])

        await product.run(.setState(.init(key: "cart", scope: .app, value: 3)))
        XCTAssertEqual(home.store.value("cart"), 2)
        router.goBack()
        XCTAssertEqual(home.store.value("cart"), 3)
        XCTAssertEqual(home.store.state.page, [:])
    }

    func testOpenUrlFollowsThePolicy() async throws {
        let recorder = SystemRecorder()
        let router = router(PageStub(), recorder)
        let home = try await loaded(router, router.root)
        var reported: [String] = []
        router.onEffect = { reported.append($0.type) }

        for url in ["https://orca.example/docs", "mailto:hi@orca.example", "javascript:alert(1)",
                    "tel:123", "file:///etc/hosts", "not a url"] {
            await home.run(.openUrl(.init(url: .string(url))))
        }
        XCTAssertEqual(recorder.opened.map(\.absoluteString),
                       ["https://orca.example/docs", "mailto:hi@orca.example"])
        XCTAssertEqual(reported.count, 6, "blocked URLs are still reported")

        let tel = SystemRecorder()
        let policy = OrcaURLPolicy(extraSchemes: ["TEL"])
        XCTAssertTrue(tel.actions(policy).perform(ActionEffect("openUrl", ["url": "tel:123"])))
        XCTAssertEqual(tel.opened.map(\.absoluteString), ["tel:123"])
    }

    func testClipboardAndShare() async throws {
        let recorder = SystemRecorder()
        let router = router(PageStub(), recorder)
        let home = try await loaded(router, router.root)
        await home.run(.copyToClipboard(.init(text: "ORCA-42")))
        await home.run(.share(.init(title: "Orca", message: "Look")))
        await home.run(.share(.init(text: "Plain")))
        XCTAssertEqual(recorder.copied, ["ORCA-42"])
        XCTAssertEqual(recorder.shared, [["Look", "Orca"], ["Plain", nil]])
        XCTAssertFalse(recorder.actions().perform(ActionEffect("navigate", ["route": "x"])))
    }
}
#endif
