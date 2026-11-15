package com.orcagateway.core.client

import java.util.UUID

/**
 * The anonymous per-install device id the client sends as
 * `x-orca-device-id`, so the cloud can count active devices. Flutter resolves
 * one at boot in `_resolveDeviceId` (sdk/lib/src/widgets/orca_app.dart) and
 * hands it to the client with `setDeviceId`
 * (sdk/lib/src/client/orca_client.dart); here it goes in as
 * [OrcaClient.deviceId]. Swift twin: `DeviceIdentity`.
 *
 * The native SDKs differ on purpose: Flutter reads identifierForVendor or
 * ANDROID_ID, while Android and iOS keep a random id stored on first run.
 */
public object DeviceIdentity {
    /** The key the id is saved under. */
    public const val STORAGE_KEY: String = "orca_device_id"

    /**
     * The id saved in [store]. When none is saved, or it is empty, a new
     * random lowercase UUID is saved and returned.
     */
    public fun resolve(store: KeyValueStore): String {
        store.getString(STORAGE_KEY)?.takeIf { it.isNotEmpty() }?.let { return it }
        val id = UUID.randomUUID().toString()
        store.putString(STORAGE_KEY, id)
        return id
    }
}
