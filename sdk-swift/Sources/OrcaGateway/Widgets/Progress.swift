#if canImport(SwiftUI)
import SwiftUI

// The two progress indicators as the Flutter SDK's builders paint them
// (primitive_builders.dart:302-323, 364-384, painters :435-513), not as a
// ProgressView: static pictures from the ProgressGeometry core on a Canvas,
// nothing animates. The same pictures as Kotlin's Progress.kt.

/// Flutter's `CircularProgressIndicator`: a `ProgressGeometry.circularSize`
/// square (a SizedBox) unless the parent forces a size (a non-square one
/// draws an ellipse), the arc's oval the box inset half the stroke
/// (`strokeWidth`, 3 by default), in `color` (#2196F3 by default). Without a
/// `value`, one static arc from -0.5 rad over 4.5 rad; with one, a full
/// track in the colour at alpha 0x33, then the arc from 12 o'clock over the
/// value (none at 0), the arcs with round caps. Angles are Flutter's: from 3
/// o'clock, clockwise. No right-to-left mirroring, as Flutter's painter.
@MainActor
struct CircularProgressIndicatorView: View {
    let node: ResolvedNode
    @Environment(\.orcaMinimum) private var minimum

    var body: some View {
        let color = ProgressColor.argb(node["color"]) ?? ProgressGeometry.defaultColor
        let stroke = ProgressGeometry.circularStroke(node["strokeWidth"]?.doubleValue)
        let arc = ProgressGeometry.circularArc(node["value"]?.doubleValue)
        let side = CGFloat(ProgressGeometry.circularSize)
        Canvas { context, size in
            let r = ProgressGeometry.circularRect(width: size.width, height: size.height, strokeWidth: stroke)
            let oval = CGRect(x: r.x, y: r.y, width: r.width, height: r.height)
            if arc.track {
                let track = ProgressColor.color(ProgressGeometry.trackColor(color))
                context.stroke(Path(ellipseIn: oval), with: .color(track),
                               style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
            }
            if arc.drawsArc {
                context.stroke(Self.arc(in: oval, from: arc.startRad, sweeping: arc.sweepRad),
                               with: .color(ProgressColor.color(color)),
                               style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            }
        }
        .modifier(TightFor(width: side, height: side, minimum: minimum.size(for: node.id)))
        .accessibilityHidden(true)
    }

    /// The arc of `oval` from `start` over `sweep` radians, as Skia's
    /// drawArc: a unit circle's arc stretched onto the oval, so the stroke
    /// keeps its width. Angles grow from 3 o'clock towards 6 in the view's
    /// y-down space; SwiftUI names that direction `clockwise: false` (its
    /// `clockwise` is meant for a y-up space).
    static func arc(in oval: CGRect, from start: Double, sweeping sweep: Double) -> Path {
        var unit = Path()
        unit.addArc(center: .zero, radius: 1, startAngle: .radians(start), endAngle: .radians(start + sweep),
                    clockwise: false)
        return unit.applying(CGAffineTransform(translationX: oval.midX, y: oval.midY)
            .scaledBy(x: oval.width / 2, y: oval.height / 2))
    }
}

/// Flutter's `LinearProgressIndicator`: `minHeight` (4 by default) high
/// across the parent's width, clipped to round ends of half that height
/// (circular corners, as Flutter's ClipRRect, not SwiftUI's continuous);
/// the track in `backgroundColor` (#E0E0E0 by default), then, when there is
/// a `value`, a bar of that part of the width in `color` (#2196F3 by
/// default) from the left, in right to left as well.
@MainActor
struct LinearProgressIndicatorView: View {
    let node: ResolvedNode
    @Environment(\.orcaMinimum) private var minimum

    var body: some View {
        let value = node["value"]?.doubleValue
        let color = ProgressColor.argb(node["color"]) ?? ProgressGeometry.defaultColor
        let track = ProgressColor.argb(node["backgroundColor"]) ?? ProgressGeometry.linearTrackColor
        let height = ProgressGeometry.linearHeight(node["minHeight"]?.doubleValue)
        let radius = ProgressGeometry.linearRadius(height)
        Canvas { context, size in
            let box = CGRect(origin: .zero, size: size)
            context.clip(to: Path(roundedRect: box, cornerRadius: radius, style: .circular))
            context.fill(Path(box), with: .color(ProgressColor.color(track)))
            if let bar = ProgressGeometry.linearBar(width: size.width, value: value) {
                context.fill(Path(CGRect(x: 0, y: 0, width: bar, height: size.height)),
                             with: .color(ProgressColor.color(color)))
            }
        }
        .modifier(TightFor(height: height, minimum: minimum.size(for: node.id)))
        .accessibilityHidden(true)
    }
}

/// Colours as the ProgressGeometry core takes them: ARGB, Flutter's `Color`
/// value.
enum ProgressColor {
    /// A wire colour (`Props.color`) as ARGB; nil when none is sent or it
    /// does not parse.
    static func argb(_ value: JSONValue?) -> UInt32? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let parts = Props.color(value)?.cgColor?
                  .converted(to: srgb, intent: .defaultIntent, options: nil)?.components,
              parts.count == 4
        else { return nil }
        func byte(_ part: CGFloat) -> UInt32 { UInt32((min(max(part, 0), 1) * 255).rounded()) }
        return byte(parts[3]) << 24 | byte(parts[0]) << 16 | byte(parts[1]) << 8 | byte(parts[2])
    }

    /// The colour of an ARGB value.
    static func color(_ argb: UInt32) -> Color {
        func part(_ shift: UInt32) -> Double { Double((argb >> shift) & 0xFF) / 255 }
        return Color(.sRGB, red: part(16), green: part(8), blue: part(0), opacity: part(24))
    }
}
#endif
