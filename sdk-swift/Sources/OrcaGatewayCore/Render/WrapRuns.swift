import Foundation

/// Flutter `WrapAlignment`: where a run's free main-axis space goes, read by
/// the builder's `_parseWrapAlignment` (start when missing or unknown).
public enum WrapAlignment: String, CaseIterable, Sendable {
    case start, end, center, spaceBetween, spaceAround, spaceEvenly

    public static func of(_ value: String?) -> WrapAlignment {
        value.flatMap(WrapAlignment.init(rawValue:)) ?? .start
    }

    /// Flutter `WrapAlignment._distributeSpace`, not flipped: the space
    /// before a run's first child and between two children, out of `free`
    /// for `count` children. spaceBetween with one child is start.
    func distribute(_ free: Double, spacing: Double, count: Int) -> (leading: Double, between: Double) {
        let n = Double(count)
        switch self {
        case .start: return (0, spacing)
        case .end: return (free, spacing)
        case .center: return (free / 2, spacing)
        case .spaceBetween: return count < 2 ? (0, spacing) : (0, free / (n - 1) + spacing)
        case .spaceAround: return (free / n / 2, free / n + spacing)
        case .spaceEvenly: return (free / (n + 1), free / (n + 1) + spacing)
        }
    }
}

/// Flutter `WrapCrossAlignment`: where a child sits in its run's cross
/// extent, read by the builder's `_parseWrapCrossAlignment` (stretch,
/// baseline and anything else are start).
public enum WrapCrossAlignment: String, Sendable {
    case start, end, center

    public static func of(_ value: String?) -> WrapCrossAlignment {
        value.flatMap(WrapCrossAlignment.init(rawValue:)) ?? .start
    }

    var factor: Double {
        switch self {
        case .start: return 0
        case .end: return 1
        case .center: return 0.5
        }
    }
}

/// A size along a Wrap's axes: a horizontal Wrap's (width, height), a vertical one's (height, width).
public struct WrapSize: Equatable, Sendable {
    public var main: Double
    public var cross: Double

    public init(main: Double, cross: Double) {
        self.main = main
        self.cross = cross
    }
}

/// A child's offset from the Wrap's origin along its axes.
public struct WrapOffset: Equatable, Sendable {
    public var main: Double
    public var cross: Double

    public init(main: Double, cross: Double) {
        self.main = main
        self.cross = cross
    }
}

/// The Wrap's own size and each child's offset, in the children's order.
public struct WrapLayout: Sendable {
    public var size: WrapSize
    public var offsets: [WrapOffset]

    public init(size: WrapSize, offsets: [WrapOffset]) {
        self.size = size
        self.offsets = offsets
    }
}

/// Flutter `RenderWrap`'s layout (rendering/wrap.dart `performLayout`,
/// `_computeRuns`, `_positionChildren`) for a Wrap that is left to right and
/// top down with runAlignment start, as the Flutter builder makes it, in
/// any one unit. A vertical Wrap is the same with the axes swapped; the
/// caller lays each child out loosely first (main axis up to the incoming
/// maximum, cross axis unbounded) and passes its size.
public enum WrapRuns {
    /// Flutter's `precisionErrorTolerance`: a child overshooting a run by no more than this still joins it.
    public static let precisionErrorTolerance: Double = 1e-10

    /// Breaks `children` into runs no longer than `maxMain` (which may be
    /// infinite), `spacing` between the children of a run and `runSpacing`
    /// between runs. The Wrap hugs its widest run and the runs' summed cross
    /// extents, brought within `minMain`...`maxMain` and
    /// `minCross`...`maxCross`; with no children it is the smallest size. In
    /// each run `alignment` shares the free main-axis space and
    /// `crossAlignment` places each child in the run's cross extent.
    public static func layout(
        _ children: [WrapSize],
        minMain: Double,
        maxMain: Double,
        minCross: Double,
        maxCross: Double,
        spacing: Double = 0,
        runSpacing: Double = 0,
        alignment: WrapAlignment = .start,
        crossAlignment: WrapCrossAlignment = .start
    ) -> WrapLayout {
        guard !children.isEmpty else {
            return WrapLayout(size: WrapSize(main: minMain, cross: minCross), offsets: [])
        }

        var runs: [Run] = []
        for (index, child) in children.enumerated() {
            if let run = runs.last, run.main + spacing + child.main - maxMain <= precisionErrorTolerance {
                runs[runs.count - 1].main += spacing + child.main
                runs[runs.count - 1].cross = max(run.cross, child.cross)
                runs[runs.count - 1].count += 1
            } else {
                runs.append(Run(first: index, main: child.main, cross: child.cross))
            }
        }

        let childrenMain = runs.map(\.main).max() ?? 0
        let childrenCross = runs.reduce(0) { $0 + $1.cross } + runSpacing * Double(runs.count - 1)
        let size = WrapSize(main: clamp(childrenMain, minMain, maxMain),
                            cross: clamp(childrenCross, minCross, maxCross))

        var offsets: [WrapOffset] = []
        offsets.reserveCapacity(children.count)
        var runCross = 0.0
        for run in runs {
            let free = max(0, size.main - run.main)
            let (leading, between) = alignment.distribute(free, spacing: spacing, count: run.count)
            var main = leading
            for child in children[run.first..<(run.first + run.count)] {
                offsets.append(WrapOffset(main: main,
                                          cross: runCross + crossAlignment.factor * (run.cross - child.cross)))
                main += child.main + between
            }
            runCross += run.cross + runSpacing
        }
        return WrapLayout(size: size, offsets: offsets)
    }

    /// Flutter `BoxConstraints.constrain` on one axis: `value` within `low`...`high`, the minimum winning.
    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        max(low, min(value, high))
    }

    /// Flutter `_RunMetrics`: a run's first child, its children, and its extent with the spacings.
    private struct Run {
        var first: Int
        var main: Double
        var cross: Double
        var count = 1
    }
}
