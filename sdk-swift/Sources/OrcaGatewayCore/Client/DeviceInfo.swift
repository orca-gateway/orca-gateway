import Foundation

/// What the device tells the server on every request, as the Flutter
/// client's `_computeDeviceHeaders` sends it. The UI layer fills it from
/// UIKit; the core only formats it, so the headers are testable on Linux.
public struct DeviceInfo: Equatable, Sendable {
    /// `iOS`: the engine parses `x-orca-platform` as `iOS` or `Android`
    /// (engine/src/core/request-info.ts).
    public var platform: String
    /// `x-orca-os-version`, e.g. "Version 18.5 (Build 22F77)".
    public var osVersion: String?
    /// Logical screen size in points.
    public var screenWidth: Double?
    public var screenHeight: Double?
    /// Pixels per point.
    public var pixelDensity: Double?
    /// Safe-area insets in points.
    public var safeTop: Double?
    public var safeBottom: Double?
    public var safeLeft: Double?
    public var safeRight: Double?
    /// `<language>_<region>`, e.g. "en_US" (Dart: languageCode_countryCode).
    public var locale: String?
    /// Time zone abbreviation, e.g. "GMT+2".
    public var timezone: String?

    public init(
        platform: String = "iOS", osVersion: String? = nil,
        screenWidth: Double? = nil, screenHeight: Double? = nil, pixelDensity: Double? = nil,
        safeTop: Double? = nil, safeBottom: Double? = nil,
        safeLeft: Double? = nil, safeRight: Double? = nil,
        locale: String? = nil, timezone: String? = nil
    ) {
        self.platform = platform
        self.osVersion = osVersion
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.pixelDensity = pixelDensity
        self.safeTop = safeTop
        self.safeBottom = safeBottom
        self.safeLeft = safeLeft
        self.safeRight = safeRight
        self.locale = locale
        self.timezone = timezone
    }

    /// The `x-orca-*` device headers. Sizes go out as whole points and the
    /// density with one decimal, matching Dart's `toStringAsFixed(0)` and
    /// `toStringAsFixed(1)`.
    public var headers: [String: String] {
        var h: [String: String] = ["x-orca-platform": platform]
        h["x-orca-os-version"] = osVersion
        func put(_ name: String, _ value: Double?, _ digits: Int) {
            guard let value, let text = DartFormat.fixed(value, digits) else { return }
            h[name] = text
        }
        put("x-orca-screen-width", screenWidth, 0)
        put("x-orca-screen-height", screenHeight, 0)
        put("x-orca-pixel-density", pixelDensity, 1)
        put("x-orca-safe-top", safeTop, 0)
        put("x-orca-safe-bottom", safeBottom, 0)
        put("x-orca-safe-left", safeLeft, 0)
        put("x-orca-safe-right", safeRight, 0)
        h["x-orca-locale"] = locale
        h["x-orca-timezone"] = timezone
        return h
    }
}
