// The SwiftUI layer of the Orca Gateway iOS SDK (Epic 23b): OrcaApp, the
// page and node views, the 15 widget views and the device headers. It
// re-exports the pure core so apps depend on one product.
//
// Everything here sits behind `canImport(SwiftUI)` so the package still builds
// (and `swift test` runs the core tests) on Linux.
@_exported import OrcaGatewayCore

#if canImport(SwiftUI)
import SwiftUI

/// Namespace for SDK-wide UI information.
public enum OrcaGatewayUI {
    /// The capability vector this build advertises, for diagnostics screens.
    public static var capabilities: CapabilityVector { .current }
}
#endif
