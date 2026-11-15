package com.orcagateway.core.client

/**
 * Small persisted strings the SDK keeps across launches: the device id and
 * the offline session queue. Flutter keeps them in SharedPreferences; the
 * Android module adapts SharedPreferences named "orca_gateway" to this, and
 * the core stays testable on the JVM. Swift twin: `KeyValueStore` with
 * `string(forKey:)` and `set(_:forKey:)`.
 */
public interface KeyValueStore {
    /** The string saved under [key], or null when there is none. */
    public fun getString(key: String): String?

    /** Saves [value] under [key]; null removes the key. */
    public fun putString(key: String, value: String?)
}

/**
 * A [KeyValueStore] held in memory, for tests and for hosts that persist
 * nothing. Thread-safe. [snapshot] gives its contents, so a test can start a
 * second store over them as an app restart would. Swift twin:
 * `MemoryKeyValueStore`.
 */
public class MemoryKeyValueStore(initial: Map<String, String> = emptyMap()) : KeyValueStore {
    private val lock = Any()
    private val values = HashMap(initial)

    override fun getString(key: String): String? = synchronized(lock) { values[key] }

    override fun putString(key: String, value: String?) {
        synchronized(lock) {
            if (value == null) values.remove(key) else values[key] = value
        }
    }

    /** A copy of everything saved. */
    public fun snapshot(): Map<String, String> = synchronized(lock) { values.toMap() }
}
