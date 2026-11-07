package com.orcagateway.sdk

import com.orcagateway.core.capabilities.GeneratedCapabilities
import com.orcagateway.core.render.WidgetRegistry
import org.junit.Test
import kotlin.test.assertEquals

/**
 * S9.13: the Compose registry draws exactly what the caps vector advertises,
 * so the server never degrades a widget Android draws and never sends one it
 * would draw as nothing. Plain JUnit, no Android.
 */
class WidgetBuildersTest {
    @Test
    fun c2_standardHasABuilderForExactlyTheAdvertisedWidgets() {
        val advertised = GeneratedCapabilities.widgets.toSet()
        val built = WidgetBuilders.standard().types
        assertEquals(emptySet(), advertised - built, "advertised without a builder")
        assertEquals(emptySet(), built - advertised, "a builder for a type not advertised")
        // The core lets the same set through, so none of them degrades.
        assertEquals(built, WidgetRegistry.shared.types)
        assertEquals(built, WidgetBuilders.shared.types)
    }
}
