package com.orcagateway.core.capabilities

import kotlinx.serialization.Serializable
import java.security.MessageDigest

/**
 * What this SDK build can render, sent to the server as `X-Orca-Caps-Hash`
 * (and as the full vector on a 412 retry) so it can degrade the rest. The
 * shipped values live in [GeneratedCapabilities], written by
 * schema/gen-native-capabilities.ts.
 */
@Serializable
public data class CapabilityVector(
    public val protocolVersion: String,
    public val sdkSemver: String,
    public val widgets: List<String>,
    public val valueKinds: List<String>,
    public val actionKinds: List<String>,
    public val transformKinds: List<String>,
    public val boolExprOps: List<String>,
) {
    /**
     * The engine's `canonicalizeVector`
     * (engine/src/core/capability-vector-cache.ts): keys in this fixed order,
     * every array sorted by UTF-16 code units, `JSON.stringify` with no
     * whitespace. One byte of drift makes every request take the 412 path.
     */
    public fun canonicalJson(): String {
        fun array(items: List<String>): String =
            // String.compareTo orders by UTF-16 code units, as Array.prototype.sort.
            items.sorted().joinToString(",", "[", "]") { jsString(it) }
        return "{" +
            "\"protocolVersion\":" + jsString(protocolVersion) +
            ",\"sdkSemver\":" + jsString(sdkSemver) +
            ",\"widgets\":" + array(widgets) +
            ",\"valueKinds\":" + array(valueKinds) +
            ",\"actionKinds\":" + array(actionKinds) +
            ",\"transformKinds\":" + array(transformKinds) +
            ",\"boolExprOps\":" + array(boolExprOps) +
            "}"
    }

    /** Lowercase hex SHA-256 of [canonicalJson], the `X-Orca-Caps-Hash` value. */
    public val hash: String
        get() = MessageDigest.getInstance("SHA-256")
            .digest(canonicalJson().toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

    /**
     * This vector with plugin [widgets] and [actions] added, as the Dart
     * client advertises them (`registerCapabilityExtensions` and
     * `_capabilityVector`, sdk/lib/src/client/orca_client.dart): widgets
     * verbatim, each action bare and as `custom:<name>` unless it already
     * has the prefix. Both lists become the sorted union, without
     * duplicates; the other fields stay.
     */
    public fun adding(widgets: Iterable<String> = emptyList(), actions: Iterable<String> = emptyList()): CapabilityVector {
        val kinds = actions.flatMap { if (it.startsWith(CUSTOM_PREFIX)) listOf(it) else listOf(it, CUSTOM_PREFIX + it) }
        return copy(
            widgets = (this.widgets + widgets).distinct().sorted(),
            actionKinds = (actionKinds + kinds).distinct().sorted(),
        )
    }

    public companion object {
        private const val CUSTOM_PREFIX = "custom:"

        /** The vector this build advertises. */
        public val current: CapabilityVector = CapabilityVector(
            protocolVersion = GeneratedCapabilities.protocolVersion,
            sdkSemver = GeneratedCapabilities.sdkSemver,
            widgets = GeneratedCapabilities.widgets,
            valueKinds = GeneratedCapabilities.valueKinds,
            actionKinds = GeneratedCapabilities.actionKinds,
            transformKinds = GeneratedCapabilities.transformKinds,
            boolExprOps = GeneratedCapabilities.boolExprOps,
        )

        /**
         * `JSON.stringify` of a string: escapes `"`, `\` and control characters,
         * leaves `/` and non-ASCII alone.
         */
        internal fun jsString(s: String): String = buildString {
            append('"')
            for (c in s) {
                when {
                    c == '"' -> append("\\\"")
                    c == '\\' -> append("\\\\")
                    c == '\b' -> append("\\b")
                    c == '\u000C' -> append("\\f")
                    c == '\n' -> append("\\n")
                    c == '\r' -> append("\\r")
                    c == '\t' -> append("\\t")
                    c.code < 0x20 -> append("\\u").append(c.code.toString(16).padStart(4, '0'))
                    else -> append(c)
                }
            }
            append('"')
        }
    }
}
