import OrcaGateway
import OrcaGoogleMap
import OrcaVideoPlayer
import OrcaVoiceRecorder
import SwiftUI
import UIKit

/// The counter example on iOS: the same Bun server as the Flutter example,
/// drawn by the Swift SDK. Start the server with `t example:dev:server`.
///
/// Any example app on that server runs here too: set ORCA_APP_ID and
/// ORCA_PATH (for example `basic-actions` and `home`, or `server-actions`
/// and `shop`) in the scheme, or as SIMCTL_CHILD_ORCA_APP_ID and
/// SIMCTL_CHILD_ORCA_PATH for `simctl launch`. ORCA_OFFLINE=1 turns on
/// `enableOffline`: with a path the version check at boot (the force-update
/// screen when the server answers forceUpdate), with ORCA_BOOT=config the
/// offline boot as well (the saved config and static pages; see "Offline" in
/// the README). ORCA_SESSIONS=1 reports session starts and ends.
///
/// ORCA_BOOT=config starts from the server's navigation config instead of a
/// path (the host passes `path: nil`): its `initialRoute` is the first page and its `initialAppState` is
/// seeded. Use it with ORCA_APP_ID=navigation (`examples/server/navigation.ts`);
/// ORCA_PATH is not read then. The two switches above work in both modes.
///
/// ORCA_PRELOAD=1, with ORCA_BOOT=config only, runs that offline boot in the
/// host instead (`HostPreload` below): its own splash awaits `preload`, then
/// OrcaApp gets the config and the cache. It implies the offline cache, with
/// or without ORCA_OFFLINE. Try both with ORCA_APP_ID=static-flows.
///
/// Debug builds start Orca DevTools (ORCA_DEVTOOLS, ORCA_DEVTOOLS_HOST in
/// `init`). ORCA_OVERLAY=1 draws the load-time chip at the bottom right of
/// each page (a tap unfolds it), and ORCA_BODIES=1 puts the request and
/// response bodies in DevTools' network events. Both are off by default.
///
/// The app opens `orcacounter://` links (see "Deep links" in the README) and
/// prints one `OrcaCounter deeplink:` line for each.
///
/// ORCA_APP_ID=custom shows the two plugins below at work, the voice
/// recorder (`VoiceRecorderPlugin`, from plugins/orca_voice_recorder/ios) behind
/// its home page's "Go to Voice Page", the video player (`VideoPlayerPlugin`,
/// from plugins/orca_video_player/ios) behind its "Go to Video Page", and the
/// Google map (`GoogleMapPlugin`, from plugins/orca_google_map/ios, drawn with
/// MapKit) behind its "Go to Map Page".
///
/// Five more switches try the screens OrcaApp draws around the pages; unset,
/// each leaves the app as it was. ORCA_API_KEY (default `demo-key`): any other
/// key gets the server's 401, so the Unauthorized screen shows. ORCA_SCHEME
/// (`dark` or `light`) is OrcaApp's colorScheme; unset follows the system.
/// ORCA_LOCALE (a BCP-47 tag such as `ar` or `fr-FR`) is OrcaApp's locale;
/// unset is the device's. ORCA_SPLASH=1 gives OrcaApp the host's own splash
/// (`HostSplash` below), shown while the version check runs or the config is
/// asked for. ORCA_TIMEOUT (seconds) is the client's timeout; unset keeps the
/// SDK's 30.
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
            let path: String? = Self.setting("ORCA_BOOT", "path") == "config"
                ? nil : Self.setting("ORCA_PATH", "home")
            if path == nil && Self.isOn("ORCA_PRELOAD") {
                HostPreload(client: Self.client) { config, cache in
                    Self.app(path: nil, preloadedConfig: config, staticFlowManager: cache)
                }
            } else {
                Self.app(path: path)
            }
        }
    }

    /// OrcaApp with the switches above. ORCA_PRELOAD's host gives it the
    /// config and the cache its own preload used.
    static func app(path: String?, preloadedConfig: NavConfig? = nil,
                    staticFlowManager: StaticFlowManager? = nil) -> OrcaApp {
        OrcaApp(
            client: client, path: path,
            enableOffline: isOn("ORCA_OFFLINE"),
            preloadedConfig: preloadedConfig, staticFlowManager: staticFlowManager,
            enableSessionTracking: isOn("ORCA_SESSIONS"),
            onDeeplink: logDeeplink,
            plugins: [BadgePlugin(), DeviceActionsPlugin(), VoiceRecorderPlugin(), VideoPlayerPlugin(),
                      GoogleMapPlugin()],
            splashView: isOn("ORCA_SPLASH") ? { AnyView(HostSplash()) } : nil,
            colorScheme: colorScheme, locale: locale)
    }

    /// ORCA_APP_ID's app with ORCA_API_KEY. ORCA_TIMEOUT sets the timeout
    /// only when given, so unset keeps the SDK's own.
    static var client: OrcaClient {
        var client = OrcaClient(baseURL: serverURL, appId: setting("ORCA_APP_ID", "counter"),
                                apiKey: setting("ORCA_API_KEY", "demo-key"))
        if let seconds = TimeInterval(setting("ORCA_TIMEOUT", "")) { client.timeout = seconds }
        return client
    }

    /// ORCA_SCHEME: `dark` or `light`; anything else, or unset, is nil and
    /// follows the system.
    static var colorScheme: ColorScheme? {
        switch setting("ORCA_SCHEME", "") {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    /// ORCA_LOCALE as a locale; unset is nil, the device's.
    static var locale: Locale? {
        let tag = setting("ORCA_LOCALE", "")
        return tag.isEmpty ? nil : Locale(identifier: tag)
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

// MARK: - Host splash

/// The host's own splash (ORCA_SPLASH=1), in place of the SDK's spinner: the
/// app's name over a colour of its own, so it cannot pass for the SDK's. The
/// caption ends with the locale OrcaApp gives its views, so ORCA_LOCALE shows.
private struct HostSplash: View {
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            Color.indigo.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Orca Counter")
                    .font(.system(size: 40, weight: .bold))
                Text("host splash · \(locale.identifier)")
                    .font(.footnote)
                    .opacity(0.8)
            }
            .foregroundColor(.white)
        }
        .accessibilityIdentifier("hostSplash")
    }
}

// MARK: - ORCA_PRELOAD

/// The host's own splash for ORCA_PRELOAD=1: it awaits `preload` (Dart
/// `OrcaApp.preload`) over `FileKeyValueStore.applicationSupport()`, the store
/// OrcaApp's `enableOffline` uses, then shows `app` with the config and the
/// same cache, so OrcaApp asks for nothing and its first frame is the first
/// page. A force update and a failed preload are the host's to show, each as
/// one plain line; offline with nothing saved the line is the error's
/// "No network and no cached config available". Relaunch to try again.
struct HostPreload<Content: View>: View {
    let client: OrcaClient
    @ViewBuilder let app: (NavConfig, StaticFlowManager) -> Content
    @State private var cache = StaticFlowManager(store: FileKeyValueStore.applicationSupport())
    /// nil while the splash shows.
    @State private var result: Result<PreloadResult, Error>?

    var body: some View {
        switch result {
        case nil:
            VStack(spacing: 16) {
                ProgressView()
                Text("Checking version...")
            }
            .task {
                do {
                    result = .success(try await preload(client: client, cache: cache))
                } catch {
                    result = .failure(error)
                }
            }
        case .success(.success(let config)):
            app(config, cache)
        case .success(.forceUpdate):
            Text("Update required")
        case .failure(let error):
            Text(error.localizedDescription).multilineTextAlignment(.center).padding()
        }
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
