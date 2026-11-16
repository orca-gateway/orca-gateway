import OrcaGateway
import SwiftUI
import UIKit

/// The counter example on iOS: the same Bun server as the Flutter example,
/// drawn by the Swift SDK. Start the server with `t example:dev:server`.
///
/// Any example app on that server runs here too: set ORCA_APP_ID and
/// ORCA_PATH (for example `basic-actions` and `home`, or `server-actions`
/// and `shop`) in the scheme, or as SIMCTL_CHILD_ORCA_APP_ID and
/// SIMCTL_CHILD_ORCA_PATH for `simctl launch`. ORCA_OFFLINE=1 runs the
/// version check at boot (the force-update screen when the server answers
/// forceUpdate), and ORCA_SESSIONS=1 reports session starts and ends.
///
/// ORCA_BOOT=config starts from the server's navigation config instead of a
/// path (the host passes `path: nil`): its `initialRoute` is the first page and its `initialAppState` is
/// seeded. Use it with ORCA_APP_ID=navigation (`examples/server/navigation.ts`);
/// ORCA_PATH is not read then. The two switches above work in both modes.
///
/// Debug builds start Orca DevTools (ORCA_DEVTOOLS, ORCA_DEVTOOLS_HOST in
/// `init`). ORCA_OVERLAY=1 draws the load-time chip at the bottom right of
/// each page (a tap unfolds it), and ORCA_BODIES=1 puts the request and
/// response bodies in DevTools' network events. Both are off by default.
///
/// The app opens `orcacounter://` links (see "Deep links" in the README) and
/// prints one `OrcaCounter deeplink:` line for each.
///
/// ORCA_APP_ID=custom shows the two plugins below at work.
@main
struct OrcaCounterApp: App {
    init() {
        #if DEBUG
        // Debug builds show up in Orca DevTools (`t devtools:dev`, port 6363).
        // ORCA_DEVTOOLS=0 turns it off; ORCA_DEVTOOLS_HOST points a device at
        // the Mac running DevTools. ORCA_OVERLAY and ORCA_BODIES turn on
        // showOverlay and includeBodies.
        OrcaDebug.start(OrcaDebugConfig(
            enabled: Self.setting("ORCA_DEVTOOLS", "1") != "0",
            host: Self.setting("ORCA_DEVTOOLS_HOST", "localhost"),
            appName: "Orca Counter",
            showOverlay: Self.isOn("ORCA_OVERLAY"),
            includeBodies: Self.isOn("ORCA_BODIES")))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            let client = OrcaClient(baseURL: Self.serverURL, appId: Self.setting("ORCA_APP_ID", "counter"),
                                    apiKey: "demo-key")
            let path: String? = Self.setting("ORCA_BOOT", "path") == "config"
                ? nil : Self.setting("ORCA_PATH", "home")
            OrcaApp(
                client: client, path: path,
                enableOffline: Self.isOn("ORCA_OFFLINE"),
                enableSessionTracking: Self.isOn("ORCA_SESSIONS"),
                onDeeplink: Self.logDeeplink,
                plugins: [BadgePlugin(), DeviceActionsPlugin()])
        }
    }

    /// The example server. The simulator reaches the Mac at localhost; set
    /// ORCA_SERVER_URL in the scheme (or SIMCTL_CHILD_ORCA_SERVER_URL for
    /// `simctl launch`) to use another address.
    static var serverURL: URL {
        URL(string: setting("ORCA_SERVER_URL", "http://localhost:8080"))!
    }

    /// One line per `orcacounter://` link the app opened (the scheme is in
    /// Info.plist; OrcaApp receives the link itself). NSLog, not print: an app
    /// that a link started has no console, and the system log is read with
    /// `simctl spawn <device id> log stream` (see the README).
    static func logDeeplink(_ event: DeeplinkEvent) {
        let line = "OrcaCounter deeplink: incoming=\(event.incoming.absoluteString) "
            + "resolvedLocation=\(event.resolvedLocation) wasRedirected=\(event.wasRedirected) "
            + "isColdStart=\(event.isColdStart)"
        NSLog("%@", line)
    }

    static func setting(_ key: String, _ fallback: String) -> String {
        let value = ProcessInfo.processInfo.environment[key] ?? ""
        return value.isEmpty ? fallback : value
    }

    /// A switch: on when the setting is "1" or "true".
    static func isOn(_ key: String) -> Bool {
        ["1", "true"].contains(setting(key, ""))
    }
}

// MARK: - Plugins

/// Draws the `ColoredBadge` widget of the `custom` example app
/// (examples/server/custom.ts): its label in white bold on its color, and a
/// tap fires the node's onTap. The Swift twin of `_BadgePlugin` in the Flutter
/// example (examples/app/lib/main.dart). Registering it adds `ColoredBadge` to
/// the capabilities the app sends, so the server keeps the badges on the page.
struct BadgePlugin: OrcaPlugin {
    let name = "BadgePlugin"

    var widgets: [String: OrcaWidgetBuilder] {
        ["ColoredBadge": { node, model in
            AnyView(ColoredBadge(label: node["label"]?.stringValue ?? "",
                                 color: Self.color(hex: node["color"]?.stringValue ?? "#888888")) {
                _ = model.fire("onTap", on: node)
            })
        }]
    }

    /// `#RRGGBB`, as the Flutter builder reads it; grey when it is anything else.
    static func color(hex: String) -> Color {
        guard hex.count == 7, hex.hasPrefix("#"), let rgb = UInt32(hex.dropFirst(), radix: 16) else {
            return .gray
        }
        return Color(red: Double(rgb >> 16 & 0xFF) / 255, green: Double(rgb >> 8 & 0xFF) / 255,
                     blue: Double(rgb & 0xFF) / 255)
    }
}

/// The badge: padding 16 by 8 and a corner radius of 20, as the Flutter one.
/// A Button, not `onTapGesture`: a tap gesture fails when the finger stays
/// down about a second, where Flutter's GestureDetector still taps on release.
struct ColoredBadge: View {
    let label: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .tracking(1.2)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

/// The custom actions of the `custom` example app. `hapticFeedback` plays an
/// impact (`intensity` light, medium or heavy); `showConfetti`, `rateApp` and
/// `processPayment` print a line, as this example has no confetti or store
/// SDK. The Swift twin of `_DeviceActionsPlugin` in the Flutter example.
struct DeviceActionsPlugin: OrcaPlugin {
    let name = "DeviceActionsPlugin"

    var actions: [String: OrcaActionHandler] {
        [
            "hapticFeedback": { action, _ in
                let style: UIImpactFeedbackGenerator.FeedbackStyle
                switch action["intensity"].stringValue {
                case "light": style = .light
                case "heavy": style = .heavy
                default: style = .medium
                }
                await MainActor.run { UIImpactFeedbackGenerator(style: style).impactOccurred() }
            },
            "showConfetti": { action, _ in Self.log(action) },
            "rateApp": { action, _ in Self.log(action) },
            "processPayment": { action, _ in Self.log(action) },
        ]
    }

    /// The action as the server sent it, in the Xcode console (or the
    /// terminal, with `simctl launch --console`).
    static func log(_ action: JSONValue) {
        let json = (try? action.encoded()).map { String(decoding: $0, as: UTF8.self) } ?? "\(action)"
        print("[DeviceActionsPlugin] \(json)")
    }
}
