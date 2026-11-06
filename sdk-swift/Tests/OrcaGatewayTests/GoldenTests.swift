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
/// with a small tolerance. Rendering is done by the simulator runtime, so each
/// golden records the iOS version it was made on (`<name>.runtime`) and the
/// test skips on any other runtime instead of failing on font noise. A missing
/// golden is recorded and the test fails once; set ORCA_RECORD_GOLDENS=1
/// (TEST_RUNNER_ORCA_RECORD_GOLDENS=1 through xcodebuild) to re-record.
@MainActor
final class GoldenTests: XCTestCase {
    static let size = CGSize(width: 393, height: 852)
    /// A pixel differs when a channel moves by more than this (0...255).
    static let channelTolerance = 48
    /// The test fails when more than this share of pixels differs: 0.01%,
    /// about 130 pixels. The same runtime renders the page pixel-identical
    /// (0.0); changing the count from 0 to 5 moves 0.095%.
    static let maxDifferingShare = 0.0001

    func testCounterPage() throws {
        let model = OrcaPageModel(page: try recordedPage("counter-home"))
        let image = render(NavigationStack { OrcaPageView(model: model) })
        try assertGolden(image, named: "counter-home")
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

    func assertGolden(_ image: UIImage, named name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let golden = swiftRoot.appendingPathComponent("Tests/Goldens/\(name).png")
        let runtimeFile = swiftRoot.appendingPathComponent("Tests/Goldens/\(name).runtime")
        let runtime = "iOS \(UIDevice.current.systemVersion)"
        let png = try XCTUnwrap(image.pngData())
        let record = ProcessInfo.processInfo.environment["ORCA_RECORD_GOLDENS"] == "1"
        guard !record, FileManager.default.fileExists(atPath: golden.path) else {
            try png.write(to: golden)
            try Data((runtime + "\n").utf8).write(to: runtimeFile)
            XCTFail("Recorded \(golden.path) on \(runtime); run the test again.", file: file, line: line)
            return
        }
        let recordedOn = (try? String(contentsOf: runtimeFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if recordedOn != runtime {
            throw XCTSkip("\(name) was recorded on \(recordedOn ?? "an unknown runtime"), this is \(runtime)")
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
