import XCTest

@testable import OrcaGatewayCore

/// T1.6: the generated caps vector advertises only widgets the manifest gives
/// the `ios` target, equals sdk-swift/capabilities.json, and Swift's
/// canonicalisation hashes exactly like the engine's.
final class CapabilitiesTests: XCTestCase {
    private func manifestIOSWidgets() throws -> Set<String> {
        let manifest = try Fixtures.json("schema/widget-registry.json")
        let widgets = manifest["widgets"].arrayValue ?? []
        XCTAssertEqual(widgets.count, 92)
        return Set(widgets.compactMap { w -> String? in
            let targets = (w["targets"].arrayValue ?? []).compactMap(\.stringValue)
            return targets.contains("ios") ? w["type"].stringValue : nil
        })
    }

    func testWidgetsAreIOSTargetsAndMatchTheImplementedList() throws {
        let ios = try manifestIOSWidgets()
        let advertised = Set(GeneratedCapabilities.widgets)
        XCTAssertTrue(advertised.isSubset(of: ios), "advertised without ios target: \(advertised.subtracting(ios))")

        let implemented = try Fixtures.json("sdk-swift/capabilities.json")
        let listed = Set((implemented["widgets"].arrayValue ?? []).compactMap(\.stringValue))
        XCTAssertEqual(advertised, listed.intersection(ios))
        XCTAssertEqual(advertised, listed)

        // The seven Material-only widgets are never advertised on iOS.
        for orphan in ["Checkbox", "Drawer", "FloatingActionButton", "InkWell", "Radio", "SnackBar", "Tooltip"] {
            XCTAssertFalse(ios.contains(orphan), "\(orphan) has the ios target")
            XCTAssertFalse(advertised.contains(orphan))
        }
    }

    func testActionKindsMatchTheImplementedList() throws {
        let implemented = try Fixtures.json("sdk-swift/capabilities.json")
        let listed = Set((implemented["actionKinds"].arrayValue ?? []).compactMap(\.stringValue))
        XCTAssertEqual(Set(GeneratedCapabilities.actionKinds), listed)
        XCTAssertTrue(listed.isSubset(of: Set(Action.kinds)))
        XCTAssertEqual(listed.count, 12)
    }

    func testValueKindsTransformsAndOpsAreComplete() {
        XCTAssertEqual(Set(GeneratedCapabilities.valueKinds), Set(Value.kinds))
        XCTAssertEqual(GeneratedCapabilities.transformKinds.count, 31)
        XCTAssertEqual(Set(GeneratedCapabilities.boolExprOps), Set(BoolExpr.ops))
    }

    func testSemverAndProtocolComeFromTheirFiles() throws {
        let version = try String(contentsOf: Fixtures.url("sdk-swift/VERSION"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(GeneratedCapabilities.sdkSemver, version)
        let proto = try Fixtures.json("schema/protocol.json")
        XCTAssertEqual(GeneratedCapabilities.protocolVersion, proto["protocolVersion"].stringValue)
    }

    func testHashMatchesTheEngineCanonicalisation() {
        // The generator hashed the vector with the engine's own
        // canonicalizeVector(); Swift must reach the same digest.
        XCTAssertEqual(CapabilityVector.current.hash, GeneratedCapabilities.capsHash)
    }

    func testPinnedEngineVector() {
        // engine/test/capability-vector-cache.test.ts "known pinned-hash" and
        // its snapshot; the Dart SDK pins the same value.
        let vector = CapabilityVector(
            protocolVersion: "1.0.0", sdkSemver: "0.1.0", widgets: ["b", "a"],
            valueKinds: ["static"], actionKinds: [], transformKinds: [], boolExprOps: [])
        XCTAssertEqual(
            vector.canonicalJSON(),
            #"{"protocolVersion":"1.0.0","sdkSemver":"0.1.0","widgets":["a","b"],"valueKinds":["static"],"actionKinds":[],"transformKinds":[],"boolExprOps":[]}"#)
        XCTAssertEqual(vector.hash, "c71ebd593604aa669274ce2d318d9d97b38facae6ca26360201907fda433db84")
    }

    func testCanonicalJSONEscapesLikeJSONStringify() {
        XCTAssertEqual(CapabilityVector.jsString("a/b"), #""a/b""#)
        XCTAssertEqual(CapabilityVector.jsString("q\"\\"), #""q\"\\""#)
        XCTAssertEqual(CapabilityVector.jsString("\n\u{1}é"), "\"\\n\\u0001é\"")
        // UTF-16 code-unit order, as Array.prototype.sort: "Z" < "a" < "é".
        let v = CapabilityVector(
            protocolVersion: "", sdkSemver: "", widgets: ["é", "a", "Z"], valueKinds: [],
            actionKinds: [], transformKinds: [], boolExprOps: [])
        XCTAssertTrue(v.canonicalJSON().contains(#""widgets":["Z","a","é"]"#))
    }

    func testSHA256KnownAnswers() {
        XCTAssertEqual(SHA256.hex([]), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(SHA256.hex(Array("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(
            SHA256.hex(Array("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
        XCTAssertEqual(
            SHA256.hex(Array(repeating: UInt8(ascii: "a"), count: 1000)),
            "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3")
    }
}
