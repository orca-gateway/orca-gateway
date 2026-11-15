package com.orcagateway.core.navigation

/** How a route change came about (Dart `OrcaRouteChangeType`). */
public enum class RouteChangeType { Push, Replace, Pop }

/**
 * One change of the shown location, reported after the redirect has
 * resolved (Dart `OrcaRouteChangeEvent`). [previousLocation] is null for the
 * first location of the app.
 */
public data class RouteChangeEvent(
    /** The location after the change. */
    val location: String,
    /** The location just before it, when there was one. */
    val previousLocation: String? = null,
    val type: RouteChangeType,
)
