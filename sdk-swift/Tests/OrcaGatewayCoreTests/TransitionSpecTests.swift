import XCTest

@testable import OrcaGatewayCore

/// A route's `transition` as a spec: the kind, the platform that honours it
/// and what the entering page looks like at a time, with a number for "now"
/// (Flutter `_transitionsBuilder`, sdk/lib/src/navigation/navigation_handler.dart:280-325).
final class TransitionSpecTests: XCTestCase {
    private func spec(_ type: String, duration: Int = 300, curve: String = "easeInOut") -> TransitionSpec {
        TransitionSpec.spec(for: RouteTransitionDef(type: type, duration: duration, curve: curve))
    }

    private func decoded(_ json: String) throws -> RouteTransitionDef {
        try JSONDecoder().decode(RouteTransitionDef.self, from: Data(json.utf8))
    }

    private typealias Look = (opacity: Double, offsetXFraction: Double, offsetYFraction: Double, scale: Double)

    private func assertLook(_ look: Look, _ opacity: Double, _ x: Double, _ y: Double, _ scale: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(look.opacity, opacity, accuracy: 1e-9, "opacity", file: file, line: line)
        XCTAssertEqual(look.offsetXFraction, x, accuracy: 1e-9, "x", file: file, line: line)
        XCTAssertEqual(look.offsetYFraction, y, accuracy: 1e-9, "y", file: file, line: line)
        XCTAssertEqual(look.scale, scale, accuracy: 1e-9, "scale", file: file, line: line)
    }

    // MARK: - B12.6-S: parsing

    func test_B12_6_everyKindIsParsedByItsName() {
        XCTAssertEqual(spec("fade").kind, .fade)
        XCTAssertEqual(spec("slideUp").kind, .slideUp)
        XCTAssertEqual(spec("scale").kind, .scale)
        XCTAssertEqual(spec("slideRight").kind, .slideRight)
        XCTAssertEqual(spec("slide").kind, .slide)
        XCTAssertEqual(spec("none").kind, TransitionKind.none)
    }

    func test_B12_6_noTransitionAndNoneAreThePlatformDefault() {
        XCTAssertEqual(TransitionSpec.spec(for: nil), TransitionSpec.none)
        XCTAssertEqual(TransitionSpec.none.kind, TransitionKind.none)
        XCTAssertEqual(TransitionSpec.none.durationMs, 300)
        XCTAssertNil(TransitionSpec.none.curve)
        // `none` is no transition at all, whatever else it carries.
        XCTAssertEqual(spec("none", duration: 900, curve: "linear"), TransitionSpec.none)
    }

    func test_B12_6_anUnknownKindIsSlideAsInDart() {
        // Dart: `'slide' || _ =>` (navigation_handler.dart:320).
        XCTAssertEqual(spec("zoom").kind, .slide)
        XCTAssertEqual(spec("").kind, .slide)
        XCTAssertEqual(spec("Fade").kind, .slide)
        XCTAssertEqual(spec("slideup").kind, .slide)
    }

