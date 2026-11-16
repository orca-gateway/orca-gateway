package com.orcagateway.core.client

import java.io.File
import java.io.IOException

/**
 * A [KeyValueStore] on disk, one file per key under [directory], for what
 * must survive a restart: the offline cache of [StaticFlowManager] (Flutter
 * keeps it in SharedPreferences). The Android module passes
 * `context.filesDir/orca_gateway`; the directory is made on the first write.
 * Swift twin `FileKeyValueStore`.
 *
 * A key's file name is the key's UTF-8 bytes with every byte outside
 * `[A-Za-z0-9_-]` written `%XX` (the dot too, so no name is `.` or `..`) and
 * the empty key named `%`, so two keys never share a file and no key
 * reaches outside [directory]. A write goes to a temporary file in
 * [directory] first, then is renamed over the key's file in one atomic step
 * (rename(2) on Android and Linux), so a reader sees the old text or the new
 * one, never a part. Temporary names start with `~`, which no key's name does.
 *
 * All file work is `java.io`, no `java.nio.file`: core ships in the Android
 * SDK at minSdk 24, and `java.nio.file` exists on Android only from API 26.
 *
 * Thread-safe. Like the SharedPreferences store's `apply()`, it never
 * throws: a write that fails keeps what was saved before, and a file that
 * cannot be read reads as absent.
 */
public class FileKeyValueStore(public val directory: File) : KeyValueStore {
    private val lock = Any()

    /** The text saved under [key], or null when there is none or it cannot be read. */
    override fun getString(key: String): String? = synchronized(lock) {
        try {
            fileOf(key).readText(Charsets.UTF_8)
        } catch (_: IOException) {
            null
        }
    }

    /** Saves [value] under [key] with an atomic rename; null deletes the key's file. */
    override fun putString(key: String, value: String?) {
        synchronized(lock) {
            try {
                if (value == null) {
                    fileOf(key).delete()
                    return
                }
                directory.mkdirs()
                // java.io wants a prefix of three characters or more.
                val temp = File.createTempFile("~orca", ".tmp", directory)
                var renamed = false
                try {
                    temp.writeText(value, Charsets.UTF_8)
                    renamed = temp.renameTo(fileOf(key))
                } finally {
                    if (!renamed) temp.delete()
                }
            } catch (_: IOException) {
                // Kept as before, as SharedPreferences.apply() reports nothing.
            }
        }
    }

    private fun fileOf(key: String): File = File(directory, fileName(key))

    private companion object {
        const val HEX = "0123456789ABCDEF"

        fun fileName(key: String): String {
            if (key.isEmpty()) return "%"
            val out = StringBuilder()
            for (byte in key.encodeToByteArray()) {
                val b = byte.toInt() and 0xFF
                val c = b.toChar()
                if (c in 'A'..'Z' || c in 'a'..'z' || c in '0'..'9' || c == '_' || c == '-') {
                    out.append(c)
                } else {
                    out.append('%').append(HEX[b shr 4]).append(HEX[b and 0xF])
                }
            }
            return out.toString()
        }
    }
}
