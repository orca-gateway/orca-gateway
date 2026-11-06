package com.orcagateway.sdk.client

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Build
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.orcagateway.core.client.DeviceInfo
import java.util.Locale
import java.util.TimeZone

/**
 * This device, for the `x-orca-*` headers: screen size and density in dp,
 * the safe-area insets (system bars and display cutout) in dp, the Android
 * version, locale and time zone. The Android side of Swift's
 * `DeviceInfo.current()`.
 *
 * The insets need an attached window, so pass the activity (or a context
 * wrapping it) after it is shown; from another context they are left out,
 * and the server sees no `x-orca-safe-*` headers.
 */
public fun DeviceInfo.Companion.current(context: Context): DeviceInfo {
    val metrics = context.resources.displayMetrics
    val density = metrics.density.toDouble()
    val locale = Locale.getDefault()
    val zone = TimeZone.getDefault()
    var info = DeviceInfo(
        osVersion = "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
        screenWidth = metrics.widthPixels / density,
        screenHeight = metrics.heightPixels / density,
        pixelDensity = density,
        locale = "${locale.language.ifEmpty { "en" }}_${locale.country}",
        timezone = zone.getDisplayName(zone.inDaylightTime(java.util.Date()), TimeZone.SHORT),
    )
    val view = context.activity()?.window?.decorView ?: return info
    val insets = ViewCompat.getRootWindowInsets(view)
        ?.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
        ?: return info
    info = info.copy(
        safeTop = insets.top / density,
        safeBottom = insets.bottom / density,
        safeLeft = insets.left / density,
        safeRight = insets.right / density,
    )
    return info
}

private tailrec fun Context.activity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.activity()
    else -> null
}
