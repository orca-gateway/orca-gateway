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
/// fires the node's action, commits the state and shows the toast.
@MainActor
final class PageModelTests: XCTestCase {
    func testTapsCountAndResetShowsTheSnackbar() throws {
        let model = OrcaPageModel(page: try recordedPage("counter-home"))
        XCTAssertEqual(model.store.value("count"), 0)

        let plus = try XCTUnwrap(model.resolve("11"))
        XCTAssertEqual(model.resolve(plus.childIds[0])?["data"], "+")
        model.fire("onTap", on: plus)
        model.fire("onTap", on: plus)
        XCTAssertEqual(model.store.value("count"), 2)
        XCTAssertEqual(model.resolve("5")?["data"], "2")
        XCTAssertNil(model.toast)

        let reset = try XCTUnwrap(model.resolve("14"))
        model.fire("onTap", on: reset)
        XCTAssertEqual(model.store.value("count"), 0)
        XCTAssertEqual(model.toast?.message, "Counter reset to 0")
        XCTAssertEqual(model.toast?.duration, 4)
        XCTAssertEqual(model.toast?.style, .snackbar)
    }

    func testOnlyWatchingNodesSubscribe() throws {
        let model = OrcaPageModel(page: try recordedPage("counter-home"))
        let count = NodeObserver(model: model, id: "5")
        let title = NodeObserver(model: model, id: "2")
        XCTAssertEqual(model.store.subscriberCount, 1)

        model.fire("onTap", on: try XCTUnwrap(model.resolve("11")))
        XCTAssertEqual(count.revision, 1)
        XCTAssertEqual(title.revision, 0)
    }

    func testMissingTriggerDoesNothing() throws {
        let model = OrcaPageModel(page: try recordedPage("counter-home"))
        model.fire("onLongPress", on: try XCTUnwrap(model.resolve("11")))
        XCTAssertEqual(model.store.value("count"), 0)
    }

    func testOtherEffectsGoToTheHost() {
        let model = OrcaPageModel(page: PageResponse(pageId: "p", title: "P"))
        var seen: [ActionEffect] = []
        model.onEffect = { seen.append($0) }
        model.perform(ActionEffect("navigate", ["route": "/next"]))
        XCTAssertEqual(seen, [ActionEffect("navigate", ["route": "/next"])])
        XCTAssertNil(model.toast)
    }
}
#endif
