import Foundation

/// How a route's page comes in (Flutter `_transitionsBuilder`,
/// sdk/lib/src/navigation/navigation_handler.dart:303-325). Only the entering
/// page moves; the page under it stands still.
public enum TransitionKind: String, Equatable, Sendable, CaseIterable {
    /// Opacity 0 to 1.
    case fade
    /// From the bottom: down by its full height, up to its place.
    case slideUp
    /// Scale 0 to 1 from the centre.
    case scale
    /// In from the right: off by its full width.
    case slideRight
    /// In from the left; also every kind this SDK does not know.
    case slide
    /// No transition of the route's own: the platform's default page
    /// animation, not "no animation".
    case none
}

/// The platform a transition is drawn on.
public enum TransitionPlatform: Equatable, Sendable {
    case iOS, android
}

/// A route's `transition` ready to play: its kind, its length and its curve.
/// Pure: `entering(at:reduceMotion:)` takes the time since the push, from the
/// frame tick in the UI and from a number in tests.
public struct TransitionSpec: Equatable, Sendable {
    public var kind: TransitionKind
    /// Whole milliseconds, never below 0; 0 is a jump.
    public var durationMs: Double
    /// A name of the core's `Curves` table; nil and any unknown name are
    /// `easeInOut`. Flutter's route transitions know eleven names only
    /// (`_parseCurve`, navigation_handler.dart:328-343); here every name of
    /// the table counts.
    public var curve: String?

    public init(kind: TransitionKind, durationMs: Double = AnimationDuration.defaultMs, curve: String? = nil) {
        self.kind = kind
        self.durationMs = durationMs
        self.curve = curve
    }

    /// No transition: what a route without one, or with `none`, gets.
    public static let none = TransitionSpec(kind: .none)

    /// The spec of a route's transition, as Dart reads it: no transition and
    /// type `none` are `TransitionSpec.none` whatever else they carry; a
    /// type that is no known kind is `slide` (Dart's `'slide' || _`, names
    /// compared as written); the duration is the route's in whole
    /// milliseconds (300 when the config names none, below 0 is 0), the
    /// curve the route's (`easeInOut` when the config names none).
    public static func spec(for transition: RouteTransitionDef?) -> TransitionSpec {
        guard let transition, transition.type != TransitionKind.none.rawValue else { return .none }
        return TransitionSpec(kind: TransitionKind(rawValue: transition.type) ?? .slide,
                              durationMs: AnimationDuration.milliseconds(.int(transition.duration)),
                              curve: transition.curve)
    }

    /// Whether the platform plays this transition itself. Android: every
    /// kind (`none` is its NavHost default). iOS: `fade` and `slideUp`; any
    /// other kind is the system push.
    public func honoured(on platform: TransitionPlatform) -> Bool {
        switch platform {
        case .android: return true
        case .iOS: return kind == .fade || kind == .slideUp
        }
    }

    /// The entering page `elapsedMs` after its push. Offsets are fractions
    /// of the page's own size (x: +1 is one width to the right, y: +1 one
    /// height down); scale is about the centre. At rest: opacity 1, offsets
    /// 0, scale 1, which is also what `none`, `reduceMotion`, a duration of
    /// 0 or less and any time at or past the end give. Before the push is
    /// the start. A curve that leaves 0...1 (elastic, back) moves the page
    /// past its place; the opacity stays within 0...1.
    public func entering(at elapsedMs: Double, reduceMotion: Bool)
        -> (opacity: Double, offsetXFraction: Double, offsetYFraction: Double, scale: Double)
    {
        if isOver(at: elapsedMs, reduceMotion: reduceMotion) { return (1, 0, 0, 1) }
        let value = Curves.apply(curve, elapsedMs / durationMs)
        switch kind {
        case .fade: return (Swift.min(1, Swift.max(0, value)), 0, 0, 1)
        case .slideUp: return (1, 0, 1 - value, 1)
        case .scale: return (1, 0, 0, value)
        case .slideRight: return (1, 1 - value, 0, 1)
        case .slide: return (1, value - 1, 0, 1)
        case .none: return (1, 0, 0, 1)
        }
    }

    /// The entrance has nothing left to play at `elapsedMs`: the page is at
    /// rest and needs no more frames.
    public func isOver(at elapsedMs: Double, reduceMotion: Bool) -> Bool {
        kind == .none || reduceMotion || !(durationMs > 0) || elapsedMs >= durationMs
    }
}
