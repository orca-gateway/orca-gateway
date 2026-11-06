import XCTest

@testable import OrcaGatewayCore

/// T1.2: for every render fixture with a `resolved` map, resolving each listed
/// prop against the fixture's app+page state gives the pinned value. Same
/// procedure as sdk/test/conformance/render_resolved_test.dart.
final class ResolverFixtureTests: XCTestCase {
    func testResolvedMapsMatch() throws {
        var covered: [String] = []
        for (name, fixture) in try Fixtures.files("render") {
            guard case .object(let resolved) = fixture["resolved"] else { continue }
            covered.append(name)
            let context = fixture["context"]
            let resolver = ValueResolver(
                page: context["pageState"].objectValue ?? [:],
                app: context["appState"].objectValue ?? [:])
            let nodes = try decodeModel([ComponentNode].self, from: fixture["expected"])
            let byId = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

            for (id, props) in resolved {
                guard let node = byId[id] else {
                    XCTFail("\(name): node \(id) missing")
                    continue
                }
                for (prop, expected) in props.objectValue ?? [:] {
                    let got = resolver.resolveDeep(node.props[prop] ?? .null)
                    assertJSONEqual(got, expected, "\(name) \(id).\(prop)")
                }
            }
        }
        // 03, 05, 06, 09, 18, 22 carry resolved maps (S0, 23b.6).
        XCTAssertGreaterThanOrEqual(covered.count, 6, "\(covered)")
    }

    func testTweenFixtureResolvesAtBothEnds() throws {
        // Fixture 24 has no resolved map (it needs animation progress); pin
        // its value at progress 0 and 1 from the Dart semantics instead.
        let fixture = try Fixtures.json("schema/fixtures/render/24_tween_transform.json")
        let node = try decodeModel([ComponentNode].self, from: fixture["expected"])[0]
        let data = node.props["data"] ?? .null
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 0).resolve(data), .int(0))
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 1).resolve(data), .int(42))
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 0.5).resolve(data), .int(21))
    }
}
