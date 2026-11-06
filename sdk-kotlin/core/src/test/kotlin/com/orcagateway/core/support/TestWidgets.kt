package com.orcagateway.core.support

import com.orcagateway.core.render.WidgetRegistry

/**
 * The widget set the Swift tests draw with by default. Swift's
 * `WidgetRegistry.shared` holds the iOS build's generated widgets; Kotlin's
 * `GeneratedCapabilities.widgets` stays empty until the Android renderer
 * (S7) lands, so render tests pass every widget of schema/widget-registry.json
 * (all of which carry the android target) explicitly instead.
 */
object TestWidgets {
    val manifestTypes: Set<String> by lazy {
        val widgets = Fixtures.json("schema/widget-registry.json")["widgets"].arrayValue.orEmpty()
        widgets.mapNotNull { it["type"].stringValue }.toSet()
    }

    /** A fresh registry (so reported types do not leak between tests). */
    fun registry(onUnknownType: ((String) -> Unit)? = null): WidgetRegistry =
        WidgetRegistry(types = manifestTypes, onUnknownType = onUnknownType)
}
