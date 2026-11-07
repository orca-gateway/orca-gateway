package com.orcagateway.core.client

import com.orcagateway.core.json.DartFormat

/**
 * What the device tells the server on every request, as the Flutter
 * client's `_computeDeviceHeaders` sends it. The Android module fills it from
 * a `Context` (`DeviceInfo.current(context)`, an extension on [Companion]);
 * the core only formats it, so the headers are testable on the JVM.
 */
public data class DeviceInfo(
    /**
     * `Android`: the engine parses `x-orca-platform` as `iOS` or `Android`
     * (engine/src/core/request-info.ts).
     */
    public val platform: String = "Android",
    /** `x-orca-os-version`, free text the engine keeps as given. */
    public val osVersion: String? = null,
    /** Logical screen size in dp (Flutter's logical pixels). */
    public val screenWidth: Double? = null,
    public val screenHeight: Double? = null,
    /** Pixels per dp. */
    public val pixelDensity: Double? = null,
    /** Safe-area (system bar and cutout) insets in dp. */
    public val safeTop: Double? = null,
    public val safeBottom: Double? = null,
    public val safeLeft: Double? = null,
    public val safeRight: Double? = null,
    /** `<language>_<region>`, e.g. "en_US" (Dart: languageCode_countryCode). */
    public val locale: String? = null,
    /** Time zone abbreviation, e.g. "GMT+2". */
    public val timezone: String? = null,
) {
    /**
     * The `x-orca-*` device headers. Sizes go out as whole dp and the
     * density with one decimal, matching Dart's `toStringAsFixed(0)` and
     * `toStringAsFixed(1)`.
     */
    public val headers: Map<String, String>
        get() {
            val h = linkedMapOf("x-orca-platform" to platform)
            osVersion?.let { h["x-orca-os-version"] = it }
            fun put(name: String, value: Double?, digits: Long) {
                val text = value?.let { DartFormat.fixed(it, digits) } ?: return
                h[name] = text
            }
            put("x-orca-screen-width", screenWidth, 0)
            put("x-orca-screen-height", screenHeight, 0)
            put("x-orca-pixel-density", pixelDensity, 1)
            put("x-orca-safe-top", safeTop, 0)
            put("x-orca-safe-bottom", safeBottom, 0)
            put("x-orca-safe-left", safeLeft, 0)
            put("x-orca-safe-right", safeRight, 0)
            locale?.let { h["x-orca-locale"] = it }
            timezone?.let { h["x-orca-timezone"] = it }
            return h
        }

    /** Where the Android module hangs `current(context)`. */
    public companion object
}
