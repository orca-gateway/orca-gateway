import XCTest

@testable import OrcaGatewayCore

/// A node under an AnimatedBuilder resolves its `tween` props by the
/// builder's progress; outside one they sit at the start.
final class AnimationProgressTests: XCTestCase {
    private let tween: JSONValue = ["type": "translate", "dx": ["type": "tween", "begin": 0, "end": -100]]

    private func renderer() -> PageRenderer {
        PageRenderer(page: PageResponse(pageId: "p", title: "P", components: [
            ComponentNode(id: "t", type: "Transform", kind: .layout, childMode: .single,
                          props: ["transform": tween], children: []),
        ]))
    }

    func testTweenInsideAPlainMapFollowsTheProgress() {
        let r = renderer()
        XCTAssertEqual(r.resolve("t", state: StoreState(), animationProgress: 0.25)?.props["transform"]?["dx"].doubleValue, -25)
        XCTAssertEqual(r.resolve("t", state: StoreState(), animationProgress: 1)?.props["transform"]?["dx"].doubleValue, -100)
    }

    func testWithoutABuilderTheTweenSitsAtItsBegin() {
        XCTAssertEqual(renderer().resolve("t", state: StoreState())?.props["transform"]?["dx"].doubleValue, 0)
    }
}
