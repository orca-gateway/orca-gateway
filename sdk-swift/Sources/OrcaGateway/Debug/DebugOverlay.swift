#if canImport(SwiftUI)
import Foundation
import SwiftUI

extension OrcaDebug {
    private static let overlayLock = NSLock()
    private static var overlayOn = false

    /// The running config's `showOverlay`: set by `start`, off after `stop`.
    /// The UI layer's switch, so not in the core's `OrcaDebugOptions`; read
    /// and written under a lock, as `reporter` is.
    static var showOverlay: Bool {
        get {
            overlayLock.lock()
            defer { overlayLock.unlock() }
            return overlayOn
        }
        set {
            overlayLock.lock()
            overlayOn = newValue
            overlayLock.unlock()
        }
    }
}

/// What the debug overlay shows, without its drawing: Flutter's
/// `_OrcaDebugOverlayState` (sdk/lib/src/debug/debug_overlay.dart). A tap
/// unfolds it, the next folds it.
struct DebugOverlayModel: Equatable {
    private(set) var expanded = false

    mutating func tap() {
        expanded.toggle()
    }

    /// The chip's lines, top to bottom: folded `<load>ms`; unfolded the load
    /// to a tenth, the node count, and the cache, which is always `-` (no
    /// Flutter page passes one). No load (a page without a timing): `-`.
    func lines(loadMs: Double?, components: Int) -> [String] {
        func ms(_ digits: Int) -> String { loadMs.flatMap { DartFormat.fixed($0, digits) } ?? "-" }
        guard expanded else { return ["\(ms(0))ms"] }
        return ["Load: \(ms(1))ms", "Components: \(components)", "Cache: -"]
    }
}

/// Flutter's `OrcaDebugOverlay`: a chip 8 points in from the bottom right of
/// a page, black at 87% with rounded corners, the load in the green accent,
/// the other lines in white 70%, all monospaced. Only the chip takes
/// touches; the page around it gets its own.
struct DebugOverlay: View {
    /// Request start to render complete, in ms; nil for a page without a timing.
    let loadMs: Double?
    /// The page's node count.
    let components: Int
    @State private var model: DebugOverlayModel

    init(loadMs: Double?, components: Int, model: DebugOverlayModel = DebugOverlayModel()) {
        self.loadMs = loadMs
        self.components = components
        _model = State(initialValue: model)
    }

    /// Whether pages draw it: DevTools on and `showOverlay` on (Flutter
    /// orca_page.dart:396).
    static var isShown: Bool { OrcaDebug.isEnabled && OrcaDebug.showOverlay }

    /// Flutter's `Colors.greenAccent`, `Colors.white70`, `Colors.black87`.
    static let accent = Color(.sRGB, red: 0x69 / 255, green: 0xF0 / 255, blue: 0xAE / 255)
    static let dim = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0xB3 / 255)
    static let fill = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0xDD / 255)

    var body: some View {
        let lines = model.lines(loadMs: loadMs, components: components)
        Group {
            if model.expanded {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line).foregroundColor(index == 0 ? Self.accent : Self.dim)
                    }
                }
                .font(.system(size: 11, design: .monospaced))
            } else {
                Text(lines[0])
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Self.accent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Self.fill))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture { model.tap() }
        .padding(.trailing, 8)
        .padding(.bottom, 8)
    }
}
#endif
