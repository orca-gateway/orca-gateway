import Foundation

/// The `duration` prop of an animated widget: whole milliseconds (Dart
/// `propOr<int>('duration', 300)`). Anything that is not a whole number is the
/// default; a negative one is 0. A duration of 0 or less means "jump".
public enum AnimationDuration {
    public static func milliseconds(_ value: JSONValue?, default fallback: Double) -> Double {
        guard let ms = value?.dartInt else { return fallback }
        return Swift.max(0, Double(ms))
    }
}

/// Flutter's `AnimationStatus`.
public enum AnimationStatus: Equatable, Sendable {
    /// Resting at 0.
    case dismissed
    /// Running towards 1.
    case forward
    /// Running towards 0.
    case reverse
    /// Resting at 1.
    case completed
}

/// The clock of one AnimatedBuilder (Flutter's `AnimationController` as
/// `OrcaAnimatedBuilder` uses it). It holds no timer: every call takes "now"
/// in milliseconds, from the frame tick in the UI and from a number in tests.
///
/// With `reduceMotion`, or a duration of 0 or less, every run ends at once:
/// the end state, one completion; a repeating builder rests at 1 and, like
/// any repeat, never completes.
public struct AnimationController: Equatable, Sendable {
    public let durationMs: Double
    public let curve: String?
    public let repeats: Bool
    public let reverses: Bool
    public let reduceMotion: Bool

    private enum Run: Equatable, Sendable {
        /// One run from `from` to `to` (0 or 1) over `span` ms.
        case once(from: Double, to: Double, start: Double, span: Double)
        /// Flutter's `repeat(reverse:)`, begun at `start`.
        case repeating(start: Double)
    }

    /// The value while no run is live.
    private var rest: Double = 0
    private var run: Run?
    /// A run that had ended, unreported, when the next one replaced it.
    private var pendingCompletion = false

    public init(durationMs: Double = 300, curve: String? = nil, repeats: Bool = false,
                reverses: Bool = false, reduceMotion: Bool = false) {
        self.durationMs = durationMs
        self.curve = curve
        self.repeats = repeats
        self.reverses = reverses
        self.reduceMotion = reduceMotion
    }

    private var jumps: Bool { reduceMotion || !(durationMs > 0) }

    // MARK: Commands

    /// The `autoStart` run: a repeat when the builder repeats, else one
    /// forward run.
    public mutating func start(at now: Double) {
        guard repeats else { return forward(at: now) }
        settle(at: now)
        if jumps {
            rest = 1
            run = nil
        } else {
            run = .repeating(start: now)
        }
    }

    /// Flutter's `forward(from: 0)`: restart from 0 and play once, also on a
    /// repeating builder (the repeat stops).
    public mutating func forward(at now: Double) {
        settle(at: now)
        run = .once(from: 0, to: 1, start: now, span: jumps ? 0 : durationMs)
    }

    /// Flutter's `reverse()`: from the current value down to 0, in value x
    /// duration. At 0 nothing happens and nothing completes.
    public mutating func reverse(at now: Double) {
        let current = value(at: now)
        guard current > 0 else { return }
        settle(at: now)
        run = .once(from: current, to: 0, start: now, span: jumps ? 0 : current * durationMs)
    }

    /// True exactly once each time a run has reached 1 or reached 0; never for
    /// a repeat. The UI asks on every frame tick and fires `onComplete`.
    public mutating func takeCompletion(at now: Double) -> Bool {
        if pendingCompletion {
            pendingCompletion = false
            return true
        }
        guard case .once(_, let to, _, _)? = run, ended(at: now) else { return false }
        rest = to
        run = nil
        return true
    }

    // MARK: Reading

    /// The linear value, 0...1.
    public func value(at now: Double) -> Double {
        switch run {
        case nil:
            return rest
        case .once(let from, let to, let start, let span)?:
            if !(span > 0) || now >= start + span { return to }
            if now <= start { return from }
            return from + (to - from) * (now - start) / span
        case .repeating(let start)?:
            let cycles = Swift.max(now - start, 0) / durationMs
            let phase = cycles - cycles.rounded(.down)
            guard reverses else { return phase }
            return Int(cycles.rounded(.down).truncatingRemainder(dividingBy: 2)) == 0 ? phase : 1 - phase
        }
    }

