package com.orcagateway.core.navigation

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * [DeepLink] directly: the location of a link (design D1) on the inputs the
 * fixture pins and on odd ones it does not (every pair of the Swift twin's
 * `DeepLinkTests`), the event of a link (D3), and a link as a `go` that
 * leaves the location on screen alone (D5).
 */
class DeepLinkTest {
    private val table = RouteTable(
        NavConfig.fromJson(
            obj(
                "initialRoute" to "/home",
                "initialAppState" to mapOf("loggedIn" to false),
                "flows" to listOf(
                    mapOf(
                        "name" to "main",
                        "routes" to listOf(
                            mapOf("path" to "home"),
                            mapOf("path" to "settings"),
                            mapOf("path" to "login"),
                            mapOf("path" to "order/:id"),
                            mapOf(
                                "path" to "account",
                                "redirect" to mapOf("when" to "loggedIn", "equals" to false, "to" to "/login?why=link"),
                            ),
                        ),
                    ),
                ),
            ),
        ),
    )
    private val loggedOut: Map<String, JsonValue> = props("loggedIn" to false)

    /** The pairs of Swift `DeepLinkTests.test_L1_locationOfALink`, in its order. */
    @Test
    fun l1_locationOfALink() {
        val pinned = listOf(
            // https: scheme and host dropped.
            "https://shop.example/settings" to "/settings",
            // A custom scheme: the first part after `//` is a host.
            "orcashop://open/settings" to "/settings",
            "orcashop://settings" to "/",
            // The query is kept as given, the fragment dropped.
            "https://shop.example/settings?tab=2&ref=mail#top" to "/settings?tab=2&ref=mail",
            "https://shop.example/account?tab=2#x" to "/account?tab=2",
            "app://host/account?tab=2" to "/account?tab=2",
            // A trailing slash is dropped; an empty path is "/".
            "https://shop.example/settings/" to "/settings",
            "https://shop.example/settings/?tab=2" to "/settings?tab=2",
            "https://shop.example" to "/",
            "https://shop.example/" to "/",
            "https://shop.example?x=1" to "/?x=1",
            // The path keeps its case.
            "https://shop.example/Settings" to "/Settings",
            "orcashop://open/order/7?gift=1" to "/order/7?gift=1",
        )
        for ((link, location) in pinned) assertEquals(location, DeepLink.location(link), link)
    }

    /** The pairs of Swift `DeepLinkTests.test_L1_oddLinks`, in its order. */
    @Test
    fun l1_oddLinks() {
        val odd = listOf(
            // The scheme is dropped whatever its case; so is the host's.
            "HTTPS://Shop.Example/Settings" to "/Settings",
            "OrcaShop://OPEN/settings" to "/settings",
            // Percent-encoding is kept as is, in the path and in the query.
            "https://shop.example/product/4%202?q=a+b%21" to "/product/4%202?q=a+b%21",
            "https://shop.example/a%2Fb" to "/a%2Fb",
            // A bare path, with and without its slash.
            "/settings" to "/settings",
            "/settings/" to "/settings",
            "/settings?tab=2#top" to "/settings?tab=2",
            "settings" to "/settings",
            "home/product/42" to "/home/product/42",
            "/" to "/",
            // Nothing at all, and nothing but a query or a fragment.
            "" to "/",
            "?tab=2" to "/?tab=2",
            "#top" to "/",
            "https://shop.example/#top" to "/",
            // An empty query is no query.
            "https://shop.example/settings?" to "/settings",
            "https://shop.example/settings?#top" to "/settings",
            // A `?` or a `/` inside the query stays; a `#` ends it.
            "https://shop.example/go?next=/a/b?c=1&d=//x#y?z" to "/go?next=/a/b?c=1&d=//x",
            // Port and user info belong to the host.
            "https://user:pw@shop.example:8443/settings" to "/settings",
            "orcashop://open:80" to "/",
            // A scheme without `//`: what follows is the path.
            "orcashop:settings" to "/settings",
            "orcashop:/settings?tab=2" to "/settings?tab=2",
            "orcashop:" to "/",
            // No host between the slashes.
            "orcashop:///settings" to "/settings",
            "file:///settings/" to "/settings",
            // A colon that is no scheme: after a slash, or after a `?`.
            "/order/a:b" to "/order/a:b",
            "order/a:b" to "/order/a:b",
            "?at=10:30" to "/?at=10:30",
            // Every trailing slash goes.
            "https://shop.example/settings//" to "/settings",
            "https://shop.example//" to "/",
            // A delimiter is a delimiter also when a combining scalar
            // follows it: the text is split by code unit, not by grapheme.
            "/s?q=#\uFE0F\u20E31" to "/s?q=",
            "a:\u0301b" to "/\u0301b",
            "x://\u0301h/p" to "/p",
        )
        for ((link, location) in odd) assertEquals(location, DeepLink.location(link), "\"$link\"")
        // A location is its own location.
        for ((_, location) in odd) assertEquals(location, DeepLink.location(location), "again \"$location\"")
    }

    /** Corners the Swift test does not pin. */
    @Test
    fun l1_oddLinksOfKotlinAlone() {
        val odd = listOf(
            // The first part after `//` is a host, also when it looks like a route.
            "app://product/42" to "/42",
            "OrcaShop://open/order/7" to "/order/7",
            "https://shop.example/order/a%20b?q=%C3%A9+x" to "/order/a%20b?q=%C3%A9+x",
            "/settings/?a=1#f" to "/settings?a=1",
            // Only a query, after a host or after an empty one.
            "https://shop.example?tab=2" to "/?tab=2",
            "orcashop://?tab=2" to "/?tab=2",
            "orcashop://" to "/",
            // `//host/path` is a host and a path.
            "//shop.example/settings" to "/settings",
            // A scheme, a `//` or a `?` further on is not one.
            "/settings?next=https://x.example/y" to "/settings?next=https://x.example/y",
            "https://shop.example/a//b/" to "/a//b",
            "https://shop.example/settings?a=1?b=2" to "/settings?a=1?b=2",
        )
        for ((link, location) in odd) assertEquals(location, DeepLink.location(link), "\"$link\"")
        for ((_, location) in odd) assertEquals(location, DeepLink.location(location), "again \"$location\"")
    }

