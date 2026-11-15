#if canImport(SwiftUI)
import SwiftUI

/// Drives a SessionTracker from the scene's phase, as `_OrcaAppState` in
/// sdk/lib/src/widgets/orca_app.dart does from `didChangeAppLifecycleState`:
/// a foreground when the view first appears (Flutter's `_initSession`) and
/// whenever the scene becomes active, a background when it goes to the
/// background. `.inactive` changes nothing. The tracker's open flag absorbs
/// the `.active` that follows the first appearance.
struct SessionTracking: ViewModifier {
    let tracker: SessionTracker?
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { foreground() }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active: foreground()
                case .background:
                    guard let tracker else { return }
                    Task { await tracker.background() }
                default: break
                }
            }
    }

    private func foreground() {
        guard let tracker else { return }
        Task { await tracker.foreground() }
    }
}

extension View {
    /// Report app sessions through `tracker`: a start when this view first
    /// appears and each time the app returns to the foreground, an end when
    /// it goes to the background. A nil tracker does nothing. Internal, like
    /// the Kotlin `SessionTracking`: only `OrcaApp` applies it, behind
    /// `enableSessionTracking`.
    func orcaSessionTracking(_ tracker: SessionTracker?) -> some View {
        modifier(SessionTracking(tracker: tracker))
    }
}
#endif
