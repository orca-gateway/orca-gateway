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

/// What OrcaApp does before its first page, the part of `_OrcaAppState`'s
/// boot in sdk/lib/src/widgets/orca_app.dart the natives have so far: with
/// `enableOffline`, the version check of `OrcaApp.preload`; a forceUpdate
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
    }

    @Published private(set) var phase: Phase
    let enableOffline: Bool
    let enableSessionTracking: Bool
    /// Where the device id and the offline session queue are kept.
    let store: KeyValueStore
    private var started = false
    private var tracker: SessionTracker?

    init(enableOffline: Bool, enableSessionTracking: Bool = false,
         store: KeyValueStore = UserDefaultsKeyValueStore()) {
        self.enableOffline = enableOffline
        self.enableSessionTracking = enableSessionTracking
        self.store = store
        phase = enableOffline ? .checking : .ready
    }

    /// Run the version check once, with no local versions yet (the static
    /// flow cache arrives with plan step 14).
    func start(client: OrcaClient) async {
        guard enableOffline, !started else { return }
        started = true
        let outcome = await VersionChecker(client: client).check(localVersions: [:])
        phase = outcome.result == .forceUpdate ? .forceUpdate : .ready
    }

    /// The one SessionTracker of this app, made on first use from `client`
    /// with its device id (the stored one when it has none) and an offline
    /// queue in the store; nil without `enableSessionTracking`.
    func sessionTracker(client: OrcaClient) -> SessionTracker? {
        guard enableSessionTracking else { return nil }
        if let tracker { return tracker }
        let made = SessionTracker(
            client: client, deviceId: client.identified(by: store).deviceId,
            offline: OfflineSessionStore(store: store))
        tracker = made
        return made
    }
}

/// OrcaApp's root: the spinner while the version check runs, the
/// force-update screen when the server demands one, else `content`, which is
/// built only then. Sessions are tracked here, around all three.
@MainActor
struct OrcaBootView<Content: View>: View {
    @ObservedObject var boot: OrcaBootModel
    let client: OrcaClient
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            switch boot.phase {
            case .checking:
                ProgressView()
            case .forceUpdate:
                ForceUpdateView()
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
