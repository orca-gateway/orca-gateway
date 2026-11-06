import OrcaGateway
import SwiftUI

/// The counter example on iOS: the same Bun server as the Flutter example,
/// drawn by the Swift SDK. Start the server with `t example:dev:server`.
@main
struct OrcaCounterApp: App {
    var body: some Scene {
        WindowGroup {
            OrcaApp(
                client: OrcaClient(baseURL: Self.serverURL, appId: "counter", apiKey: "demo-key"),
                path: "home")
        }
    }

    /// The example server. The simulator reaches the Mac at localhost; set
    /// ORCA_SERVER_URL in the scheme (or SIMCTL_CHILD_ORCA_SERVER_URL for
    /// `simctl launch`) to use another address.
    static var serverURL: URL {
        let configured = ProcessInfo.processInfo.environment["ORCA_SERVER_URL"]
        return URL(string: configured ?? "http://localhost:8080")!
    }
}
