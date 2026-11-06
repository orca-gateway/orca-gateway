import Foundation
import XCTest

@testable import OrcaGatewayCore

/// T4.2: the three fallback policies and the 426 gate, on pages a real engine
/// produced for the Swift caps vector (`t sdk-swift:record`, the
/// capability-demo `degrade` page with a Checkbox iOS lacks). The engine
/// shapes are pinned by engine/test/caps-policy-e2e.test.ts; these tests pin
/// what the Swift renderer makes of them.
final class DegradeTests: XCTestCase {
    func recorded(_ name: String) throws -> Data {
        try Fixtures.data("sdk-swift/Tests/Pages/\(name).json")
    }

    func tree(_ name: String) throws -> RenderNode {
        let page = try JSONDecoder().decode(PageResponse.self, from: try recorded(name))
        let renderer = PageRenderer(page: page, registry: WidgetRegistry())
        let store = ElmStore()
        store.seed(page.state)
        return try XCTUnwrap(renderer.tree(state: store.state))
    }

    func texts(_ tree: RenderNode) -> [String] {
        tree.all.filter { $0.type == "Text" }.compactMap { $0.props["data"]?.stringValue }
    }

    func testGracefulStripsTheNodeAndKeepsItsSiblings() throws {
        let tree = try tree("degrade-graceful")
        XCTAssertEqual(tree.type, "Scaffold")
        XCTAssertNil(tree.first { $0.type == "Checkbox" || $0.type == "FallbackPrompt" })
        let column = try XCTUnwrap(tree.first { $0.type == "Column" })
        XCTAssertEqual(column.children.map { $0.props["data"]?.stringValue },
                       ["Above the checkbox.", "Below the checkbox."])
    }

    func testWarnPrependsABannerAndKeepsThePage() throws {
        let tree = try tree("degrade-warn")
        XCTAssertEqual(tree.id, "__caps_warn_root__")
        XCTAssertEqual(tree.type, "Column")
        XCTAssertEqual(tree.children.map(\.id), ["__caps_warn_banner__", "0"])
        let banner = tree.children[0]
        XCTAssertEqual(banner.type, "FallbackPrompt")
        XCTAssertEqual(banner.props["severity"], "warn")
        XCTAssertEqual(banner.props["title"], "Some content needs an update")
        XCTAssertEqual(tree.children[1].type, "Scaffold")
        // warn keeps the authored tree, Checkbox included; the client then
        // draws it as its own "Unsupported content" prompt, as Flutter does.
        let checkbox = try XCTUnwrap(tree.first { $0.node.degradedFrom == "Checkbox" })
        XCTAssertEqual(checkbox.type, "FallbackPrompt")
        XCTAssertEqual(checkbox.props["title"], "Unsupported content")
        XCTAssertEqual(texts(tree).filter { $0.hasSuffix("checkbox.") },
                       ["Above the checkbox.", "Below the checkbox."])
    }

    func testRequireReplacesThePageWithOneBlockingPrompt() throws {
        let tree = try tree("degrade-require")
        XCTAssertEqual(tree.all.count, 1)
        XCTAssertEqual(tree.id, "__caps_block_root__")
        XCTAssertEqual(tree.type, "FallbackPrompt")
        XCTAssertEqual(tree.props["severity"], "blocking")
        XCTAssertEqual(tree.props["title"], "Update required")
    }

    func testA426DrawsTheUpgradePageItCarries() async throws {
        let engine = StubEngine(page: Data())
        engine.forced = HTTPResponse(status: 426, body: try recorded("degrade-426"))
        let client = OrcaClient(baseURL: URL(string: "http://localhost:8080")!, appId: "capability-demo",
                                transport: engine)

        let page = try await client.fetchPage("degrade")

        XCTAssertEqual(page.title, "Update required")
        XCTAssertEqual(page.components.map(\.id), ["__min_sdk_block_root__"])
        let root = try XCTUnwrap(page.components.first)
        XCTAssertEqual(root.type, "FallbackPrompt")
        XCTAssertEqual(root.props["severity"], "blocking")
        XCTAssertEqual(root.props["body"]?.stringValue,
                       "This app needs version 99.0.0 or later to continue. Please update from your app store.")
    }

    func testA426WithoutAPageStaysAnError() async throws {
        let engine = StubEngine(page: Data())
        let body = Data(#"{"error":"sdk_version_too_old"}"#.utf8)
        engine.forced = HTTPResponse(status: 426, body: body)
        let client = OrcaClient(baseURL: URL(string: "http://localhost:8080")!, appId: "a", transport: engine)
        do {
            _ = try await client.fetchPage("home")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? OrcaClientError,
                           .http(status: 426, body: #"{"error":"sdk_version_too_old"}"#))
        }
    }

    func testAnotherStatusWithAPageStaysAnError() async throws {
        let engine = StubEngine(page: Data())
        engine.forced = HTTPResponse(status: 500, body: try recorded("degrade-426"))
        let client = OrcaClient(baseURL: URL(string: "http://localhost:8080")!, appId: "a", transport: engine)
        do {
            _ = try await client.fetchPage("home")
            XCTFail("expected an error")
        } catch {
            guard case .http(let status, _)? = error as? OrcaClientError else {
                return XCTFail("unexpected \(error)")
            }
            XCTAssertEqual(status, 500)
        }
    }
}