    func test_B12_6_theDurationDefaultIs300AndItIsWholeMilliseconds() throws {
        XCTAssertEqual(TransitionSpec.spec(for: try decoded(#"{"type":"fade"}"#)).durationMs, 300)
        XCTAssertEqual(TransitionSpec.spec(for: try decoded(#"{"type":"fade","duration":450}"#)).durationMs, 450)
        XCTAssertEqual(spec("fade", duration: 0).durationMs, 0)
        // Below zero is zero: a jump.
        XCTAssertEqual(spec("fade", duration: -20).durationMs, 0)
        // Dart reads `json['duration'] as int?`: a fraction is not a duration.
        XCTAssertThrowsError(try decoded(#"{"type":"fade","duration":250.7}"#))
    }

    func test_B12_6_theCurveDefaultIsEaseInOutAndAnyNameOfTheTableIsKept() throws {
        XCTAssertEqual(TransitionSpec.spec(for: try decoded(#"{"type":"fade"}"#)).curve, "easeInOut")
        XCTAssertEqual(spec("fade", curve: "linear").curve, "linear")
        // Outside Dart's eleven route curves, inside the core's table.
        XCTAssertEqual(spec("fade", curve: "easeOutCubic").curve, "easeOutCubic")
        let cubic = spec("fade", curve: "easeOutCubic").entering(at: 150, reduceMotion: false)
        XCTAssertEqual(cubic.opacity, Curves.apply("easeOutCubic", 0.5), accuracy: 1e-9)
        // A name no table has is easeInOut.
        let unknown = spec("fade", curve: "wobble").entering(at: 75, reduceMotion: false)
        XCTAssertEqual(unknown.opacity, Curves.apply("easeInOut", 0.25), accuracy: 1e-9)
    }

    // MARK: - B12.7-S: who honours what

    func test_B12_7_iOSHonoursFadeAndSlideUpOnlyAndroidEveryKind() {
        let table: [(String, Bool)] = [
            ("fade", true), ("slideUp", true), ("scale", false), ("slideRight", false),
            ("slide", false), ("zoom", false), ("none", false),
        ]
        for (type, iOS) in table {
            XCTAssertEqual(spec(type).honoured(on: .iOS), iOS, "iOS \(type)")
            XCTAssertTrue(spec(type).honoured(on: .android), "android \(type)")
        }
        XCTAssertFalse(TransitionSpec.spec(for: nil).honoured(on: .iOS))
        XCTAssertTrue(TransitionSpec.spec(for: nil).honoured(on: .android))
    }

    // MARK: - B12.6-S: the entering page at a time

    func test_B12_6_atTheStartEachKindIsWhereItComesFrom() {
        assertLook(spec("fade").entering(at: 0, reduceMotion: false), 0, 0, 0, 1)
        assertLook(spec("slideUp").entering(at: 0, reduceMotion: false), 1, 0, 1, 1)
        assertLook(spec("scale").entering(at: 0, reduceMotion: false), 1, 0, 0, 0)
        assertLook(spec("slideRight").entering(at: 0, reduceMotion: false), 1, 1, 0, 1)
        assertLook(spec("slide").entering(at: 0, reduceMotion: false), 1, -1, 0, 1)
        assertLook(spec("zoom").entering(at: 0, reduceMotion: false), 1, -1, 0, 1)
        assertLook(spec("none").entering(at: 0, reduceMotion: false), 1, 0, 0, 1)
        // Before the start is the start.
        assertLook(spec("fade").entering(at: -40, reduceMotion: false), 0, 0, 0, 1)
    }

    func test_B12_6_midwayFollowsTheCurve() {
        // Linear: 150 of 300 ms is half way, 75 a quarter.
        assertLook(spec("fade", curve: "linear").entering(at: 150, reduceMotion: false), 0.5, 0, 0, 1)
        assertLook(spec("slideUp", curve: "linear").entering(at: 75, reduceMotion: false), 1, 0, 0.75, 1)
        assertLook(spec("scale", curve: "linear").entering(at: 75, reduceMotion: false), 1, 0, 0, 0.25)
        assertLook(spec("slideRight", curve: "linear").entering(at: 75, reduceMotion: false), 1, 0.75, 0, 1)
        assertLook(spec("slide", curve: "linear").entering(at: 75, reduceMotion: false), 1, -0.75, 0, 1)
        // easeInOut at a quarter is Flutter's 0.12868531048297882.
        let eased = 0.12868531048297882
        assertLook(spec("fade").entering(at: 75, reduceMotion: false), eased, 0, 0, 1)
        assertLook(spec("slideUp").entering(at: 75, reduceMotion: false), 1, 0, 1 - eased, 1)
        assertLook(spec("fade").entering(at: 150, reduceMotion: false), 0.5, 0, 0, 1)
        // The duration is the route's.
        assertLook(spec("fade", duration: 1000, curve: "linear").entering(at: 250, reduceMotion: false),
                   0.25, 0, 0, 1)
    }

    func test_B12_6_aCurveThatOvershootsMovesThePageButNotItsOpacity() {
        // elasticOut at a quarter is 1.125.
        assertLook(spec("fade", curve: "elasticOut").entering(at: 75, reduceMotion: false), 1, 0, 0, 1)
        assertLook(spec("slideUp", curve: "elasticOut").entering(at: 75, reduceMotion: false), 1, 0, -0.125, 1)
        assertLook(spec("scale", curve: "elasticOut").entering(at: 75, reduceMotion: false), 1, 0, 0, 1.125)
    }

    func test_B12_6_atTheEndAndPastItThePageIsInPlace() {
        for type in ["fade", "slideUp", "scale", "slideRight", "slide", "none"] {
            assertLook(spec(type).entering(at: 300, reduceMotion: false), 1, 0, 0, 1)
            assertLook(spec(type).entering(at: 5000, reduceMotion: false), 1, 0, 0, 1)
        }
    }

    func test_B12_7_reducedMotionOrNoDurationIsInPlaceAtOnce() {
        for type in ["fade", "slideUp", "scale", "slideRight", "slide", "none"] {
            assertLook(spec(type).entering(at: 0, reduceMotion: true), 1, 0, 0, 1)
            assertLook(spec(type).entering(at: 150, reduceMotion: true), 1, 0, 0, 1)
            assertLook(spec(type, duration: 0).entering(at: 0, reduceMotion: false), 1, 0, 0, 1)
            assertLook(spec(type, duration: -5).entering(at: 0, reduceMotion: false), 1, 0, 0, 1)
        }
    }

    func test_B12_7_isOverTellsWhenTheEntranceNeedsNoMoreFrames() {
        XCTAssertFalse(spec("fade").isOver(at: 0, reduceMotion: false))
        XCTAssertFalse(spec("fade").isOver(at: 299, reduceMotion: false))
        XCTAssertTrue(spec("fade").isOver(at: 300, reduceMotion: false))
        XCTAssertTrue(spec("fade").isOver(at: 0, reduceMotion: true))
        XCTAssertTrue(spec("fade", duration: 0).isOver(at: 0, reduceMotion: false))
        XCTAssertTrue(spec("none").isOver(at: 0, reduceMotion: false))
    }
}
