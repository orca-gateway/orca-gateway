/// The app's one queue of snackbars and toasts, the Swift side of Flutter's
/// root ScaffoldMessenger as showSnackbar and showToast use it
/// (sdk/lib/src/state/action_executor.dart:393-423; material scaffold.dart
/// :371-392, :438-449, :661-674; snack_bar.dart:30, :323). Pure: no clock;
/// the UI passes time in with `advance(by:)`.
///
/// First in, first shown, nothing dropped or replaced. The head enters in
/// 250 ms, shows its duration counted from when it is fully in, leaves in
/// 250 ms, and the next enters as it goes. A swipe removes the head at once,
/// with no leave animation, and the next enters.
public struct SnackbarQueue: Equatable, Sendable {
    /// How long a bar takes to come in, and to go (snack_bar.dart:30).
    public static let transitionMs: Double = 250
    /// A snackbar's time on screen when its action names none
    /// (action_executor.dart:395).
    public static let snackbarDurationMs = 4000
    /// A toast's (action_executor.dart:410).
    public static let toastDurationMs = 2000

    public enum Kind: String, Equatable, Sendable {
        case snackbar, toast
    }

    /// Where the head is.
    public enum Phase: Equatable, Sendable {
        /// Coming in, for `transitionMs`.
        case entering
        /// Fully in, for its duration.
        case showing
        /// Going, for `transitionMs` from fully in.
        case leaving
    }

    public struct Item: Equatable, Sendable, Identifiable {
        /// Which show this is: the same message twice is two items.
        public let id: Int
        public let kind: Kind
        public let message: String
        /// Its time fully in, ms; 0 or less leaves as soon as it is in.
        public let durationMs: Int
    }

    /// Everything waiting, the head (on screen) first.
    public private(set) var items: [Item] = []
    /// The head's phase; nil when the queue is idle.
    public private(set) var phase: Phase?
    /// How far the head is in, ms, 0 ... transitionMs.
    private var inMs: Double = 0
    /// How long the head has been fully in, ms.
    private var shownMs: Double = 0
    private var shown = 0

    public init() {}

    /// The item on screen, nil when idle.
    public var current: Item? { items.first }

    /// How far the head is in, 0 (out) ... 1 (fully in): what the bar is
    /// revealed by.
    public var reveal: Double { inMs / Self.transitionMs }

    /// The ms until the head's phase next changes; nil when idle.
    public var untilNextChangeMs: Double? {
        switch phase {
        case nil: return nil
        case .entering?: return Self.transitionMs - inMs
        case .showing?: return Swift.max(0, Double(items[0].durationMs) - shownMs)
        case .leaving?: return inMs
        }
    }

    /// showSnackbar or showToast: the item, at the back of the queue; it
    /// starts entering at once when the queue is idle. No duration is
    /// 4000 ms for a snackbar, 2000 for a toast.
    @discardableResult
    public mutating func show(_ kind: Kind, message: String, durationMs: Int? = nil) -> Item {
        let item = Item(id: shown, kind: kind, message: message,
                        durationMs: durationMs ?? (kind == .snackbar ? Self.snackbarDurationMs
                                                                     : Self.toastDurationMs))
        shown += 1
        items.append(item)
        if phase == nil {
            phase = .entering
            inMs = 0
            shownMs = 0
        }
        return item
    }

    /// A swipe on the bar, once the UI has slid it off with the drag
    /// (Flutter's Dismissible): the head goes at once, whatever its phase,
    /// with no leave animation (removeCurrentSnackBar, snack_bar.dart
    /// :859-871, :865), and the next, if any, starts entering. An idle queue
    /// is left as it is.
    public mutating func swipe() {
        guard phase != nil else { return }
        dropHead()
    }

    /// The head is gone: the next, if any, starts entering from 0.
    private mutating func dropHead() {
        inMs = 0
        shownMs = 0
        items.removeFirst()
        phase = items.isEmpty ? nil : .entering
    }

    /// `ms` of time passes: phases end in turn, the time left over going to
    /// the next, and a head that has left gives way to the next item, which
    /// starts entering. Zero, negative or NaN changes nothing.
    public mutating func advance(by ms: Double) {
        guard ms > 0 else { return }
        var left = ms
        while left > 0, let current = phase {
            switch current {
            case .entering:
                let need = Self.transitionMs - inMs
                if left < need {
                    inMs += left
                    left = 0
                } else {
                    left -= need
                    inMs = Self.transitionMs
                    shownMs = 0
                    phase = .showing
                }
            case .showing:
                let need = Swift.max(0, Double(items[0].durationMs) - shownMs)
                if left < need {
                    shownMs += left
                    left = 0
                } else {
                    left -= need
                    phase = .leaving
                }
            case .leaving:
                if left < inMs {
                    inMs -= left
                    left = 0
                } else {
                    left -= inMs
                    dropHead()
                }
            }
        }
    }
}
