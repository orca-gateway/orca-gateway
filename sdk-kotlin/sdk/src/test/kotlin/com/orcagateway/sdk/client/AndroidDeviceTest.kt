package com.orcagateway.sdk.client

import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.client.DeviceInfo
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Locale
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class AndroidDeviceTest {
    @Test
    fun theScreenGoesOutInDpWithTheDensity() {
        Locale.setDefault(Locale.US)
        val info = DeviceInfo.current(ApplicationProvider.getApplicationContext())
        assertEquals("Android", info.platform)
        assertTrue(info.osVersion!!.endsWith("(API 34)"), info.osVersion)
        assertEquals(393.0, info.screenWidth)
        assertEquals(852.0, info.screenHeight)
        assertEquals(2.0, info.pixelDensity)
        assertEquals("en_US", info.locale)
        assertEquals("393", info.headers["x-orca-screen-width"])
        assertEquals("2.0", info.headers["x-orca-pixel-density"])
        // Not an activity: no window, so no safe-area insets are claimed.
        assertNull(info.safeTop)
        assertNull(info.headers["x-orca-safe-top"])
    }
}
