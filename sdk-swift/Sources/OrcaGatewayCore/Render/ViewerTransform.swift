import Foundation

/// A point in an InteractiveViewer's own coordinates (the viewport's, where
/// gestures land) or in its child's (the scene's).
public struct ViewerPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A width and a height: an InteractiveViewer's viewport or its child.
public struct ViewerSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// What an InteractiveViewer draws its child through: Flutter's
/// TransformationController value as InteractiveViewer moves it with
/// rotation off, a uniform `scale` about the child's top-left corner and
/// then a translation (`x`, `y`), so scene point p is drawn at
/// scale·p + (x, y).
public struct ViewerTransform: Equatable, Sendable {
    public var scale: Double
    public var x: Double
    public var y: Double

    public static let identity = ViewerTransform(scale: 1, x: 0, y: 0)

    public init(scale: Double, x: Double, y: Double) {
        self.scale = scale
        self.x = x
        self.y = y
    }

    /// Flutter `TransformationController.toScene`: the scene point drawn at `point`.
    public func toScene(_ point: ViewerPoint) -> ViewerPoint {
        ViewerPoint(x: (point.x - x) / scale, y: (point.y - y) / scale)
    }
}

/// What bounds an InteractiveViewer's transform: its viewport (its own box)
/// and its child's size, and the Flutter builder's props with its defaults
/// (layout_builders.dart:636-644). The framework's boundaryMargin is zero,
/// so the bound is the child's rect (`_boundaryRect`, interactive_viewer.dart
/// :515-526), and its panAxis free.
public struct ViewerLimits: Equatable, Sendable {
    public var viewport: ViewerSize
    public var child: ViewerSize
    public var minScale: Double
    public var maxScale: Double
    public var panEnabled: Bool
    public var scaleEnabled: Bool

    public init(viewport: ViewerSize, child: ViewerSize, minScale: Double = 0.8, maxScale: Double = 2.5,
                panEnabled: Bool = true, scaleEnabled: Bool = true) {
        self.viewport = viewport
        self.child = child
        self.minScale = minScale
        self.maxScale = maxScale
        self.panEnabled = panEnabled
        self.scaleEnabled = scaleEnabled
    }

    /// Flutter `_matrixScale` (:646-660): `transform` scaled by `change`
    /// about the top-left corner, the total first raised to the scale at
    /// which the child covers the viewport, then clamped to minScale ...
    /// maxScale (`clampDouble`, so the clamp wins). A change of 1 changes
    /// nothing.
    func scaled(_ transform: ViewerTransform, by change: Double) -> ViewerTransform {
        if change == 1 { return transform }
        let total = max(transform.scale * change,
                        max(viewport.width / child.width, viewport.height / child.height))
        let clamped = total < minScale ? minScale : total > maxScale ? maxScale : total
        return ViewerTransform(scale: clamped, x: transform.x, y: transform.y)
    }

    /// Flutter `_matrixTranslate` (:547-640): `transform` moved by
    /// `translation` in scene units. When the viewport, mapped into the
    /// scene, would leave the child's rect, the move goes to the nearest
    /// place inside instead; when no place fits, it does not move; when
    /// only one axis fits, only that axis keeps its translation (the other
    /// is 0, as Flutter sets it).
    func translated(_ transform: ViewerTransform, by translation: ViewerPoint) -> ViewerTransform {
        if translation.x == 0 && translation.y == 0 { return transform }
        let scale = transform.scale
        let next = ViewerTransform(scale: scale, x: transform.x + scale * translation.x,
                                   y: transform.y + scale * translation.y)
        let offending = exceeds(next)
        if offending.x == 0 && offending.y == 0 { return next }
        let corrected = ViewerTransform(scale: scale, x: next.x - offending.x * scale,
                                        y: next.y - offending.y * scale)
        let still = exceeds(corrected)
        if still.x == 0 && still.y == 0 { return corrected }
        if still.x != 0 && still.y != 0 { return transform }
        return ViewerTransform(scale: scale, x: still.x == 0 ? corrected.x : 0, y: still.y == 0 ? corrected.y : 0)
    }

