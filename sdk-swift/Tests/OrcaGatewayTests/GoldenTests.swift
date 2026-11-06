#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import XCTest

@testable import OrcaGateway

/// T2.4: one golden of the counter page in a NavigationStack, 393x852 points
/// at 2x, light. Runs on an iOS simulator only (the macOS UI job).
///
/// The page is hosted in a UIKit window and its layer tree is rendered,
/// because SwiftUI's ImageRenderer cannot draw the navigation bar. Pixels are compared
/// with a small tolerance.
///
/// The picture depends on the toolchain as well as on the page: the simulator
/// runtime draws it, and SwiftUI picks layout metrics (bar height, button
/// padding) by the SDK the tests were built with. Xcode 16.4 and Xcode 27.2
/// draw this page 1 to 3 points apart on the same iOS 18.5 runtime. So each
/// golden is named after its toolchain, `<name>.sdk-<SDK>.ios-<runtime>.png`,
/// and the test skips on a toolchain that has none. CI pins Xcode 16.4 and
/// prefers iOS 18.5, so it always compares. Set ORCA_RECORD_GOLDENS=1
/// (TEST_RUNNER_ORCA_RECORD_GOLDENS=1 through xcodebuild) to record the golden
/// of the toolchain you run on.
@MainActor
final class GoldenTests: XCTestCase {
    static let size = CGSize(width: 393, height: 852)
    /// A pixel differs when a channel moves by more than this (0...255).
    static let channelTolerance = 48
    /// The test fails when more than this share of pixels differs: 0.01%,
    /// about 130 pixels. The same toolchain renders the page pixel-identical
    /// (0.0); changing the count from 0 to 5 moves 0.095%.
    static let maxDifferingShare = 0.0001

    func testCounterPage() throws {
        let model = OrcaPageModel(page: try recordedPage("counter-home"))
        let image = render(NavigationStack { OrcaPageView(model: model) })
        try assertGolden(image, named: "counter-home")
    }

    /// T4.1 and T4.2: the warn policy's banner over the page (with the
    /// Checkbox drawn as its own prompt) and the require policy's blocking
    /// prompt, in Flutter's colours.
    func testWarnPolicyPage() throws {
        let model = OrcaPageModel(page: try recordedPage("degrade-warn"), registry: WidgetRegistry())
        let image = render(NavigationStack { OrcaPageView(model: model) })
        try assertGolden(image, named: "degrade-warn")
    }

    func testRequirePolicyPage() throws {
        let model = OrcaPageModel(page: try recordedPage("degrade-require"))
        let image = render(NavigationStack { OrcaPageView(model: model) })
        try assertGolden(image, named: "degrade-require")
    }

    /// T4.4 and T4.5: the S4 demo page. Network images would make the
    /// picture depend on the network, so each Image's src is emptied and the
    /// box draws its "!" placeholder; layout, colours and icons stay.
    func testNativeWidgetsPage() throws {
        var page = try recordedPage("native-widgets-home")
        for index in page.components.indices where page.components[index].type == "Image" {
            page.components[index].props["src"] = ""
        }
        let model = OrcaPageModel(page: page)
        let image = render(NavigationStack { OrcaPageView(model: model) })
        try assertGolden(image, named: "native-widgets-home")
    }

    // MARK: rendering and comparison

    func render<V: View>(_ view: V) -> UIImage {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.size))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: Self.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(window.bounds)
            // drawHierarchy needs an on-screen window; a test bundle without a
            // host app has none, so render the layer tree instead.
            window.layer.render(in: context.cgContext)
        }
    }

    /// `sdk-<SDK>.ios-<runtime>`: the SDK this test bundle was built with
    /// (`DTPlatformVersion`, written by Xcode) and the simulator's iOS version.
    static var toolchain: String {
        let sdk = Bundle(for: GoldenTests.self).object(forInfoDictionaryKey: "DTPlatformVersion") as? String
        return "sdk-\(sdk ?? "unknown").ios-\(UIDevice.current.systemVersion)"
    }

    func assertGolden(_ image: UIImage, named name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let goldens = swiftRoot.appendingPathComponent("Tests/Goldens")
        let golden = goldens.appendingPathComponent("\(name).\(Self.toolchain).png")
        let png = try XCTUnwrap(image.pngData())
        if ProcessInfo.processInfo.environment["ORCA_RECORD_GOLDENS"] == "1" {
            try png.write(to: golden)
            XCTFail("Recorded \(golden.path); run the test again.", file: file, line: line)
            return
        }
        guard FileManager.default.fileExists(atPath: golden.path) else {
            let others = ((try? FileManager.default.contentsOfDirectory(atPath: goldens.path)) ?? [])
                .filter { $0.hasPrefix("\(name).") && $0.hasSuffix(".png") }.sorted()
            throw XCTSkip(
                "\(name) has no golden for \(Self.toolchain) (have: \(others.joined(separator: ", "))); "
                    + "record one with ORCA_RECORD_GOLDENS=1")
        }
        let expected = try XCTUnwrap(UIImage(contentsOfFile: golden.path))
        let share = try differingShare(image, expected)
        if share > Self.maxDifferingShare {
            let actualURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).actual.png")
            try png.write(to: actualURL)
            let attachment = XCTAttachment(image: image)
            attachment.name = "\(name).actual"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTFail(
                "\(name): \(String(format: "%.2f", share * 100))% of pixels differ "
                    + "(limit \(Self.maxDifferingShare * 100)%). Actual image: \(actualURL.path)",
                file: file, line: line)
        }
    }

    /// Share of pixels where any RGBA channel differs by more than the tolerance;
    /// 1 when the sizes differ.
    func differingShare(_ a: UIImage, _ b: UIImage) throws -> Double {
        let pa = try rgba(a)
        let pb = try rgba(b)
        guard pa.width == pb.width, pa.height == pb.height else { return 1 }
        var differing = 0
        let count = pa.width * pa.height
        for i in 0..<count {
            let o = i * 4
            for c in 0..<4 where abs(Int(pa.bytes[o + c]) - Int(pb.bytes[o + c])) > Self.channelTolerance {
                differing += 1
                break
            }
        }
        return Double(differing) / Double(max(count, 1))
    }

    func rgba(_ image: UIImage) throws -> (width: Int, height: Int, bytes: [UInt8]) {
        let cg = try XCTUnwrap(image.cgImage)
        let width = cg.width
        let height = cg.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw XCTSkip("could not read the image") }
        return (width, height, bytes)
    }
}
#endif