    /// The value after the curve: what a `tween` reads.
    public func progress(at now: Double) -> Double {
        Curves.apply(curve, value(at: now))
    }

    public func status(at now: Double) -> AnimationStatus {
        switch run {
        case nil:
            return rest >= 1 ? .completed : .dismissed
        case .once(_, let to, _, _)?:
            if ended(at: now) { return to >= 1 ? .completed : .dismissed }
            return to >= 1 ? .forward : .reverse
        case .repeating(let start)?:
            guard reverses else { return .forward }
            let cycles = (Swift.max(now - start, 0) / durationMs).rounded(.down)
            return Int(cycles.truncatingRemainder(dividingBy: 2)) == 0 ? .forward : .reverse
        }
    }

    /// Whether the value still moves after `now`. A one-shot run that has just
    /// ended is not running, but its completion may still be waiting.
    public func isRunning(at now: Double) -> Bool {
        switch run {
        case nil: return false
        case .once?: return !ended(at: now)
        case .repeating?: return true
        }
    }

    // MARK: Private

    private func ended(at now: Double) -> Bool {
        guard case .once(_, _, let start, let span)? = run else { return false }
        return !(span > 0) || now >= start + span
    }

    /// Before a new run replaces the current one: keep an ended run's
    /// completion for the next `takeCompletion`.
    private mutating func settle(at now: Double) {
        if ended(at: now) { pendingCompletion = true }
    }
}

/// The controllers of one page by `animationId` (Flutter's
/// `AnimationRegistry`), what `animateForward` / `animateReverse` and a
/// `tween` naming an id reach. One per page model; used from the page's own
/// actor, so it has no lock.
///
/// The last builder to register an id owns it, and a builder that leaves
/// removes the entry only while it is still its own (Flutter removes whatever
/// sits under the id).
public final class AnimationRegistry {
    /// What tells one registering builder from another.
    public struct Owner: Hashable, Sendable {
        fileprivate let raw: Int
    }

    private var entries: [String: (owner: Owner, controller: AnimationController)] = [:]
    private var nextOwner = 0

    public init() {}

    /// A fresh token; a builder takes one when it appears.
    public func makeOwner() -> Owner {
        nextOwner += 1
        return Owner(raw: nextOwner)
    }

    /// Puts `controller` under `id` for `owner`, replacing any earlier entry.
    public func register(id: String, owner: Owner, controller: AnimationController) {
        entries[id] = (owner, controller)
    }

    /// Removes `id` if `owner` still owns it.
    public func unregister(id: String, owner: Owner) {
        guard entries[id]?.owner == owner else { return }
        entries[id] = nil
    }

    /// `animateForward`. False, and nothing happens, for an unknown id.
    @discardableResult
    public func forward(id: String, at now: Double) -> Bool {
        guard entries[id] != nil else { return false }
        entries[id]?.controller.forward(at: now)
        return true
    }

    /// `animateReverse`. False, and nothing happens, for an unknown id.
    @discardableResult
    public func reverse(id: String, at now: Double) -> Bool {
        guard entries[id] != nil else { return false }
        entries[id]?.controller.reverse(at: now)
        return true
    }

    /// The curved progress of `id`; 0 for an unknown id.
    public func progress(id: String, at now: Double) -> Double {
        entries[id]?.controller.progress(at: now) ?? 0
    }

    /// The controller under `id`, for its owner only.
    public func controller(id: String, owner: Owner) -> AnimationController? {
        guard let entry = entries[id], entry.owner == owner else { return nil }
        return entry.controller
    }

    /// Lets the owner change its controller in place (`start`,
    /// `takeCompletion`). Nil, and `body` is not run, when `owner` does not
    /// own `id`.
    @discardableResult
    public func update<Result>(id: String, owner: Owner,
                               _ body: (inout AnimationController) -> Result) -> Result? {
        guard var entry = entries[id], entry.owner == owner else { return nil }
        let result = body(&entry.controller)
        entries[id] = entry
        return result
    }
}
