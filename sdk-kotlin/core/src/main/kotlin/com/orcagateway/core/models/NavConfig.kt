package com.orcagateway.core.models

import com.orcagateway.core.json.JsonValue
import kotlinx.serialization.SerializationException

/**
 * Body of `GET /api/v1/app/:appId/config` (the engine's `getNavConfig`): where
 * the app starts, its tabs and drawer, the app state to seed before the first
 * page request, and the routes of every flow. A port of the Dart `NavConfig`
 * with the same defaults. Keys the client does not read (`appId`, `appName`,
 * a route's `requiredAppState`) are ignored, and stay readable in [raw].
 */
public data class NavConfig(
    public val initialRoute: String = "/",
    public val tabs: List<TabDef> = emptyList(),
    public val drawerItems: List<DrawerItemDef> = emptyList(),
    /** Seeded into app state before the router is built. */
    public val initialAppState: Map<String, JsonValue> = emptyMap(),
    /** The custom tab bar, as a flat component array (empty: the default bar). */
    public val tabBarComponents: List<ComponentNode> = emptyList(),
    /** The custom drawer, as a flat component array (empty: the default drawer). */
    public val drawerComponents: List<ComponentNode> = emptyList(),
    public val flows: List<NavFlow> = emptyList(),
    /** The whole body as decoded, unknown keys included. */
    public val raw: JsonValue = JsonValue.Object(emptyMap()),
    /** The body text of the HTTP response, for the offline cache; null when not decoded from one. */
    public val rawBody: String? = null,
) {
    public companion object {
        /**
         * Decodes a config body (Dart `NavConfig.fromJson`). Throws a
         * [SerializationException] when [json] is not an object, a required
         * key is missing or a value has the wrong type.
         */
        public fun fromJson(json: JsonValue, rawBody: String? = null): NavConfig {
            val f = Fields.of(json, "NavConfig")
            return NavConfig(
                initialRoute = f.stringOrNull("initialRoute") ?: "/",
                tabs = f.listOrNull("tabs", TabDef::fromTree).orEmpty(),
                drawerItems = f.listOrNull("drawerItems", DrawerItemDef::fromTree).orEmpty(),
                initialAppState = f.objOrNull("initialAppState").orEmpty(),
                tabBarComponents = f.listOrNull("tabBarComponents", ComponentNodeSerializer::fromTree).orEmpty(),
                drawerComponents = f.listOrNull("drawerComponents", ComponentNodeSerializer::fromTree).orEmpty(),
                flows = f.listOrNull("flows", NavFlow::fromTree).orEmpty(),
                raw = json,
                rawBody = rawBody,
            )
        }
    }
}

/** A tab of the bottom bar; [initialRoute] has a leading slash. */
public data class TabDef(
    public val id: String,
    public val label: String,
    public val icon: String,
    public val initialRoute: String,
) {
    internal companion object {
        fun fromTree(tree: JsonValue): TabDef {
            val f = Fields.of(tree, "TabDef")
            return TabDef(f.string("id"), f.string("label"), f.string("icon"), f.string("initialRoute"))
        }
    }
}

/** An entry of the drawer; [route] has a leading slash. */
public data class DrawerItemDef(
    public val id: String,
    public val label: String,
    public val icon: String? = null,
    public val route: String,
) {
    internal companion object {
        fun fromTree(tree: JsonValue): DrawerItemDef {
            val f = Fields.of(tree, "DrawerItemDef")
            return DrawerItemDef(f.string("id"), f.string("label"), f.stringOrNull("icon"), f.string("route"))
        }
    }
}

/**
 * A group of routes. A static flow ([isStatic]) comes with its [pages]
 * already rendered, keyed by page path, and a [version] to compare against
 * the server's, for offline use.
 */
public data class NavFlow(
    public val name: String,
    public val version: Int? = null,
    public val isStatic: Boolean = false,
    public val routes: List<NavRoute> = emptyList(),
    public val pages: Map<String, PageResponse>? = null,
) {
    internal companion object {
        fun fromTree(tree: JsonValue): NavFlow {
            val f = Fields.of(tree, "NavFlow")
            return NavFlow(
                name = f.string("name"),
                version = f.longOrNull("version")?.toInt(),
                isStatic = f.boolOrNull("isStatic") ?: false,
                routes = f.listOrNull("routes", NavRoute::fromTree).orEmpty(),
                pages = f.mapOrNull("pages", PageResponseSerializer::fromTree),
            )
        }
    }
}

/**
 * One route. [path] has no leading slash and a child carries its full path
 * (`home/product/:id`); a `:name` segment is a parameter.
 */
public data class NavRoute(
    public val path: String,
    public val children: List<NavRoute> = emptyList(),
    public val redirect: RedirectRule? = null,
    public val transition: RouteTransitionDef? = null,
    public val isDynamic: Boolean = false,
) {
    internal companion object {
        fun fromTree(tree: JsonValue): NavRoute {
            val f = Fields.of(tree, "NavRoute")
            return NavRoute(
                path = f.string("path"),
                children = f.listOrNull("children", ::fromTree).orEmpty(),
                redirect = f.decodeOrNull("redirect", RedirectRule::fromTree),
                transition = f.decodeOrNull("transition", RouteTransitionDef::fromTree),
                isDynamic = f.boolOrNull("isDynamic") ?: false,
            )
        }
    }
}

/**
 * Go to [to] when app state key [when] equals [equals]. An absent `equals`
 * reads as JSON null, as in Dart.
 */
public data class RedirectRule(
    public val `when`: String,
    public val equals: JsonValue,
    public val to: String,
) {
    internal companion object {
        fun fromTree(tree: JsonValue): RedirectRule {
            val f = Fields.of(tree, "RedirectRule")
            return RedirectRule(f.string("when"), f.jsonOrNull("equals") ?: JsonValue.Null, f.string("to"))
        }
    }
}

/** How a route's page comes in: [type], [duration] in milliseconds, [curve]. */
public data class RouteTransitionDef(
    public val type: String,
    public val duration: Int = 300,
    public val curve: String = "easeInOut",
) {
    internal companion object {
        fun fromTree(tree: JsonValue): RouteTransitionDef {
            val f = Fields.of(tree, "RouteTransitionDef")
            return RouteTransitionDef(
                type = f.string("type"),
                duration = f.longOrNull("duration")?.toInt() ?: 300,
                curve = f.stringOrNull("curve") ?: "easeInOut",
            )
        }
    }
}
