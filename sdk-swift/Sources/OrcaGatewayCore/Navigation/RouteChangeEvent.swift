import Foundation

/// How a route change was initiated. A port of Dart `OrcaRouteChangeType`
/// (sdk/lib/src/navigation/deeplink_event.dart).
public enum RouteChangeType: String, Sendable {
    case push, replace, pop
}

/// One change of location, reported after the redirect resolved. A port of
/// Dart `OrcaRouteChangeEvent`: the first event of an app has no
/// `previousLocation` and type `push`.
public struct RouteChangeEvent: Equatable, Sendable {
    /// The new location, after the navigation completed.
    public var location: String
    /// The location just before the change; nil at boot.
    public var previousLocation: String?
    public var type: RouteChangeType

    public init(location: String, previousLocation: String? = nil, type: RouteChangeType) {
        self.location = location
        self.previousLocation = previousLocation
        self.type = type
    }
}
