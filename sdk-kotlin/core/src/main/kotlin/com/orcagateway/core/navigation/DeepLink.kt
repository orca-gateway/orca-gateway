package com.orcagateway.core.navigation

import com.orcagateway.core.json.JsonValue

/**
 * What the deep link callback receives, once per link, after the navigation
 * has settled and after the route change callback (Dart `OrcaDeeplinkEvent`).
 * Built by [DeepLink.event].
 */
public data class DeeplinkEvent(
    /** The link as the platform delivered it. */
    val incoming: String,
    /** The final location, after the redirect: path and query. */
    val resolvedLocation: String,
    /** Path parameters of every matched level of the final location; empty on the not-found route. */
    val pathParameters: Map<String, String>,
    /** Query parameters of the final location. */
    val queryParameters: Map<String, String>,
    /** A redirect rule ran: the final path differs from the path of the link's location. */
    val wasRedirected: Boolean,
    /** The link is what opened the app. */
    val isColdStart: Boolean,
)

/** What [TabShell.open] did. */
public data class DeepLinkNavigation(
    /** What the link's location resolved to, also when nothing changed. */
    val resolution: RouteResolution,
    /** What the shell changed; nothing when the location was on screen. */
    val change: TabShellChange,
)

/**
 * Deep links, pure: a link is a URL the platform hands to the app, and the
 * app goes to its [location] as a `go` ([TabShell.open]). Pinned by the `links` of
 * schema/fixtures/navigation.
 */
public object DeepLink {
    /**
     * The location of [link]: its path and its query, nothing else. Scheme,
     * host (user info and port with it) and fragment are dropped, an empty
     * path is `/`, trailing slashes are dropped, a path without a leading
     * slash gets one. Path and query are kept as given (no decoding); an
     * empty query is no query. `app://account` has host `account` and
     * location `/`. Never throws: any string has a location.
     */
    public fun location(link: String): String {
        var rest = link.substringBefore('#')
        // `scheme:` is a letter, then letters, digits, `+`, `-` or `.`, up to the first colon.
        val colon = rest.indexOf(':')
        if (colon > 0 && rest[0].isAsciiLetter() &&
            (1 until colon).all { rest[it].isAsciiLetter() || rest[it] in '0'..'9' || rest[it] in "+-." }
        ) {
            rest = rest.substring(colon + 1)
        }
        // `//host` runs to the path or to the query.
        if (rest.startsWith("//")) {
            val end = rest.indexOfAny(charArrayOf('/', '?'), startIndex = 2)
            rest = if (end < 0) "" else rest.substring(end)
        }
        val mark = rest.indexOf('?')
        val path = (if (mark < 0) rest else rest.substring(0, mark)).trimEnd('/')
        val query = if (mark < 0) "" else rest.substring(mark + 1)
        val slashed = if (path.startsWith("/")) path else "/$path"
        return if (query.isEmpty()) slashed else "$slashed?$query"
    }

    /**
     * The event of [link], given what its [location] resolved to
     * (`table.resolve(DeepLink.location(link), appState)`, or the
     * `resolution` of [TabShell.open]) and whether the link opened the app.
     */
    public fun event(link: String, resolution: RouteResolution, coldStart: Boolean): DeeplinkEvent = DeeplinkEvent(
        incoming = link,
        resolvedLocation = resolution.location,
        pathParameters = resolution.params,
        queryParameters = resolution.queryParameters,
        wasRedirected = resolution.redirected,
        isColdStart = coldStart,
    )

    private fun Char.isAsciiLetter(): Boolean = this in 'a'..'z' || this in 'A'..'Z'
}

/**
 * Opens a link's location ([DeepLink.location]): a [TabShell.go], so the
 * stack and the tab come from the config and the asked route's redirect rule
 * is applied once. On a fresh shell this is the boot of a cold link: the app
 * starts at the link, not at the initial route. When the link ends on the
 * location already on screen, itself or by its redirect, nothing changes and
 * nothing is requested; the resolution is returned all the same, for the
 * event.
 */
public fun TabShell.open(link: String, appState: Map<String, JsonValue>): DeepLinkNavigation {
    val resolution = table.resolve(if (link.startsWith("/")) link else "/$link", appState)
    if (visible.isNotEmpty() && resolution.location == location) return DeepLinkNavigation(resolution, TabShellChange())
    return DeepLinkNavigation(resolution, go(link, appState))
}
