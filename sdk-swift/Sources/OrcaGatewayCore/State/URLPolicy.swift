import Foundation

/// Which URLs an `openUrl` action (or a tapped link) may open: http, https
/// and mailto, plus any schemes the host opts into (Flutter `OrcaUrlPolicy`,
/// sdk/lib/src/state/url_scheme_policy.dart, where tel and sms are opt-in).
/// Anything else is dropped without a word, after the effect was reported.
public struct OrcaURLPolicy: Sendable, Equatable {
    public static let defaultSchemes: Set<String> = ["http", "https", "mailto"]

    public var allowedSchemes: Set<String>

    public init(extraSchemes: Set<String> = []) {
        allowedSchemes = Self.defaultSchemes.union(extraSchemes.map { $0.lowercased() })
    }

    public static let standard = OrcaURLPolicy()

    public func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return allowedSchemes.contains(scheme)
    }

    /// The URL in `text`, when it parses and is allowed.
    public func url(_ text: String) -> URL? {
        guard let url = URL(string: text), isAllowed(url) else { return nil }
        return url
    }
}
