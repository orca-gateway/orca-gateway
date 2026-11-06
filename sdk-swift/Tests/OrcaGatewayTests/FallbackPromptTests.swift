#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// T4.1: a FallbackPrompt's call to action goes through the URL policy, as
/// Flutter's (`OrcaUrlPolicy.isAllowed`, then `launchUrl`). The colours are
/// pinned by the warn and require goldens (GoldenTests, iOS only).
@MainActor
final class FallbackPromptTests: XCTestCase {
    func model() throws -> OrcaPageModel {
        OrcaPageModel(page: try recordedPage("degrade-require"))
    }

    func testAnAllowedLinkGoesOutAsAnOpenUrlEffect() throws {
        let model = try model()
        var effects: [ActionEffect] = []
        model.effectHandler = { effects.append($0) }
        var opened: [URL] = []

        model.openLink("https://apps.apple.com/app/id000000000") { opened.append($0) }

        XCTAssertEqual(effects, [ActionEffect("openUrl", ["url": "https://apps.apple.com/app/id000000000"])])
        XCTAssertEqual(opened, [])
    }

    func testABlockedSchemeDoesNothing() throws {
        let model = try model()
        var effects: [ActionEffect] = []
        model.effectHandler = { effects.append($0) }
        var opened: [URL] = []

        for raw in ["javascript:alert(1)", "file:///etc/hosts", "tel:123", "not a url"] {
            model.openLink(raw) { opened.append($0) }
        }

        XCTAssertEqual(effects, [])
        XCTAssertEqual(opened, [])
    }

    func testWithoutARouterTheLinkOpensDirectly() throws {
        let model = try model()
        var opened: [URL] = []

        model.openLink("mailto:help@example.com") { opened.append($0) }

        XCTAssertEqual(opened, [URL(string: "mailto:help@example.com")!])
    }

    func testUnderTheRouterTheSystemOpensIt() throws {
        let recorder = SystemRecorder()
        let router = OrcaRouter(
            client: OrcaClient(baseURL: URL(string: "http://localhost:8080")!, appId: "a"),
            path: "home", system: recorder.actions())
        let model = try model()
        router.attach(model)

        model.openLink("https://example.com/whats-new") { _ in XCTFail("the router opens it") }

        XCTAssertEqual(recorder.opened, [URL(string: "https://example.com/whats-new")!])
    }
}
#endif
