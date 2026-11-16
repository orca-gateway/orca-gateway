import XCTest

@testable import OrcaGatewayCore

/// T1.6: the generated caps vector advertises only widgets the manifest gives
/// the `ios` target, equals sdk-swift/capabilities.json, and Swift's
/// canonicalisation hashes exactly like the engine's.
final class CapabilitiesTests: XCTestCase {
    private func manifestIOSWidgets() throws -> Set<String> {
        let manifest = try Fixtures.json("schema/widget-registry.json")
        let widgets = manifest["widgets"].arrayValue ?? []
        XCTAssertEqual(widgets.count, 93)
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

        // SnackBar and Tooltip have no ios target until native parity step 8,
        // so they are never advertised on iOS. Checkbox, Radio,
        // FloatingActionButton and InkWell, Epic 23b's other Material-only
        // four, take it in step 6 (design D2).
        for orphan in ["SnackBar", "Tooltip"] {
            XCTAssertFalse(ios.contains(orphan), "\(orphan) has the ios target")
            XCTAssertFalse(advertised.contains(orphan))
        }
        // Drawer now has the ios target.
        XCTAssertTrue(ios.contains("Drawer"), "Drawer lacks the ios target")
    }

    /// A3.1: native parity step 3's 13 layout wrappers are drawn by SwiftUI,
    /// so the generated vector advertises them, each once and sorted like
    /// capabilities.json. The pin is 89: with step 12's 5 animated widgets
    /// (49), then native parity step 4's 11 effect and touch wrappers (A4.x,
    /// 60), then step 13's ReorderableListView and SubPage, then S18's
    /// UnsupportedWidgetPlaceholder (63), then native parity step 5's five
    /// scroll widgets (A5.x, 68), then step 13's CustomScrollView and four
    /// sliver widgets (B13.1, B13.2, 73), then native parity step 6's nine
    /// form controls (A6.x, 82), then native parity step 7's seven rich
    /// widgets (A7.x).
    func testA3_1TheThirteenLayoutWrappersAreAdvertisedEightyNineInAll() throws {
        let advertised = Set(GeneratedCapabilities.widgets)
        XCTAssertEqual(Self.a3_1.subtracting(advertised), [], "not advertised")
        XCTAssertTrue(Self.a3_1.isSubset(of: try manifestIOSWidgets()), "a wrapper lacks the ios target")
        XCTAssertEqual(GeneratedCapabilities.widgets.count, 89)
        XCTAssertEqual(advertised.count, 89)
        XCTAssertEqual(GeneratedCapabilities.widgets, GeneratedCapabilities.widgets.sorted())
    }

    /// Native parity step 3's layout wrappers (A3.1).
    static let a3_1: Set<String> = [
        "Align", "AspectRatio", "Baseline", "ConstrainedBox", "FittedBox", "Flexible",
        "FractionallySizedBox", "IntrinsicHeight", "IntrinsicWidth", "LimitedBox", "Offstage",
        "SafeArea", "Wrap",
    ]

    /// A4.x: native parity step 4's 11 effect and touch wrappers are drawn by
    /// SwiftUI, so capabilities.json lists each of them and the generated
    /// vector advertises each, once, every one carrying the manifest's ios
    /// target.
    func testA4TheElevenEffectAndTouchWrappersAreAdvertised() throws {
        let implemented = try Fixtures.json("sdk-swift/capabilities.json")
        let listed = Set((implemented["widgets"].arrayValue ?? []).compactMap(\.stringValue))
        XCTAssertEqual(Self.a4.subtracting(listed), [], "not in capabilities.json")
        for wrapper in Self.a4.sorted() {
            XCTAssertEqual(GeneratedCapabilities.widgets.filter { $0 == wrapper }.count, 1,
                           "\(wrapper) is not advertised exactly once")
        }
        XCTAssertTrue(Self.a4.isSubset(of: try manifestIOSWidgets()), "a wrapper lacks the ios target")
    }

