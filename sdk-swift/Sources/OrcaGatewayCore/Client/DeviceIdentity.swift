import Foundation

/// The anonymous per-install device id the client sends as
/// `x-orca-device-id`, so the cloud can count distinct active devices.
/// A port of `_resolveDeviceId` in sdk/lib/src/widgets/orca_app.dart, which
/// hands the id to the client through `setDeviceId` in
/// sdk/lib/src/client/orca_client.dart (here: `OrcaClient.deviceId`).
///
/// Where the native SDKs differ: Flutter reads identifierForVendor on iOS and
/// ANDROID_ID on Android; the natives make a random id on first run and keep
/// it in a KeyValueStore.
public enum DeviceIdentity {
    /// The key the id is saved under.
    public static let storageKey = "orca_device_id"

    /// The saved id, or, when none is saved or it is empty, a new random
    /// lowercase UUID, which is saved and returned.
    public static func resolve(_ store: KeyValueStore) -> String {
        if let saved = store.string(forKey: storageKey), !saved.isEmpty { return saved }
        let id = UUID().uuidString.lowercased()
        store.set(id, forKey: storageKey)
        return id
    }
}
