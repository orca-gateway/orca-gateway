// The SwiftUI layer of the Orca Gateway iOS SDK: renderer, widget views and
// platform adapters arrive in slice S2 (Epic 23b). Until then this module only
// re-exports the pure core so apps can depend on one product.
//
// Everything here sits behind `canImport(SwiftUI)` so the package still builds
// (and `swift test` runs the core tests) on Linux.
@_exported import OrcaGatewayCore

#if canImport(SwiftUI)
import SwiftUI

/// Namespace for the SDK's SwiftUI entry points (OrcaApp lands in S2).
public enum OrcaGatewayUI {
    /// The capability vector this build advertises, for diagnostics screens.
    public static var capabilities: CapabilityVector { .current }
}
#endif