    /// Native parity step 4's effect and touch wrappers (A4.1-A4.5).
    static let a4: Set<String> = [
        "AbsorbPointer", "BackdropFilter", "BlurView", "ClipOval", "ClipRect", "ColorFiltered",
        "DecoratedBox", "IgnorePointer", "InteractiveViewer", "Opacity", "RotatedBox",
    ]

    /// C18.4: S18 adds UnsupportedWidgetPlaceholder. It has the ios target,
    /// is advertised, and the registry the SDK draws with knows it, so a
    /// page's placeholder is not degraded to FallbackPrompt.
    func testC18_4_UnsupportedWidgetPlaceholderIsAdvertisedAndTheStandardRegistryKnowsIt() throws {
        let ios = try manifestIOSWidgets()
        XCTAssertTrue(ios.contains("UnsupportedWidgetPlaceholder"), "UnsupportedWidgetPlaceholder lacks the ios target")
        XCTAssertTrue(GeneratedCapabilities.widgets.contains("UnsupportedWidgetPlaceholder"), "not advertised")
        XCTAssertTrue(WidgetRegistry.shared.supports("UnsupportedWidgetPlaceholder"), "the standard registry degrades it")
    }

    /// A5.x: native parity step 5's five scroll widgets are drawn by SwiftUI
    /// (A5.1-A5.5, A5.7), so capabilities.json lists each of them, the
    /// generated vector advertises each, once, every one carrying the
    /// manifest's ios target, and the standard registry lets them through.
    func testA5TheFiveScrollWidgetsAreAdvertised() throws {
        let implemented = try Fixtures.json("sdk-swift/capabilities.json")
        let listed = Set((implemented["widgets"].arrayValue ?? []).compactMap(\.stringValue))
        XCTAssertEqual(Self.a5.subtracting(listed), [], "not in capabilities.json")
        for widget in Self.a5.sorted() {
            XCTAssertEqual(GeneratedCapabilities.widgets.filter { $0 == widget }.count, 1,
                           "\(widget) is not advertised exactly once")
        }
        XCTAssertTrue(Self.a5.isSubset(of: try manifestIOSWidgets()), "a widget lacks the ios target")
        XCTAssertEqual(Self.a5.subtracting(WidgetRegistry.shared.types), [], "degraded by the standard registry")
    }

    /// Native parity step 5's scroll widgets (A5.1-A5.5, A5.7).
    static let a5: Set<String> = ["GridView", "ListView", "PageView", "PullToRefresh", "Scrollbar"]

    /// A6.x: native parity step 6's nine form controls are drawn by SwiftUI
    /// (A6.1-A6.7), so capabilities.json lists each of them, the generated
    /// vector advertises each, once, every one carrying the manifest's ios
    /// target, and the standard registry lets them through.
    func testA6_xAdvertisesTheNineFormControls() throws {
        let implemented = try Fixtures.json("sdk-swift/capabilities.json")
        let listed = Set((implemented["widgets"].arrayValue ?? []).compactMap(\.stringValue))
        XCTAssertEqual(Self.a6.subtracting(listed), [], "not in capabilities.json")
        for widget in Self.a6.sorted() {
            XCTAssertEqual(GeneratedCapabilities.widgets.filter { $0 == widget }.count, 1,
                           "\(widget) is not advertised exactly once")
        }
        XCTAssertEqual(Self.a6.subtracting(try manifestIOSWidgets()), [], "a widget lacks the ios target")
        XCTAssertEqual(Self.a6.subtracting(WidgetRegistry.shared.types), [], "degraded by the standard registry")
    }

    /// Native parity step 6's form controls (A6.1-A6.7).
    static let a6: Set<String> = [
        "Checkbox", "FloatingActionButton", "Form", "IconButton", "InkWell", "Radio", "Slider",
        "Switch", "TextFormField",
    ]

