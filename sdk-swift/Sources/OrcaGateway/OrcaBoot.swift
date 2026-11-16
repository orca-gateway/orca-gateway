#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// A KeyValueStore over UserDefaults (`.standard` by default), the Swift side
/// of the SharedPreferences sdk/lib/src/widgets/orca_app.dart and
/// sdk/lib/src/client/offline_session_store.dart write to. OrcaApp keeps the
/// device id and the offline session queue in it; a host can use it with
/// `DeviceIdentity.resolve` to give its own client the same id.
public final class UserDefaultsKeyValueStore: KeyValueStore, @unchecked Sendable {
    public let defaults: UserDefaults

    public init(_ defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved string for `key`, or nil.
    public func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    /// Saves `value` under `key`; nil removes the key.
    public func set(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

extension FileKeyValueStore {
    /// The store OrcaApp uses with `enableOffline` when the host gives no
    /// `staticFlowManager` (Flutter's `StaticFlowManager()` keeps it in the
    /// app's SharedPreferences): Application Support/<bundle id>/OrcaGateway,
    /// or Application Support/OrcaGateway when the main bundle has no id,
    /// created by the first save. A host that runs `preload` during its own
    /// splash builds its cache over this store, so the two share one cache:
    ///
    ///     let cache = StaticFlowManager(store: FileKeyValueStore.applicationSupport())
    ///     if case .success(let config) = try await preload(client: client, cache: cache) {
    ///         OrcaApp(client: client, preloadedConfig: config, staticFlowManager: cache)
    ///     }
    public static func applicationSupport() -> FileKeyValueStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return applicationSupport(in: support, bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    /// The store under `support`: <bundleIdentifier>/OrcaGateway, or
    /// OrcaGateway with no id. Nothing is created here.
    static func applicationSupport(in support: URL, bundleIdentifier: String?) -> FileKeyValueStore {
        var directory = support
        if let bundleIdentifier {
            directory.appendPathComponent(bundleIdentifier, isDirectory: true)
        }
        return FileKeyValueStore(directory: directory.appendingPathComponent("OrcaGateway", isDirectory: true))
    }
}

extension OrcaClient {
    /// This client with a device id: its own when it has one, else the one
    /// saved in `store` (made on first run), as `_resolveDeviceId` in
    /// sdk/lib/src/widgets/orca_app.dart gives the client an id whether or
    /// not sessions are tracked.
    func identified(by store: KeyValueStore) -> OrcaClient {
        guard deviceId?.isEmpty ?? true else { return self }
        var client = self
        client.deviceId = DeviceIdentity.resolve(store)
        return client
    }
}

/// What OrcaApp does before its first page outside the config boot, part of
/// `_OrcaAppState`'s boot in sdk/lib/src/widgets/orca_app.dart: with
/// `enableOffline`, the version check of `OrcaApp.preload` alone (OrcaApp
/// asks for it with a host `path` or a host's router, which cache nothing;
/// its config boot runs `preload` in `OrcaAppBoot` instead); a forceUpdate
/// answer blocks the app, any other answer boots it. Without it the app is
/// ready at once and asks nothing. Internal: only OrcaApp drives it.
@MainActor
final class OrcaBootModel: ObservableObject {
    enum Phase: Equatable {
        /// The version check runs; the spinner shows.
        case checking
        /// Pages may load.
        case ready
        /// The server demands an update; no page is ever fetched.
        case forceUpdate
        /// The app cannot start (a plugin conflict, Flutter's boot error):
        /// Flutter's default error screen shows with this message, and
        /// nothing is fetched.
        case failed(String)
    }

    @Published private(set) var phase: Phase
    let enableOffline: Bool
    let enableSessionTracking: Bool
    /// Where the device id and the offline session queue are kept.
    let store: KeyValueStore
    private var started = false
    private var tracker: SessionTracker?

    /// With a `failure` (OrcaPluginHost's conflict) the app starts failed.
    init(enableOffline: Bool, enableSessionTracking: Bool = false,
         store: KeyValueStore = UserDefaultsKeyValueStore(), failure: String? = nil) {
        self.enableOffline = enableOffline
        self.enableSessionTracking = enableSessionTracking
        self.store = store
        phase = failure.map(Phase.failed) ?? (enableOffline ? .checking : .ready)
    }

    /// Run the version check once, with no local versions: a `path` or a
    /// host's router keeps no flow versions.
    func start(client: OrcaClient) async {
        guard enableOffline, !started, phase == .checking else { return }
        started = true
        let outcome = await VersionChecker(client: client).check(localVersions: [:])
        phase = outcome.result == .forceUpdate ? .forceUpdate : .ready
    }

    /// The one SessionTracker of this app, made on first use from `client`
    /// with its device id (the stored one when it has none) and an offline
    /// queue in the store; nil without `enableSessionTracking` or when the
    /// app failed to start.
    func sessionTracker(client: OrcaClient) -> SessionTracker? {
        guard enableSessionTracking else { return nil }
        if case .failed = phase { return nil }
        if let tracker { return tracker }
        let made = SessionTracker(
            client: client, deviceId: client.identified(by: store).deviceId,
            offline: OfflineSessionStore(store: store))
        tracker = made
        return made
    }
}

/// The host's boot views, OrcaApp's `loadingView`, `splashView`, `errorView`
/// and `forceUpdateView` (Flutter `OrcaApp.loadingWidget`, `splashWidget`,
/// `errorBuilder` and `forceUpdateBuilder`, sdk/lib/src/widgets/orca_app.dart);
/// each nil draws the SDK's own. Boot only: pages keep the SDK's spinner
/// and error screen.
struct BootViews {
    var loading: (() -> AnyView)? = nil
    var splash: (() -> AnyView)? = nil
    var error: ((Error) -> AnyView)? = nil
    var forceUpdate: (() -> AnyView)? = nil

    /// Flutter `_buildSplash`: the splash, else the loading view, else the
    /// SDK's spinner.
    @MainActor @ViewBuilder
    func splashScreen() -> some View {
        if let host = splash ?? loading {
            host()
        } else {
            ProgressView()
        }
    }

    /// Flutter `_buildForceUpdate`: the host's view, else `ForceUpdateView`.
    @MainActor @ViewBuilder
    func forceUpdateScreen() -> some View {
        if let forceUpdate {
            forceUpdate()
        } else {
            ForceUpdateView()
        }
    }

    /// Flutter `_buildError`: the host's view given `error`, drawn alone,
    /// else the SDK's screen.
    @MainActor @ViewBuilder
    func errorScreen<SDKScreen: View>(_ error: Error, sdk: () -> SDKScreen) -> some View {
        if let host = self.error {
            host(error)
        } else {
            sdk()
        }
    }
}

/// OrcaApp's root: the splash while the version check runs, the
/// force-update screen when the server demands one, the error when the app
/// cannot start (each the host's when given), else `content`, which is
/// built only then. Sessions are tracked here, around all of them but the
/// error.
@MainActor
struct OrcaBootView<Content: View>: View {
    @ObservedObject var boot: OrcaBootModel
    let client: OrcaClient
    var views = BootViews()
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            switch boot.phase {
            case .checking:
                views.splashScreen()
            case .forceUpdate:
                views.forceUpdateScreen()
            case .failed(let message):
                // Flutter's ArgumentError: its default screen, with the
                // conflict's own words. No retry: a conflict stays one.
                let conflict = OrcaPluginConflict(message: message)
                views.errorScreen(conflict) { OrcaErrorView(error: conflict, message: message) }
            case .ready:
                content()
            }
        }
        .orcaSessionTracking(boot.sessionTracker(client: client))
        .task { await boot.start(client: client) }
    }
}

/// Flutter's default force-update screen (`_buildForceUpdate` in
/// sdk/lib/src/widgets/orca_app.dart): one centred line.
struct ForceUpdateView: View {
    var body: some View {
        Text("Update required. Please update the app.")
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("orca.forceUpdate")
    }
}
#endif
