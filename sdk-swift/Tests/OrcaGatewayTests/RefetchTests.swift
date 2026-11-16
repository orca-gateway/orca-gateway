#if canImport(SwiftUI)
import Combine
import Foundation
import XCTest

@testable import OrcaGateway

/// Serves one page per request in order (the last one again after that);
/// from request number `failingFrom` on it answers 500. Every request is kept.
private final class RefetchStub: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private let pages: [JSONValue]
    private let failingFrom: Int?

    init(_ pages: [JSONValue], failingFrom: Int? = nil) {
        self.pages = pages
        self.failingFrom = failingFrom
    }

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    /// Keep the request; its number, from 1.
    private func record(_ request: HTTPRequest) -> Int {
        lock.lock()
        defer { lock.unlock() }
        _requests.append(request)
        return _requests.count
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let number = record(request)
        if let failingFrom, number >= failingFrom {
            return HTTPResponse(status: 500, body: Data(#"{"error":"down"}"#.utf8))
        }
        return HTTPResponse(status: 200, body: try pages[min(number, pages.count) - 1].encoded())
    }

    var client: OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                   device: DeviceInfo(osVersion: "test"), transport: self)
    }

    /// The app state a request carried (a POST body), or nil for a GET.
    static func appState(_ request: HTTPRequest) -> JSONValue? {
        guard request.method == "POST", let body = request.body else { return nil }
        return (try? JSONValue.decode(body))?["appState"]
    }
}

/// The action types a host handler ran, in order.
private actor RanActions {
    private(set) var types: [String] = []

    func record(_ action: JSONValue) {
        types.append(action["type"].stringValue ?? "")
    }
}

/// A5.6: refetchPage fetches the page again and swaps its tree in place, as
/// Flutter's `OrcaPage.onRefetchPage` (sdk/lib/src/widgets/orca_page.dart):
/// no loading phase, the same page model, app state kept, page state back to
/// the new page's initial values, no effect.
@MainActor
final class RefetchTests: XCTestCase {
    /// A Column of a Text showing `id` that runs refetchPage on tap, and with
    /// `extra` a second Text "added".
    private static func page(_ id: String, extra: Bool = false, state: [JSONValue] = []) -> JSONValue {
        var children: [JSONValue] = ["label"]
        var nodes: [JSONValue] = [[
            "id": "label", "type": "Text", "kind": "primitive", "childMode": "none",
            "props": ["data": .string(id)], "children": [], "watches": [],
            "actions": ["onTap": ["type": "refetchPage"]],
        ]]
        if extra {
            children.append("extra")
            nodes.append([
                "id": "extra", "type": "Text", "kind": "primitive", "childMode": "none",
                "props": ["data": "added"], "children": [], "watches": [],
            ])
        }
        let root: JSONValue = [
            "id": "root", "type": "Column", "kind": "layout", "childMode": "multi",
            "props": [:], "children": .array(children), "watches": [],
        ]
        return ["pageId": .string(id), "title": .string(id), "state": .array(state),
                "components": .array([root] + nodes)]
    }