    /// A7.x: native parity step 7's seven rich widgets are drawn by SwiftUI
    /// (A7.1-A7.4: RichText, SelectableText, DefaultTextStyle, ImageIcon,
    /// the two progress indicators, Table), so capabilities.json lists each
    /// of them, the generated vector advertises each, once, every one
    /// carrying the manifest's ios target, and the standard registry lets
    /// them through.
    func testA7_xAdvertisesTheSevenRichWidgets() throws {
        let implemented = try Fixtures.json("sdk-swift/capabilities.json")
        let listed = Set((implemented["widgets"].arrayValue ?? []).compactMap(\.stringValue))
        XCTAssertEqual(Self.a7.subtracting(listed), [], "not in capabilities.json")
        for widget in Self.a7.sorted() {
            XCTAssertEqual(GeneratedCapabilities.widgets.filter { $0 == widget }.count, 1,
                           "\(widget) is not advertised exactly once")
        }
        XCTAssertEqual(Self.a7.subtracting(try manifestIOSWidgets()), [], "a widget lacks the ios target")
        XCTAssertEqual(Self.a7.subtracting(WidgetRegistry.shared.types), [], "degraded by the standard registry")
    }

    /// Native parity step 7's rich widgets (A7.1-A7.4).
    static let a7: Set<String> = [
        "CircularProgressIndicator", "DefaultTextStyle", "ImageIcon", "LinearProgressIndicator",
        "RichText", "SelectableText", "Table",
    ]

    func testActionKindsMatchTheImplementedList() throws {
        let implemented = try Fixtures.json("sdk-swift/capabilities.json")
        let listed = Set((implemented["actionKinds"].arrayValue ?? []).compactMap(\.stringValue))
        XCTAssertEqual(Set(GeneratedCapabilities.actionKinds), listed)
        XCTAssertTrue(listed.isSubset(of: Set(Action.kinds)))
        // 23 before step 5's refetchPage (A5.6), 24 before step 14's persistState and clearState.
        XCTAssertEqual(listed.count, 26)
        XCTAssertTrue(listed.isSuperset(of: ["switchTab", "openDrawer"]))
        XCTAssertTrue(listed.isSuperset(of: ["once", "always", "debugLog"]))
        XCTAssertTrue(listed.contains("updateSubPage"))
        // C14.6 (S8): native parity step 14 advertises the saved-state pair.
        XCTAssertTrue(listed.isSuperset(of: ["persistState", "clearState"]))
        XCTAssertEqual(GeneratedCapabilities.actionKinds, GeneratedCapabilities.actionKinds.sorted())
        // The executor runs exactly what is advertised, plus the server-only
        // replaceComponent (not in action.ts, so never advertised).
        XCTAssertEqual(ActionExecutor.kinds, listed.union(["replaceComponent"]))
    }

    /// A5.6: refetchPage is advertised and the executor runs it as a known
    /// kind (the page model's handler, else nothing, as Flutter awaits a null
    /// onRefetchPage), so the engine keeps a PullToRefresh whose onRefresh is
    /// RefetchPage (capability-filter.ts drops a node whose action kind is
    /// not advertised).
    func testA5_6_RefetchPageIsAdvertisedAndKnownToTheExecutor() throws {
        let implemented = try Fixtures.json("sdk-swift/capabilities.json")
        let listed = (implemented["actionKinds"].arrayValue ?? []).compactMap(\.stringValue)
        XCTAssertTrue(listed.contains("refetchPage"), "not in capabilities.json")
        XCTAssertEqual(listed, listed.sorted(), "capabilities.json actionKinds unsorted")
        XCTAssertEqual(GeneratedCapabilities.actionKinds.filter { $0 == "refetchPage" }.count, 1,
                       "refetchPage is not advertised exactly once")
        XCTAssertEqual(GeneratedCapabilities.actionKinds, GeneratedCapabilities.actionKinds.sorted())
        XCTAssertTrue(ActionExecutor.kinds.contains("refetchPage"))
        XCTAssertTrue(ActionExecutor.implements(.refetchPage))
        XCTAssertTrue(ActionExecutor.implements(.always(.init(action: .once(.init(action: .refetchPage))))))
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