    @Test
    fun l1_eventOfALink() {
        val link = "orcashop://open/order/a%20b/?gift=1&to=a+b#x"
        val location = DeepLink.location(link)
        assertEquals("/order/a%20b?gift=1&to=a+b", location)
        assertEquals(
            DeeplinkEvent(
                incoming = link,
                resolvedLocation = "/order/a%20b?gift=1&to=a+b",
                pathParameters = mapOf("id" to "a b"),
                queryParameters = mapOf("gift" to "1", "to" to "a b"),
                wasRedirected = false,
                isColdStart = true,
            ),
            DeepLink.event(link, table.resolve(location, loggedOut), coldStart = true),
        )
    }

    @Test
    fun l3_eventOfARedirectedLink() {
        val link = "https://shop.example/account?from=mail"
        assertEquals(
            DeeplinkEvent(link, "/login?why=link", emptyMap(), mapOf("why" to "link"), wasRedirected = true, isColdStart = false),
            DeepLink.event(link, table.resolve(DeepLink.location(link), loggedOut), coldStart = false),
        )
        assertEquals(
            DeeplinkEvent(link, "/account?from=mail", emptyMap(), mapOf("from" to "mail"), wasRedirected = false, isColdStart = false),
            DeepLink.event(link, table.resolve(DeepLink.location(link), props("loggedIn" to true)), coldStart = false),
        )
    }

    @Test
    fun l4_eventOfAnUnknownLink() {
        for (link in listOf("https://shop.example/nowhere/?x=1", "orcashop://settings")) {
            val resolution = table.resolve(DeepLink.location(link), loggedOut)
            assertEquals(RouteResolutionKind.Error, resolution.kind, link)
            val event = DeepLink.event(link, resolution, coldStart = false)
            assertEquals(link, event.incoming)
            assertEquals(DeepLink.location(link), event.resolvedLocation)
            assertEquals(emptyMap(), event.pathParameters)
            assertEquals(false, event.wasRedirected, "a dropped slash or an empty path is not a redirect: $link")
        }
    }

    /** D2 and D5: a link is a `go`, but not when it ends on the location on screen, itself or by its redirect. */
    @Test
    fun l3_l4_aLinkIsAGoExceptToTheLocationOnScreen() {
        val none = TabShellChange()
        val shell = TabShell(table)
        shell.go("/home", loggedOut)

        // A go: the page is requested, what was shown is dropped.
        val order = shell.open("/order/7?gift=1", loggedOut)
        assertEquals(table.resolve("/order/7?gift=1", loggedOut), order.resolution)
        assertEquals(listOf("order/7"), order.change.requested.map { it.pagePath })
        assertEquals(listOf("home"), order.change.dropped.map { it.pagePath })
        assertEquals("/order/7?gift=1", shell.location)

        // The location on screen: nothing changes, the resolution is there.
        val before = shell.visible
        val again = shell.open("/order/7?gift=1", loggedOut)
        assertEquals(none, again.change)
        assertEquals(order.resolution, again.resolution)
        assertEquals(before, shell.visible)
        // Another query is another location.
        val other = shell.open("/order/7?gift=2", loggedOut)
        assertEquals(listOf("order/7"), other.change.requested.map { it.pagePath })
        assertEquals("/order/7?gift=2", shell.location)

        // Redirected: the target is shown and requested.
        val account = shell.open("/account?from=mail", loggedOut)
        assertEquals(true, account.resolution.redirected)
        assertEquals(listOf("login"), account.change.requested.map { it.pagePath })
        assertEquals("/login?why=link", shell.location)
        // Redirected onto the location on screen: nothing changes, and the
        // resolution is the link's, redirected.
        val shown = shell.visible
        val accountAgain = shell.open("/account", loggedOut)
        assertEquals(none, accountAgain.change)
        assertEquals(true, accountAgain.resolution.redirected)
        assertEquals("/login?why=link", accountAgain.resolution.location)
        assertEquals(shown, shell.visible)

        // Unknown: the error entry, nothing requested, the location kept.
        val lost = shell.open("/nowhere?x=1", loggedOut)
        assertEquals(RouteResolutionKind.Error, lost.resolution.kind)
        assertEquals(emptyList(), lost.change.requested)
        assertEquals(listOf("login"), lost.change.dropped.map { it.pagePath })
        assertEquals("/nowhere?x=1", shell.location)
        assertEquals(listOf(RouteResolutionKind.Error), shell.visible.map { it.resolution.kind })
        val lostAgain = shell.open("/nowhere?x=1", loggedOut)
        assertEquals(none, lostAgain.change)
        assertEquals(RouteResolutionKind.Error, lostAgain.resolution.kind)

        // A location without its slash is the same location.
        assertEquals(none, shell.open("nowhere?x=1", loggedOut).change)

        // A fresh shell: the link is the boot.
        val cold = TabShell(table)
        val boot = cold.open("/account?from=mail", loggedOut)
        assertEquals(listOf("login"), boot.change.requested.map { it.pagePath })
        assertEquals(emptyList(), boot.change.dropped)
        assertEquals("/login?why=link", cold.location)
    }
}
