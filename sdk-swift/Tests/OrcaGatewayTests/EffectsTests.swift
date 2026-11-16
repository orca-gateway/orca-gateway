#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A4.1, A4.2 and the ColorFiltered half of A4.3: Opacity, RotatedBox,
/// ClipRect, ClipOval, DecoratedBox and ColorFiltered as the Flutter
/// builders make them (layout_builders.dart :288-293, :523-550, :426-432),
/// checked by ImageRenderer pixels (premultiplied RGBA, `Pixels`) around
/// sized children, and their taps in a hosted window with a UIKit text
/// field as the probe (iOS).
@MainActor
final class EffectsTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: Opacity (A4.1)

    /// A4.1: Opacity 0.5 draws a red 40x20 at half alpha over a transparent
    /// canvas (premultiplied, so red reads half too), and nothing outside;
    /// at 0 it draws nothing.
    func testA4_1OpacityHalfDrawsItsChildHalfTransparent() throws {
        let pixels = try draw([node("o", "Opacity", ["opacity": 0.5], ["red"]), box("red", "#FF0000", 40, 20)],
                              width: 60, height: 40)
        assertPixel(pixels.pixel(20, 10), (128, 0, 0, 128), "the child at half alpha")
        assertFrame(pixels.bounds { $0.a > 0 }, CGRect(x: 0, y: 0, width: 40, height: 20))

        let hidden = try draw([node("o", "Opacity", ["opacity": 0], ["red"]), box("red", "#FF0000", 40, 20)],
                              width: 60, height: 40, page: Self.blue)
        assertPixel(hidden.pixel(20, 10), (0, 0, 255, 255), "the child at opacity 0 is drawn")
    }

    /// A4.1: with no `opacity` the child is drawn opaque (Flutter's 1).
    func testA4_1OpacityDefaultsToOpaque() throws {
        let pixels = try draw([node("o", "Opacity", [:], ["red"]), box("red", "#FF0000", 40, 20)],
                              width: 60, height: 40)
        assertPixel(pixels.pixel(20, 10), (255, 0, 0, 255), "the child opaque")
    }

    // MARK: RotatedBox (A4.1)

    /// A4.1: one quarter turn lays a 60x20 box out as 20x60: a sibling
    /// below it starts at 60, and the box is turned clockwise about its
    /// centre (its red left half is on top).
    func testA4_1RotatedBoxOneQuarterTurnSwapsWidthAndHeight() throws {
        let pixels = try rotated(1)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 20, height: 30))
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 0, y: 30, width: 20, height: 30))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 0, y: 60, width: 20, height: 10))

        let model = try model(rotatedNodes(1))
        let frames = NativeWidgetTests().layout(width: 100, height: 100) {
            NodeView(id: "rb", model: model).record("rb")
        }
        assertFrame(frames["rb"], CGRect(x: 0, y: 0, width: 20, height: 60))
    }

    /// A4.1: two turns keep the 60x20 size (red now on the right), three
    /// turns swap it again (red at the bottom), as do -1 (Dart's
    /// `quarterTurns % 4` is 3); none or 0 leave the box as it is.
    func testA4_1RotatedBoxTwoTurnsKeepTheSizeAndThreeSwapIt() throws {
        let two = try rotated(2)
        assertFrame(two.bounds(of: Pixels.isRed), CGRect(x: 30, y: 0, width: 30, height: 20))
        assertFrame(two.bounds(of: Self.isBlue), CGRect(x: 0, y: 0, width: 30, height: 20))
        assertFrame(two.bounds(of: Self.isGreen), CGRect(x: 0, y: 20, width: 20, height: 10))

        for turns in [3, -1] {
            let three = try rotated(turns)
            assertFrame(three.bounds(of: Pixels.isRed), CGRect(x: 0, y: 30, width: 20, height: 30))
            assertFrame(three.bounds(of: Self.isBlue), CGRect(x: 0, y: 0, width: 20, height: 30))
            assertFrame(three.bounds(of: Self.isGreen), CGRect(x: 0, y: 60, width: 20, height: 10))
        }

        for turns in [nil, 0] as [Int?] {
            let none = try rotated(turns)
            assertFrame(none.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 30, height: 20))
            assertFrame(none.bounds(of: Self.isBlue), CGRect(x: 30, y: 0, width: 30, height: 20))
            assertFrame(none.bounds(of: Self.isGreen), CGRect(x: 0, y: 20, width: 20, height: 10))
        }
    }

    /// A4.1: with no child a RotatedBox is the smallest size its parent
    /// allows (RenderRotatedBox `constraints.smallest`): zero where the
    /// parent leaves it free, so a sibling below it starts at the top, and
    /// the forced size where the parent forces one.
    func testA4_1RotatedBoxWithNoChildIsTheSmallestSize() throws {
        let nodes = [
            node("col", "Column", ["crossAxisAlignment": "start"], ["rb", "below"]),
            node("rb", "RotatedBox", ["quarterTurns": 1]),
            box("below", "#00FF00", 20, 10),
        ]
        let model = try model(nodes)
        let frames = NativeWidgetTests().layout(width: 100, height: 100) {
            NodeView(id: "col", model: model).record("col")
        }
        XCTAssertNotNil(frames["col"], "the page was not laid out")
        assertFrame(try draw(nodes, width: 100, height: 100).bounds(of: Self.isGreen),
                    CGRect(x: 0, y: 0, width: 20, height: 10))
        let alone = NativeWidgetTests().layout(width: 100, height: 100) {
            NodeView(id: "rb", model: model).record("rb")
        }
        XCTAssertEqual(alone["rb"]?.size ?? .zero, .zero, "a RotatedBox with no child takes room")
        let forced = NativeWidgetTests().layout(width: 100, height: 70) {
            NodeView(id: "rb", model: model).environment(\.orcaTight, [.horizontal, .vertical]).record("rb")
        }
        XCTAssertEqual(forced["rb"]?.size, CGSize(width: 100, height: 70), "not the forced size")
    }

    /// A4.1: the child is laid out within the flipped limits, unbounded
    /// axes included: a 60x150 Container turned once in a Column 100 wide
    /// (a SizedBox in a wider canvas) is offered at most 100 on its height
    /// (the Column's width), so Flutter clamps it to 60x100 and the
    /// RotatedBox is 100x60, not 150 wide; a sibling below starts at 60.
    func testA4_1RotatedBoxLaysItsChildOutWithinTheFlippedLimits() throws {
        let nodes = [
            node("narrow", "SizedBox", ["width": 100], ["col"]),
            node("col", "Column", ["crossAxisAlignment": "start"], ["rb", "below"]),
            node("rb", "RotatedBox", ["quarterTurns": 1], ["tall"]),
            box("tall", "#FF0000", 60, 150),
            box("below", "#00FF00", 20, 10),
        ]
        let pixels = try draw(nodes, width: 200, height: 300)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 100, height: 60))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 0, y: 60, width: 20, height: 10))
    }

    // MARK: ClipRect and ClipOval (A4.2)

    /// A4.2: an 80x80 red Container hanging 20 past every side of a 40x40
    /// box (a Stack sized by a SizedBox, its Positioned child at -20, -20)
    /// is cut to that box by a ClipRect, 20 in from the canvas's corner.
    func testA4_2ClipRectCutsOverflowToItsBox() throws {
        let open = try draw(clipped(nil), width: 120, height: 120)
        assertFrame(open.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 80, height: 80))

        let pixels = try draw(clipped("ClipRect"), width: 120, height: 120)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 20, y: 20, width: 40, height: 40))
        assertFrame(pixels.bounds { $0.a > 0 }, CGRect(x: 20, y: 20, width: 40, height: 40))
        for (x, y) in [(20, 20), (59, 20), (20, 59), (59, 59)] {
            XCTAssertTrue(Pixels.isRed(pixels.pixel(x, y)), "corner (\(x), \(y)) is \(pixels.pixel(x, y))")
        }
    }

    /// A4.2: a ClipOval cuts the same overflow to the ellipse inscribed in
    /// its 40x40 box: the box's corners are clear, its centre and the
    /// middle of each side red.
    func testA4_2ClipOvalCutsToTheInscribedEllipse() throws {
        let pixels = try draw(clipped("ClipOval"), width: 120, height: 120)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 20, y: 20, width: 40, height: 40))
        for (x, y) in [(21, 21), (58, 21), (21, 58), (58, 58), (24, 24), (55, 55)] {
            XCTAssertEqual(pixels.pixel(x, y).a, 0, "corner (\(x), \(y)) is \(pixels.pixel(x, y)), not clear")
        }
        for (x, y) in [(40, 40), (40, 21), (21, 40), (58, 40), (40, 58)] {
            XCTAssertTrue(Pixels.isRed(pixels.pixel(x, y)), "(\(x), \(y)) is \(pixels.pixel(x, y)), not red")
        }
    }

    // MARK: DecoratedBox (A4.2)

    /// A4.2: a DecoratedBox with a blue fill and a red border 4 wide around
    /// a 60x40 Container (a green 30x20 at its top left) is exactly 60x40:
    /// the child is not inset by the border (unlike a Container), and the
    /// decoration is drawn behind it, the border showing only where the
    /// child leaves it free.
    func testA4_2DecoratedBoxIsItsChildsSizeWithNoBorderInset() throws {
        let nodes = decorated([:])
        let model = try model(nodes)
        let frames = NativeWidgetTests().layout(width: 100, height: 100) {
            NodeView(id: "deco", model: model).record("deco")
        }
        assertFrame(frames["deco"], CGRect(x: 0, y: 0, width: 60, height: 40))

        let pixels = try draw(nodes, width: 100, height: 80)
        assertFrame(pixels.bounds { $0.a > 0 }, CGRect(x: 0, y: 0, width: 60, height: 40))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 0, y: 0, width: 30, height: 20))
        for (x, y) in [(59, 20), (30, 39), (0, 30), (59, 0), (57, 37)] {
            XCTAssertTrue(Pixels.isRed(pixels.pixel(x, y)), "(\(x), \(y)) is \(pixels.pixel(x, y)), not the border")
        }
        XCTAssertTrue(Self.isBlue(pixels.pixel(45, 30)), "the fill is \(pixels.pixel(45, 30))")
    }

    /// A4.2: `position: foreground` draws the decoration over the child: a
    /// red border 4 wide (no fill) covers the green child's top and left
    /// edges, the box still 60x40.
    func testA4_2DecoratedBoxForegroundPaintsOverItsChild() throws {
        let nodes = decorated(["border": ["color": "#FF0000", "width": 4]], position: "foreground")
        let pixels = try draw(nodes, width: 100, height: 80)
        assertFrame(pixels.bounds { $0.a > 0 }, CGRect(x: 0, y: 0, width: 60, height: 40))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 4, y: 4, width: 26, height: 16))
        for (x, y) in [(1, 1), (10, 1), (1, 10), (59, 20), (30, 39)] {
            XCTAssertTrue(Pixels.isRed(pixels.pixel(x, y)), "(\(x), \(y)) is \(pixels.pixel(x, y)), not the border")
        }
        XCTAssertEqual(pixels.pixel(45, 30).a, 0, "a foreground border with no fill fills the box")
    }

    // MARK: ColorFiltered (A4.3)

    /// A4.3: the colour (blue at alpha 128) is blended with each pixel of a
    /// two-colour child (opaque red, green at alpha 128) by Flutter's
    /// formula for the mode, and that result alone is laid over the page
    /// (opaque white), as Flutter's filter layer is: within 2/255 per
    /// channel of `c + page·(1−a)`. Blended with the page itself, the
    /// result would differ.
    func testA4_3ColorFilteredBlendsItsColourByFluttersFormula() throws {
        let colour: [Double] = [0, 0, 128.0 / 255, 128.0 / 255]
        let red: [Double] = [1, 0, 0, 1]
        let green: [Double] = [0, 128.0 / 255, 0, 128.0 / 255]
        for mode in ["multiply", "srcIn", "dstIn", "dstATop", "srcATop"] {
            let pixels = try draw(filtered(["color": "#0000FF80", "blendMode": .string(mode)]), width: 80, height: 50,
                                  page: Self.white)
            assertPixel(pixels.pixel(15, 15), Self.bytes(Self.overWhite(Self.flutter(mode, colour, red))),
                        "\(mode) over red")
            assertPixel(pixels.pixel(45, 15), Self.bytes(Self.overWhite(Self.flutter(mode, colour, green))),
                        "\(mode) over green")
        }
    }

    /// A4.3: each mode SwiftUI has maps to SwiftUI's mode of the same
    /// effect: srcOver normal, srcATop sourceAtop, dstOver destinationOver,
    /// the separable and non-separable modes by name (srcIn, dstIn and
    /// dstATop are built from other modes and opacity).
    func testA4_3EachBlendModeMapsToSwiftUIsMode() {
        let table: [(OrcaBlendMode, BlendMode)] = [
            (.srcOver, .normal), (.srcATop, .sourceAtop), (.dstOver, .destinationOver), (.multiply, .multiply),
            (.screen, .screen), (.overlay, .overlay), (.darken, .darken), (.lighten, .lighten),
            (.colorDodge, .colorDodge), (.colorBurn, .colorBurn), (.hardLight, .hardLight),
            (.softLight, .softLight), (.difference, .difference), (.exclusion, .exclusion), (.hue, .hue),
            (.saturation, .saturation), (.color, .color), (.luminosity, .luminosity),
        ]
        XCTAssertEqual(Set(table.map(\.0.rawValue)).union(["srcIn", "dstIn", "dstATop"]),
                       Set(OrcaBlendMode.allCases.map(\.rawValue)), "a mode is missing from the table")
        for (mode, expected) in table {
            XCTAssertEqual(ColorFilteredView.blendMode(mode), expected, mode.rawValue)
        }
    }

    /// A4.3: the default, a transparent colour by srcATop, leaves the child
    /// as it is.
    func testA4_3ColorFilteredByDefaultLeavesItsChildUnchanged() throws {
        let pixels = try draw(filtered([:]), width: 80, height: 50)
        assertPixel(pixels.pixel(15, 15), (255, 0, 0, 255), "red")
        assertPixel(pixels.pixel(45, 15), (0, 128, 0, 128), "green at half alpha")
    }

    // MARK: taps (a hosted window, a UIKit text field as the probe)

    #if canImport(UIKit)
    /// A4.2: a ClipOval takes taps only inside its ellipse (RenderClipOval
    /// hit-tests the oval, proxy_box.dart:1924-1938). Around a red 80x80
    /// Container over a text field: a tap at its centre finds no field, a
    /// tap in its top left corner, outside the oval, finds the field behind,
    /// one at the middle of its top edge does not.
    func testA4_2ClipOvalTakesTapsOnlyInsideItsEllipse() throws {
        let oval = [node("w", "ClipOval", [:], ["red"]), box("red", "#FF0000", 80, 80)]
        let (centred, centredField) = try overField(oval, left: 60, top: 68)
        let centre = CGPoint(x: 100, y: 108)
        XCTAssertTrue(centredField.contains(centre), "the field \(centredField) is not under the centre")
        XCTAssertFalse(FlowTests.isInField(centred.hitTest(centre, with: nil)), "a tap at the centre went through")
        centred.isHidden = true

        let (cornered, corneredField) = try overField(oval, left: 50, top: 104)
        defer { cornered.isHidden = true }
        // (2, 2) and (40, 2) in the ClipOval's own box.
        let corner = CGPoint(x: 52, y: 106), edge = CGPoint(x: 90, y: 106)
        XCTAssertTrue(corneredField.contains(corner) && corneredField.contains(edge),
                      "the field \(corneredField) is not under the corner and the edge")
        XCTAssertTrue(FlowTests.isInField(cornered.hitTest(corner, with: nil)),
                      "a tap in the corner, outside the oval, was taken")
        XCTAssertFalse(FlowTests.isInField(cornered.hitTest(edge, with: nil)), "a tap inside the oval went through")
    }

    /// A4.2: a clip takes no taps itself: RenderClipRect and RenderClipOval
    /// have no hitTestSelf, so where the child takes none the tap goes on
    /// to what is behind. Around a SizedBox 80x80 (which takes none) over a
    /// text field, a tap at the centre finds the field, for both.
    func testA4_2ClipsTakeNoTapsWhereTheirChildTakesNone() throws {
        for clip in ["ClipRect", "ClipOval"] {
            let (window, field) = try overField(sized(clip, [:], width: 80, height: 80), left: 60, top: 68)
            defer { window.isHidden = true }
            let centre = CGPoint(x: 100, y: 108)
            XCTAssertTrue(field.contains(centre), "the field \(field) is not under the centre")
            XCTAssertTrue(FlowTests.isInField(window.hitTest(centre, with: nil)), "\(clip) took the tap")
        }
    }

    /// A4.2: a ClipRect takes no taps on its child's overflow (Flutter never
    /// hits a box outside its size): the red 80x80 hanging 20 past a 40x40
    /// box over a text field takes a tap inside the box, and taps on the
    /// overflow on either side find the field.
    func testA4_2ClipRectTakesNoTapsOnItsChildsOverflow() throws {
        let (window, field) = try overField(clipped("ClipRect", root: "w"), left: 60, top: 90)
        defer { window.isHidden = true }
        let inside = CGPoint(x: 80, y: 110), right = CGPoint(x: 110, y: 110), left = CGPoint(x: 50, y: 110)
        XCTAssertTrue(field.contains(inside) && field.contains(right) && field.contains(left),
                      "the field \(field) is not under the three points")
        XCTAssertFalse(FlowTests.isInField(window.hitTest(inside, with: nil)), "a tap inside the box went through")
        XCTAssertTrue(FlowTests.isInField(window.hitTest(right, with: nil)), "a tap on the right overflow was taken")
        XCTAssertTrue(FlowTests.isInField(window.hitTest(left, with: nil)), "a tap on the left overflow was taken")
    }

    /// A4.1: at opacity 0 the child still takes taps, as in Flutter
    /// (RenderOpacity has no hitTest override, proxy_box.dart:886): a red
    /// 80x80 Container at opacity 0 over a text field takes a tap at its
    /// centre, and a text field at opacity 0 takes a tap itself.
    func testA4_1OpacityZeroStillTakesTaps() throws {
        let hidden = [node("w", "Opacity", ["opacity": 0], ["red"]), box("red", "#FF0000", 80, 80)]
        let (window, field) = try overField(hidden, left: 60, top: 68)
        let centre = CGPoint(x: 100, y: 108)
        XCTAssertTrue(field.contains(centre), "the field \(field) is not under the centre")
        XCTAssertFalse(FlowTests.isInField(window.hitTest(centre, with: nil)), "a tap at the centre went through")
        window.isHidden = true

        let page = [
            node("page", "Stack", ["alignment": "topLeft"], ["at"]),
            node("at", "Positioned", ["left": 0, "right": 0, "top": 100], ["o"]),
            node("o", "Opacity", ["opacity": 0], ["field"]),
            node("field", "TextField", ["placeholder": "Name"]),
        ]
        let (own, _) = try hosted(page)
        defer { own.isHidden = true }
        let shown = try XCTUnwrap(FlowTests.textField(in: own), "no text field")
        let point = shown.convert(CGPoint(x: shown.bounds.midX, y: shown.bounds.midY), to: own)
        XCTAssertTrue(FlowTests.isInField(own.hitTest(point, with: nil)), "a field at opacity 0 takes no tap")
    }

    /// A4.2: a DecoratedBox takes every tap in its box, filled or not
    /// (RenderDecoratedBox `hitTestSelf` is BoxDecoration.hitTest, true over
    /// the whole box with no borderRadius, box_decoration.dart:375-392): a
    /// border-only one around a 60x40 SizedBox over a text field finds no
    /// field at its centre, in the background or the foreground.
    func testA4_2DecoratedBoxTakesTapsOverItsWholeBox() throws {
        for position in [nil, "foreground"] as [String?] {
            var props: [String: JSONValue] = ["decoration": ["border": ["color": "#FF0000", "width": 2]]]
            if let position { props["position"] = .string(position) }
            let (window, field) = try overField(sized("DecoratedBox", props), left: 70, top: 88)
            defer { window.isHidden = true }
            let centre = CGPoint(x: 100, y: 108)
            XCTAssertTrue(field.contains(centre), "the field \(field) is not under the centre")
            XCTAssertFalse(FlowTests.isInField(window.hitTest(centre, with: nil)),
                           "\(position ?? "background"): a tap at the centre went through")
        }
    }

    /// A4.2: with a borderRadius of 20 the DecoratedBox takes taps only in
    /// its rounded box (BoxDecoration.hitTest's RRect), in the background
    /// or the foreground: a point just inside its top left corner, outside
    /// the radius, finds the field behind; its centre and the middle of its
    /// top edge do not.
    func testA4_2DecoratedBoxWithARadiusTakesTapsInItsRoundedBoxOnly() throws {
        for position in [nil, "foreground"] as [String?] {
            let name = position ?? "background"
            var props: [String: JSONValue] = ["decoration": ["border": ["color": "#FF0000", "width": 2],
                                                             "borderRadius": 20]]
            if let position { props["position"] = .string(position) }
            let rounded = sized("DecoratedBox", props)
            let (centred, centredField) = try overField(rounded, left: 70, top: 88)
            let centre = CGPoint(x: 100, y: 108)
            XCTAssertTrue(centredField.contains(centre), "the field \(centredField) is not under the centre")
            XCTAssertFalse(FlowTests.isInField(centred.hitTest(centre, with: nil)),
                           "\(name): a tap at the centre went through")
            centred.isHidden = true

            let (cornered, corneredField) = try overField(rounded, left: 50, top: 104)
            defer { cornered.isHidden = true }
            // (2, 2) and (30, 2) in the DecoratedBox's own box.
            let corner = CGPoint(x: 52, y: 106), edge = CGPoint(x: 80, y: 106)
            XCTAssertTrue(corneredField.contains(corner) && corneredField.contains(edge),
                          "the field \(corneredField) is not under the corner and the edge")
            XCTAssertTrue(FlowTests.isInField(cornered.hitTest(corner, with: nil)),
                          "\(name): a tap in the corner, outside the radius, was taken")
            XCTAssertFalse(FlowTests.isInField(cornered.hitTest(edge, with: nil)),
                           "\(name): a tap on the top edge went through")
        }
    }

    /// A4.2: with no decoration (Flutter's empty BoxDecoration) the box
    /// still takes taps: its centre finds no field.
    func testA4_2DecoratedBoxWithNoDecorationStillTakesTaps() throws {
        let (window, field) = try overField(sized("DecoratedBox", [:]), left: 70, top: 88)
        defer { window.isHidden = true }
        let centre = CGPoint(x: 100, y: 108)
        XCTAssertTrue(field.contains(centre), "the field \(field) is not under the centre")
        XCTAssertFalse(FlowTests.isInField(window.hitTest(centre, with: nil)), "a tap at the centre went through")
    }

    /// A4.2: the child is hit-tested first: a text field inside a
    /// DecoratedBox, under a foreground fill, takes a tap itself.
    func testA4_2DecoratedBoxChildTakesItsOwnTapsFirst() throws {
        let page = [
            node("page", "Stack", ["alignment": "topLeft"], ["at"]),
            node("at", "Positioned", ["left": 0, "right": 0, "top": 100], ["deco"]),
            node("deco", "DecoratedBox", ["decoration": ["color": "#0000FF80"], "position": "foreground"], ["field"]),
            node("field", "TextField", ["placeholder": "Name"]),
        ]
        let (window, _) = try hosted(page)
        defer { window.isHidden = true }
        let field = try XCTUnwrap(FlowTests.textField(in: window), "no text field")
        let point = field.convert(CGPoint(x: field.bounds.midX, y: field.bounds.midY), to: window)
        XCTAssertTrue(FlowTests.isInField(window.hitTest(point, with: nil)), "the DecoratedBox took its child's tap")
    }

    /// `type` with `props`, its first node "w", around a SizedBox (60x40 by default).
    func sized(_ type: String, _ props: [String: JSONValue], width: Double = 60, height: Double = 40) -> [JSONValue] {
        [node("w", type, props, ["size"]), node("size", "SizedBox", ["width": .double(width), "height": .double(height)])]
    }

    /// A4.3: a ColorFiltered is a proxy box, its child takes the taps
    /// however it is drawn: dstIn with a fully transparent colour hides a
    /// red 80x80 Container over a text field, which still takes a tap at its
    /// centre.
    func testA4_3ColorFilteredChildTakesTapsWhenFilteredOut() throws {
        let filtered = [node("w", "ColorFiltered", ["color": "#0000FF00", "blendMode": "dstIn"], ["red"]),
                        box("red", "#FF0000", 80, 80)]
        let pixels = try draw(filtered, width: 100, height: 100, page: Self.blue)
        assertPixel(pixels.pixel(40, 40), (0, 0, 255, 255), "the filtered child is drawn")
        let (window, field) = try overField(filtered, left: 60, top: 68)
        defer { window.isHidden = true }
        let centre = CGPoint(x: 100, y: 108)
        XCTAssertTrue(field.contains(centre), "the field \(field) is not under the centre")
        XCTAssertFalse(FlowTests.isInField(window.hitTest(centre, with: nil)), "a tap at the centre went through")
    }

    /// A light 200x200 window holding a Stack: a text field across it at y
    /// 100, and above it `wrapper` (its first node is "w") at (`left`,
    /// `top`). The window and the field's frame in it.
    func overField(_ wrapper: [JSONValue], left: Double, top: Double) throws -> (UIWindow, CGRect) {
        let nodes = [
            node("page", "Stack", ["alignment": "topLeft"], ["fieldAt", "at"]),
            node("fieldAt", "Positioned", ["left": 0, "right": 0, "top": 100], ["field"]),
            node("field", "TextField", ["placeholder": "Name"]),
            node("at", "Positioned", ["left": .double(left), "top": .double(top)], ["w"]),
        ] + wrapper
        let (window, _) = try hosted(nodes)
        let field = try XCTUnwrap(FlowTests.textField(in: window), "no text field")
        return (window, field.convert(field.bounds, to: window))
    }

    /// The first node in a light 200x200 window away from the screen's edges.
    func hosted(_ nodes: [JSONValue]) throws -> (UIWindow, OrcaPageModel) {
        let model = try model(nodes)
        let host = UIHostingController(rootView: NodeView(id: try rootId(nodes), model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
        let window = UIWindow(frame: CGRect(x: 0, y: 300, width: 200, height: 200))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return (window, model)
    }
    #endif

    // MARK: pages

    /// A Column (start) holding a RotatedBox of `turns` around a 60x20 blue
    /// Container with a red 30x20 at its left, and a green 20x10 below.
    func rotatedNodes(_ turns: Int?) -> [JSONValue] {
        [
            node("col", "Column", ["crossAxisAlignment": "start"], ["rb", "below"]),
            node("rb", "RotatedBox", turns.map { ["quarterTurns": .int($0)] } ?? [:], ["frame"]),
            node("frame", "Container", ["width": 60, "height": 20, "color": "#0000FF", "alignment": "topLeft"],
                 ["red"]),
            box("red", "#FF0000", 30, 20),
            box("below", "#00FF00", 20, 10),
        ]
    }

    func rotated(_ turns: Int?) throws -> Pixels {
        try draw(rotatedNodes(turns), width: 100, height: 100)
    }

    /// 20 in from the corner, `clip` (none when nil) around a Stack sized by
    /// a 40x40 SizedBox whose red 80x80 Positioned child sits at -20, -20.
    /// With `root`, the clip itself is the first node, under that id.
    func clipped(_ clip: String?, root: String? = nil) -> [JSONValue] {
        let stack = [
            node("stack", "Stack", [:], ["size", "pos"]),
            node("size", "SizedBox", ["width": 40, "height": 40]),
            node("pos", "Positioned", ["left": -20, "top": -20, "width": 80, "height": 80], ["fill"]),
            node("fill", "Container", ["color": "#FF0000"]),
        ]
        if let root, let clip { return [node(root, clip, [:], ["stack"])] + stack }
        let pad = node("pad", "Padding", ["padding": ["left": 20, "top": 20, "right": 0, "bottom": 0]],
                       [clip == nil ? "stack" : "clip"])
        return [pad] + (clip.map { [node("clip", $0, [:], ["stack"])] } ?? []) + stack
    }

    /// A DecoratedBox (blue fill, red border 4 wide unless `decoration` is
    /// given) around a 60x40 Container holding a green 30x20 at its top left.
    func decorated(_ decoration: [String: JSONValue], position: String? = nil) -> [JSONValue] {
        var props: [String: JSONValue] = [
            "decoration": decoration.isEmpty
                ? ["color": "#0000FF", "border": ["color": "#FF0000", "width": 4]] : .object(decoration),
        ]
        if let position { props["position"] = .string(position) }
        return [
            node("deco", "DecoratedBox", props, ["frame"]),
            node("frame", "Container", ["width": 60, "height": 40, "alignment": "topLeft"], ["green"]),
            box("green", "#00FF00", 30, 20),
        ]
    }

    /// A ColorFiltered with `props` around a Row (min) of an opaque red
    /// 30x30 and a 30x30 green at alpha 128.
    func filtered(_ props: [String: JSONValue]) -> [JSONValue] {
        [
            node("cf", "ColorFiltered", props, ["row"]),
            node("row", "Row", ["mainAxisSize": "min"], ["left", "right"]),
            box("left", "#FF0000", 30, 30),
            box("right", "#00FF0080", 30, 30),
        ]
    }

    // MARK: Flutter's blend modes

    /// Flutter's `BlendMode` (dart:ui; Skia's formulas) on premultiplied
    /// RGBA in 0...1: `s` the filter's colour (source), `d` the child's
    /// pixel (destination).
    static func flutter(_ mode: String, _ s: [Double], _ d: [Double]) -> [Double] {
        let sa = s[3], da = d[3]
        return (0..<4).map { i -> Double in
            switch mode {
            case "srcATop": return s[i] * da + d[i] * (1 - sa)
            case "srcIn": return s[i] * da
            case "dstIn": return d[i] * sa
            case "dstATop": return d[i] * sa + s[i] * (1 - da)
            case "multiply": return s[i] * (1 - da) + d[i] * (1 - sa) + s[i] * d[i]
            default: XCTFail("no formula for \(mode)"); return 0
            }
        }
    }

    /// Premultiplied `rgba` laid over an opaque white page.
    static func overWhite(_ rgba: [Double]) -> [Double] {
        [rgba[0] + 1 - rgba[3], rgba[1] + 1 - rgba[3], rgba[2] + 1 - rgba[3], 1]
    }

    static func bytes(_ rgba: [Double]) -> (UInt8, UInt8, UInt8, UInt8) {
        func byte(_ v: Double) -> UInt8 { UInt8(max(0, min(255, (v * 255).rounded()))) }
        return (byte(rgba[0]), byte(rgba[1]), byte(rgba[2]), byte(rgba[3]))
    }

    // MARK: helpers

    static func isGreen(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.g > 200 && p.r < 60 && p.b < 60
    }

    static func isBlue(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.b > 200 && p.r < 60 && p.g < 60
    }

    func assertPixel(_ actual: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ expected: (UInt8, UInt8, UInt8, UInt8),
                     _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let pairs = [(actual.r, expected.0), (actual.g, expected.1), (actual.b, expected.2), (actual.a, expected.3)]
        for (a, e) in pairs where abs(Int(a) - Int(e)) > 2 {
            return XCTFail("\(message): \(actual) vs \(expected)", file: file, line: line)
        }
    }

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected)", file: file, line: line)
        }
    }

    /// A wire node: a Stack, Row or Column holds many children, the rest one or none.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:],
              _ children: [String] = []) -> JSONValue {
        [
            "id": .string(id), "type": .string(type), "kind": "layout",
            "childMode": ["Stack", "Row", "Column"].contains(type) ? "multi" : "single",
            "props": .object(props), "children": .array(children.map { .string($0) }), "watches": [],
        ]
    }

    /// A solid Container of `hex`, `width` by `height`.
    func box(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": .double(width), "height": .double(height)])
    }

    /// The page, its registry widened by the six types (they are advertised
    /// only in group 6, and the renderer degrades any type it lacks).
    func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        let wrappers: Set<String> = ["Opacity", "RotatedBox", "ClipRect", "ClipOval", "DecoratedBox", "ColorFiltered"]
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(wrappers)))
    }

    func rootId(_ nodes: [JSONValue]) throws -> String {
        guard case .object(let first)? = nodes.first else { return try XCTUnwrap(nil as String?, "no root node") }
        return try XCTUnwrap(first["id"]?.stringValue, "no root id")
    }

    static let blue = Color(.sRGB, red: 0, green: 0, blue: 1)
    static let white = Color(.sRGB, red: 1, green: 1, blue: 1)

    /// The first node drawn by ImageRenderer at scale 1, in a `width` by
    /// `height` box from the top leading corner, over `page` (transparent by
    /// default). A render that draws nothing at all can come back holding
    /// the previous render's pixels, so a check that nothing is drawn draws
    /// over a page colour.
    func draw(_ nodes: [JSONValue], width: CGFloat, height: CGFloat, page: Color = .clear) throws -> Pixels {
        let view = NodeView(id: try rootId(nodes), model: try model(nodes))
            .frame(width: width, height: height, alignment: .topLeading)
            .background(page)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }
}
#endif