    /// Flutter `_exceedsBy` (:1252-1272) with the child's rect as the
    /// boundary: on each axis, the largest of the viewport's four corners'
    /// distances (in the scene, through `transform`) to the nearest point
    /// inside the rect, rounded to 9 places (`_round`); zero inside.
    private func exceeds(_ transform: ViewerTransform) -> ViewerPoint {
        let corners = [(0, 0), (viewport.width, 0), (viewport.width, viewport.height), (0, viewport.height)]
            .map { transform.toScene(ViewerPoint(x: $0.0, y: $0.1)) }
        var largest = ViewerPoint(x: 0, y: 0)
        for corner in corners {
            let x = min(max(corner.x, 0), child.width) - corner.x
            let y = min(max(corner.y, 0), child.height) - corner.y
            if abs(x) > abs(largest.x) { largest.x = x }
            if abs(y) > abs(largest.y) { largest.y = y }
        }
        return ViewerPoint(x: Self.round(largest.x), y: Self.round(largest.y))
    }

    /// Flutter `_round`: to 9 decimal places.
    static func round(_ value: Double) -> Double {
        (value * 1e9).rounded() / 1e9
    }
}

/// One gesture on an InteractiveViewer, Flutter's scale gesture (one
/// recogniser pans and pinches, interactive_viewer.dart :700-805): `start`
/// where it begins, then each `update` with its scale since the start and
/// its focal point (in the viewer's coordinates) gives the next transform.
/// Fling inertia at the end (`_onScaleEnd`) is not ported.
public struct ViewerGesture: Sendable {
    /// Flutter `_GestureType` with rotation off.
    public enum Kind: Sendable {
        case pan, scale
    }

    /// Decided at the first update, and again while it is a pan.
    public private(set) var kind: Kind?
    /// The scale when the gesture began.
    public private(set) var scaleStart: Double = 1
    /// The scene point that should stay under the focal point.
    public private(set) var reference = ViewerPoint(x: 0, y: 0)

    public init() {}

    /// Flutter `_onScaleStart`.
    public mutating func start(focal: ViewerPoint, transform: ViewerTransform) {
        kind = nil
        scaleStart = transform.scale
        reference = transform.toScene(focal)
    }

    /// Flutter `_onScaleUpdate`: a scale (any scale but 1, while
    /// scaleEnabled) zooms by `scale` since the start and then moves so the
    /// reference is back under `focal` (bounded, the reference following
    /// when the bound stops it); a pan (scale 1) moves by the focal point's
    /// travel in the scene. A kind its flag turns off changes nothing, as
    /// does a pan whose scale is not 1.
    public mutating func update(scale: Double, focal: ViewerPoint, transform: ViewerTransform,
                                limits: ViewerLimits) -> ViewerTransform {
        if kind == nil || kind == .pan {
            kind = abs((limits.scaleEnabled ? scale : 1) - 1) > 0 ? .scale : .pan
        }
        switch kind {
        case .scale:
            guard limits.scaleEnabled else { return transform }
            let scaled = limits.scaled(transform, by: scaleStart * scale / transform.scale)
            let focalScene = scaled.toScene(focal)
            let next = limits.translated(scaled, by: ViewerPoint(x: focalScene.x - reference.x,
                                                                  y: focalScene.y - reference.y))
            let check = next.toScene(focal)
            if ViewerLimits.round(check.x) != ViewerLimits.round(reference.x)
                || ViewerLimits.round(check.y) != ViewerLimits.round(reference.y) {
                reference = check
            }
            return next
        default:
            guard limits.panEnabled, scale == 1 else { return transform }
            let focalScene = transform.toScene(focal)
            let next = limits.translated(transform, by: ViewerPoint(x: focalScene.x - reference.x,
                                                                     y: focalScene.y - reference.y))
            reference = next.toScene(focal)
            return next
        }
    }
}