    private func loaded(_ loader: OrcaPageLoader) async throws -> OrcaPageModel {
        await loader.loadIfNeeded()
        guard case .loaded(let model) = loader.phase else {
            throw NSError(domain: "RefetchTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "page did not load: \(loader.phase)"])
        }
        return model
    }

    /// Tap the label, which runs refetchPage, and wait for the action.
    private func refetch(_ model: OrcaPageModel) async throws {
        let label = try XCTUnwrap(model.resolve("label"))
        let task = try XCTUnwrap(model.fire("onTap", on: label))
        await task.value
    }

    func testA5_6_RefetchPageSwapsTheTreeInPlaceWithoutLoading() async throws {
        let stub = RefetchStub([Self.page("first"), Self.page("second", extra: true)])
        let router = OrcaRouter(client: stub.client, path: "home", system: SystemRecorder().actions())
        let loader = router.loader(for: router.root)
        let model = try await loaded(loader)
        let revision = model.structureRevision
        var phases: [String] = []
        let watch = loader.$phase.dropFirst().sink { phase in
            switch phase {
            case .loading: phases.append("loading")
            case .loaded: phases.append("loaded")
            case .failed: phases.append("failed")
            }
        }
        defer { watch.cancel() }

        try await refetch(model)

        // The action ends after the second fetch, of the same path, with the
        // swap landed.
        XCTAssertEqual(stub.requests.map(\.url.path), Array(repeating: "/api/v1/app/fixture-app/page/home", count: 2))
        XCTAssertEqual(model.page.pageId, "second")
        XCTAssertEqual(model.store.pageId, "second")
        XCTAssertEqual(model.renderer.rootId, "root")
        XCTAssertEqual(model.resolve("label")?["data"], "second")
        XCTAssertEqual(model.resolve("extra")?["data"], "added")
        XCTAssertEqual(model.resolve("root")?.childIds, ["label", "extra"])
        XCTAssertGreaterThan(model.structureRevision, revision, "the view redraws")
        // No loading phase, not even a set phase: the same model stays.
        XCTAssertEqual(phases, [])
        guard case .loaded(let after) = loader.phase else { return XCTFail("\(loader.phase)") }
        XCTAssertTrue(after === model)
    }

    func testA5_6_RefetchPageKeepsAppStateAndResetsPageState() async throws {
        let stub = RefetchStub([
            Self.page("first", state: [
                ["key": "visits", "scope": "app", "initial": 0],
                ["key": "count", "scope": "page", "initial": 0],
                ["key": "draft", "scope": "page", "initial": "x"],
            ]),
            Self.page("second", state: [
                ["key": "visits", "scope": "app", "initial": 0],
                ["key": "theme", "scope": "app", "initial": "dark"],
                ["key": "count", "scope": "page", "initial": 10],
            ]),
        ])
        let router = OrcaRouter(client: stub.client, path: "home", system: SystemRecorder().actions())
        let model = try await loaded(router.loader(for: router.root))
        model.store.dispatch(["visits": 3], scope: .app)
        model.store.dispatch(["count": 5, "draft": "typed"], scope: .page)

        try await refetch(model)

        // Fetched with the app state, as the loader fetches.
        XCTAssertEqual(stub.requests.count, 2)
        XCTAssertEqual(stub.requests.dropFirst().first.flatMap(RefetchStub.appState), ["visits": 3])
        // App state kept, unset app keys seeded; page state the new page's.
        XCTAssertEqual(model.store.state.app, ["visits": 3, "theme": "dark"])
        XCTAssertEqual(model.store.state.page, ["count": 10])
        XCTAssertEqual(router.appState, ["visits": 3, "theme": "dark"])
    }

    func testA5_6_RefetchPageEmitsNoEffect() async throws {
        let stub = RefetchStub([Self.page("first"), Self.page("second")])
        let loader = OrcaPageLoader(client: stub.client, path: "home")
        let model = try await loaded(loader)
        var reported: [ActionEffect] = []
        var performed: [ActionEffect] = []
        var errors: [Error] = []
        model.onEffect = { reported.append($0) }
        model.effectHandler = { performed.append($0) }
        model.onError = { errors.append($0) }
        model.store.dispatch(["visits": 1], scope: .app)

        try await refetch(model)

        XCTAssertEqual(model.page.pageId, "second")
        XCTAssertEqual(reported, [])
        XCTAssertEqual(performed, [])
        XCTAssertEqual(errors.count, 0)
        // Without a router the page's own app scope goes with the fetch.
        XCTAssertEqual(stub.requests.count, 2)
        XCTAssertEqual(stub.requests.dropFirst().first.flatMap(RefetchStub.appState), ["visits": 1])
    }

    /// A host's `refetchPage` replaces the built-in, as any custom action
    /// named like a built-in does in Flutter (fixture
    /// 47_handler_overrides_builtin): it runs and nothing is fetched.
    func testA5_6_AHostRefetchPageHandlerWinsOverTheBuiltIn() async throws {
        let stub = RefetchStub([Self.page("first"), Self.page("second")])
        let ran = RanActions()
        let host = OrcaPluginHost(
            plugins: [], customActions: ["refetchPage": { [ran] action, _ in await ran.record(action) }],
            widgets: WidgetBuilders())
        let router = host.attach(OrcaRouter(client: stub.client, path: "home", system: SystemRecorder().actions()))
        let model = try await loaded(router.loader(for: router.root))

        try await refetch(model)

        let types = await ran.types
        XCTAssertEqual(types, ["refetchPage"])
        XCTAssertEqual(stub.requests.count, 1, "the host's handler fetches nothing")
        XCTAssertEqual(model.page.pageId, "first")
    }

    func testA5_6_FailedRefetchKeepsThePageAndThrowsOutOfTheAction() async throws {
        let stub = RefetchStub([Self.page("first", state: [["key": "count", "scope": "page", "initial": 0]])],
                               failingFrom: 2)
        let loader = OrcaPageLoader(client: stub.client, path: "home")
        let model = try await loaded(loader)
        model.store.dispatch(["count": 5], scope: .page)
        let revision = model.structureRevision
        var errors: [Error] = []
        model.onError = { errors.append($0) }

        do {
            try await model.executor.execute(.refetchPage)
            XCTFail("a failed refetch throws out of the action")
        } catch {
            XCTAssertEqual(error as? OrcaClientError, .http(status: 500, body: #"{"error":"down"}"#))
        }
        // Fired from a node, the error reaches onError as any action's does.
        try await refetch(model)
        XCTAssertEqual(errors.count, 1)

        XCTAssertEqual(stub.requests.count, 3)
        XCTAssertEqual(model.page.pageId, "first")
        XCTAssertEqual(model.store.pageId, "first")
        XCTAssertEqual(model.resolve("label")?["data"], "first")
        XCTAssertEqual(model.store.state.page, ["count": 5])
        XCTAssertEqual(model.structureRevision, revision)
        guard case .loaded(let after) = loader.phase else { return XCTFail("\(loader.phase)") }
        XCTAssertTrue(after === model)
    }
}
#endif
