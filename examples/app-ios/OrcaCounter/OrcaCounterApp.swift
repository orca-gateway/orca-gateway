import OrcaGateway
import SwiftUI

/// The counter example on iOS: the same Bun server as the Flutter example,
/// drawn by the Swift SDK. Start the server with `t example:dev:server`.
///
/// Any example app on that server runs here too: set ORCA_APP_ID and
/// ORCA_PATH (for example `basic-actions` and `home`, or `server-actions`
/// and `shop`) in the scheme, or as SIMCTL_CHILD_ORCA_APP_ID and
/// SIMCTL_CHILD_ORCA_PATH for `simctl launch`.
@main
struct OrcaCounterApp: App {
    init() {
        #if DEBUG
        // Debug builds show up in Orca DevTools (`t devtools:dev`, port 6363).
        // ORCA_DEVTOOLS=0 turns it off; ORCA_DEVTOOLS_HOST points a device at
        // the Mac running DevTools.
        OrcaDebug.start(OrcaDebugConfig(
            enabled: Self.setting("ORCA_DEVTOOLS", "1") != "0",
            host: Self.setting("ORCA_DEVTOOLS_HOST", "localhost"),
            appName: "Orca Counter"))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            OrcaApp(
                client: OrcaClient(baseURL: Self.serverURL, appId: Self.setting("ORCA_APP_ID", "counter"),
                                   apiKey: "demo-key"),
                path: Self.setting("ORCA_PATH", "home"))
        }
    }

    /// The example server. The simulator reaches the Mac at localhost; set
    /// ORCA_SERVER_URL in the scheme (or SIMCTL_CHILD_ORCA_SERVER_URL for
    /// `simctl launch`) to use another address.
    static var serverURL: URL {
        URL(string: setting("ORCA_SERVER_URL", "http://localhost:8080"))!
    }

    static func setting(_ key: String, _ fallback: String) -> String {
        let value = ProcessInfo.processInfo.environment[key] ?? ""
        return value.isEmpty ? fallback : value
    }
}
