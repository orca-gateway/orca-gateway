#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// sdk-swift/ (this file is sdk-swift/Tests/OrcaGatewayTests/).
let swiftRoot: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

func recordedPage(_ name: String) throws -> PageResponse {
    let url = swiftRoot.appendingPathComponent("Tests/Pages/\(name).json")
    return try JSONDecoder().decode(PageResponse.self, from: Data(contentsOf: url))
}

/// What the views do with a tap, without tapping through SwiftUI: the model
/// runs the node's action, commits the state and shows the toast.
@MainActor
final class PageModelTests: XCTestCase {
    func testTapsCountAndResetShowsTheSnackbar() async throws {
        let model = OrcaPageModel(page: try recordedPage("counter-home"))
        XCTAssertEqual(model.store.value("count"), 0)

        let plus = try XCTUnwrap(model.resolve("11"))
        XCTAssertEqual(model.resolve(plus.childIds[0])?["data"], "+")
        await model.fire("onTap", on: plus)?.value
        await model.fire("onTap", on: plus)?.value
        XCTAssertEqual(model.store.value("count"), 2)
        XCTAssertEqual(model.resolve("5")?["data"], "2")
        XCTAssertNil(model.toast)

        let reset = try XCTUnwrap(model.resolve("14"))
        await model.fire("onTap", on: reset)?.value
        XCTAssertEqual(model.store.value("count"), 0)
        XCTAssertEqual(model.toast?.message, "Counter reset to 0")
        XCTAssertEqual(model.toast?.duration, 4)
        XCTAssertEqual(model.toast?.style, .snackbar)
    }

    func testOnlyWatchingNodesSubscribe() async throws {
        let model = OrcaPageModel(page: try recordedPage("counter-home"))
        let count = NodeObserver(model: model, id: "5")
        let title = NodeObserver(model: model, id: "2")
        XCTAssertEqual(model.store.subscriberCount, 1)

        await model.fire("onTap", on: try XCTUnwrap(model.resolve("11")))?.value
        XCTAssertEqual(count.revision, 1)
        XCTAssertEqual(title.revision, 0)
    }

    func testMissingTriggerDoesNothing() throws {
        let model = OrcaPageModel(page: try recordedPage("counter-home"))
        XCTAssertNil(model.fire("onLongPress", on: try XCTUnwrap(model.resolve("11"))))
        XCTAssertEqual(model.store.value("count"), 0)
    }

    func testNavigationAndSystemEffectsGoToTheHandler() async {
        let model = OrcaPageModel(page: PageResponse(pageId: "p", title: "P"))
        var reported: [ActionEffect] = []
        var handled: [ActionEffect] = []
        model.onEffect = { reported.append($0) }
        model.effectHandler = { handled.append($0) }
        await model.run(.actionGroup(.init(actions: [
            .navigate(.init(route: "/next")), .showToast(.init(message: "hi")),
        ])))
        XCTAssertEqual(handled, [ActionEffect("navigate", ["route": "/next", "replace": false])])
        XCTAssertEqual(reported.map(\.type), ["navigate", "showToast"])
        XCTAssertEqual(model.toast?.message, "hi")
    }

    func testAThrownActionIsReportedNotRaised() async {
        let model = OrcaPageModel(page: PageResponse(pageId: "p", title: "P"),
                                  client: PageStub.client(PageStub(actionBody: "not json")))
        var errors: [Error] = []
        model.onError = { errors.append($0) }
        await model.run(.serverAction(.init(id: "boom")))
        XCTAssertEqual(errors.count, 1)
    }

    /// T3.2: a server action's component kinds edit the tree and every node
    /// redraws. Watches stay what the server sent, as in Dart's
    /// `ComponentStore.updateComponent`.
    func testMutationsRedrawTheTree() async throws {
        let model = OrcaPageModel(page: try recordedPage("counter-home"))
        let title = NodeObserver(model: model, id: "2")

        model.apply(.update(id: "2", props: [
            "data": ["type": "state", "scope": "page", "key": "count"],
        ]))
        XCTAssertEqual(model.structureRevision, 1)
        XCTAssertEqual(title.revision, 1)
        XCTAssertEqual(model.resolve("2")?["data"], 0)
        XCTAssertEqual(model.store.subscriberCount, 0)

        model.apply(.delete(id: "14"))
        XCTAssertNil(model.resolve("14"))
        XCTAssertFalse(model.resolve("4")?.childIds.contains("14") ?? true)
        XCTAssertEqual(title.revision, 2)
    }
}
#endif
