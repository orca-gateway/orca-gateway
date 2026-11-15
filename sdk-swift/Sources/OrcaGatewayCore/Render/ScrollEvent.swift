import Foundation

/// Where a scroll view stands, Flutter's `ScrollMetrics`, in points
/// (Flutter's logical pixel is the iOS point). A SingleChildScrollView's
/// `minExtent` is 0.
public struct ScrollMetrics: Equatable, Sendable {
    public var offset: Double
    public var maxExtent: Double
    public var viewportDimension: Double
    public var minExtent: Double

    /// How far from an edge, in points, still counts as at it. Offsets and
    /// lengths come from layout as fractions of a point, so a view resting
    /// at its end can stand a pixel fraction off content minus viewport;
    /// Flutter compares exactly. A bounce past an edge is further out.
    public static let tolerance: Double = 0.5

    public init(offset: Double, maxExtent: Double, viewportDimension: Double, minExtent: Double = 0) {
        self.offset = offset
        self.maxExtent = maxExtent
        self.viewportDimension = viewportDimension
        self.minExtent = minExtent
    }

    /// A sample along the scroll axis: `offset` from the content's top (or
    /// leading edge), the content's and the viewport's lengths. maxExtent is
    /// content minus viewport, never below 0. `reverse` counts the offset
    /// from the far end, as Flutter's reversed view does (offset 0 at the
    /// bottom).
    public init(offset: Double, contentExtent: Double, viewportExtent: Double, reverse: Bool = false) {
        let maxExtent = max(0, contentExtent - viewportExtent)
        self.init(offset: reverse ? maxExtent - offset : offset, maxExtent: maxExtent,
                  viewportDimension: viewportExtent)
    }

    /// The payload `V.event` reads, Flutter `_scrollEventData`
    /// (builder_helpers.dart:32-41): at an edge, at the start when at or
    /// before `minExtent`, at the end when at or past `maxExtent` (content
    /// that fits is at both), each within `tolerance`.
    public var eventData: [String: JSONValue] {
        let tolerance = Self.tolerance
        let atEdge = abs(offset - minExtent) <= tolerance || abs(offset - maxExtent) <= tolerance
        return [
            "offset": .double(offset),
            "maxExtent": .double(maxExtent),
            "minExtent": .double(minExtent),
            "viewportDimension": .double(viewportDimension),
            "atStart": .bool(atEdge && offset <= minExtent + tolerance),
            "atEnd": .bool(atEdge && offset >= maxExtent - tolerance),
        ]
    }
}

/// A scroll trigger to fire on the view's node, with its payload.
public struct ScrollEvent: Equatable, Sendable {
    public var trigger: String
    public var eventData: [String: JSONValue]

    public init(trigger: String, eventData: [String: JSONValue]) {
        self.trigger = trigger
        self.eventData = eventData
    }

    /// The triggers a scroll view fires; a view whose node sets none is not watched.
    public static let triggers: Set<String> = ["onScrollBegin", "onScrolling", "onScrollEnd"]
}

/// Turns samples of one scroll view into its triggers, Flutter
/// `wrapScrollNotifier` (builder_helpers.dart:46-71), no throttling:
///
/// - onScrollBegin when a scroll starts (a drag, an animation), with the
///   metrics from before it moved, as Flutter's ScrollStartNotification.
/// - onScrolling for each sample whose offset changed, with `delta`, the
///   change since the sample before (negative toward the start).
/// - onScrollEnd when the scroll is no longer in progress, where it settled.
/// - An offset that changes with no scroll in progress is a jump: begin,
///   scrolling and end at once, all at the new offset, as Flutter's `jumpTo`.
/// - A new extent or viewport alone runs nothing (Flutter's
///   ScrollMetricsNotification is not a scroll notification).
public final class ScrollObserver {
    private var last: ScrollMetrics?
    private var scrolling = false

    public init() {}

    /// The triggers the sample `metrics` runs, in order; `inProgress` is
    /// whether a scroll is under way.
    public func observe(_ metrics: ScrollMetrics, inProgress: Bool) -> [ScrollEvent] {
        let previous = last
        last = metrics
        var events: [ScrollEvent] = []
        let moved = previous.map { $0.offset != metrics.offset } ?? false
        if !scrolling && (inProgress || moved) {
            scrolling = true
            let start = inProgress ? previous ?? metrics : metrics
            events.append(ScrollEvent(trigger: "onScrollBegin", eventData: start.eventData))
        }
        if moved, let previous {
            var data = metrics.eventData
            data["delta"] = .double(metrics.offset - previous.offset)
            events.append(ScrollEvent(trigger: "onScrolling", eventData: data))
        }
        if scrolling && !inProgress {
            scrolling = false
            events.append(ScrollEvent(trigger: "onScrollEnd", eventData: metrics.eventData))
        }
        return events
    }
}
