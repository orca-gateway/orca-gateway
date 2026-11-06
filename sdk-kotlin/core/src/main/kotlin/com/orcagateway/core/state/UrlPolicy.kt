package com.orcagateway.core.state

import java.net.URI
import java.net.URISyntaxException
import java.util.Locale

/**
 * Which URLs an `openUrl` action (or a tapped link) may open: http, https
 * and mailto, plus any schemes the host opts into (Flutter `OrcaUrlPolicy`,
 * sdk/lib/src/state/url_scheme_policy.dart, where tel and sms are opt-in).
 * Anything else is dropped without a word, after the effect was reported.
 *
 * Text is parsed with [java.net.URI], which refuses what RFC 3986 refuses
 * (a space, say); recent Foundation versions percent-encode such characters
 * instead and accept the URL.
 */
public class OrcaUrlPolicy(extraSchemes: Set<String> = emptySet()) {
    public val allowedSchemes: Set<String> = defaultSchemes + extraSchemes.map { it.lowercase(Locale.ROOT) }

    public fun isAllowed(url: URI): Boolean {
        val scheme = url.scheme?.lowercase(Locale.ROOT) ?: return false
        return scheme in allowedSchemes
    }

    /** The URL in [text], when it parses and is allowed. */
    public fun url(text: String): URI? {
        val url = try {
            URI(text)
        } catch (_: URISyntaxException) {
            return null
        }
        return if (isAllowed(url)) url else null
    }

    override fun equals(other: Any?): Boolean = other is OrcaUrlPolicy && other.allowedSchemes == allowedSchemes

    override fun hashCode(): Int = allowedSchemes.hashCode()

    public companion object {
        public val defaultSchemes: Set<String> = setOf("http", "https", "mailto")

        public val standard: OrcaUrlPolicy = OrcaUrlPolicy()
    }
}
