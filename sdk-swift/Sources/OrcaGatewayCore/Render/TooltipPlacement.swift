/// Where a Tooltip's bubble goes and how long it takes, Flutter's Material
/// Tooltip as its builder makes it (layout_builders.dart:583-586: message
/// and child, every other prop at its default): the bubble is placed by
/// `positionDependentBox` (painting/geometry.dart:42-68) with MUI
/// tooltip.dart's vertical offset 24 and preferBelow (:413-414, :475-495),
/// shown by a 500 ms long press and faded by RawTooltip
/// (widgets/raw_tooltip.dart:27-31, :752-767). Pure: the UI measures the
/// child and the bubble, passes them in, and runs the timers.
///
/// All rects and sizes are in the overlay's coordinate space, in points.
/// Flutter's overlay stops at the keyboard (raw_tooltip.dart:897, its
/// bottom the view's bottom inset): the UI passes the overlay less it.
public enum TooltipPlacement {
    /// How far the bubble's near edge is from the child's centre
    /// (tooltip.dart:413).
    public static let verticalOffset: Double = 24
    /// The least distance from the bubble to the overlay's edges
    /// (geometry.dart:48; MUI passes none).
    public static let margin: Double = 10
    /// How long a press must last to show the bubble, kLongPressTimeout
    /// (gestures/constants.dart:29), MUI's default trigger (tooltip.dart:420).
    public static let longPressMs = 500
    /// How long the bubble stays after the finger lifts, MUI's
    /// `_defaultShowDuration` (tooltip.dart:416) passed as RawTooltip's
    /// touchDelay (:570), the delay `_handlePressUp` dismisses with
    /// (raw_tooltip.dart:766).
    public static let showDurationMs = 1500
    /// The fade in, and the fade out, both Curves.fastOutSlowIn, Cubic(0.4,
    /// 0, 0.2, 1) (raw_tooltip.dart:27-31; animation/curves.dart:1865).
    public static let fadeInMs = 150
    public static let fadeOutMs = 75

    /// A rect in the overlay: its top-left corner and its size.
    public struct Rect: Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    public struct Size: Equatable, Sendable {
        public let width: Double
        public let height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    /// The bubble's top-left corner in the overlay.
    public struct Origin: Equatable, Sendable {
        public let x: Double
        public let y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// The bubble's top-left corner for a `child` rect, the `bubble`'s size
    /// and the `overlay`'s, as geometry.dart:50-67 computes it with the
    /// child's centre as the target. Below: its top `verticalOffset` under
    /// the centre, when its bottom is at most `margin` from the overlay's
    /// (`<=`). Else above, its bottom `verticalOffset` over the centre, when
    /// its top is at least `margin` from the overlay's. When neither side
    /// fits it stays below (preferBelow), its top at most `margin` above the
    /// overlay's bottom. Across: centred on the child, held `margin` from
    /// both edges; with `2 × margin` or less to spare it is centred in the
    /// overlay instead. Flutter lays the bubble out with the overlay's size
    /// as its maximum (`constraints.loosen()`, raw_tooltip.dart:993), so it
    /// is never wider than the overlay and x is never below 0: the UI must
    /// measure the bubble the same way before passing its size in.
    public static func origin(child: Rect, bubble: Size, overlay: Size) -> Origin {
        let targetX = child.x + child.width / 2
        let targetY = child.y + child.height / 2
        let fitsBelow = targetY + verticalOffset + bubble.height <= overlay.height - margin
        let fitsAbove = targetY - verticalOffset - bubble.height >= margin
        let below = fitsAbove == fitsBelow ? true : fitsBelow
        let y = below
            ? min(targetY + verticalOffset, overlay.height - margin)
            : max(targetY - verticalOffset - bubble.height, margin)
        let flexibleSpace = overlay.width - bubble.width
        let x = flexibleSpace <= 2 * margin
            ? flexibleSpace / 2
            : min(max(targetX - bubble.width / 2, margin), flexibleSpace - margin)
        return Origin(x: x, y: y)
    }
}
