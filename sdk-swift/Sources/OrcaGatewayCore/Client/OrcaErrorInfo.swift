import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// What the error screen shows for an error: Flutter's `buildOrcaError`
/// (sdk/lib/src/widgets/orca_error.dart) as a value, its titles and messages
/// verbatim. The UI layer and a host's error view draw it; `kind` picks the
/// icon.
///
/// - `OrcaClientError.http` and `.action` (Dart `OrcaClientException`) map by
///   status: 401, 403, 404, 429 and >= 500 to their screens; any other status
///   is "Error" with the error's own message. An `.http` reads "Failed to
///   fetch page: <status>" for a page, and for /config and /version too, where
///   Flutter says "Failed to fetch config: N" and "Failed to fetch version: N":
///   a native difference, the error carries no route. An `.action` keeps the
///   server's `error`, or "Server action failed".
/// - A `DecodingError` (Dart `FormatException` from `jsonDecode` or a model)
///   and `OrcaClientError.invalidURL` (Dart `Uri.parse` throws a
///   `FormatException`) are "Configuration Error".
/// - A `URLError` that never reached the server (Dart `SocketException`,
///   "Connection refused") is "Connection Failed". A timeout counts too, a
///   native difference: Flutter's `TimeoutException` falls to the default.
/// - Anything else is "Something Went Wrong".
public struct OrcaErrorInfo: Equatable, Sendable {
    /// Flutter's branches, each with its own icon there: unauthorized
    /// `lock_outline`, forbidden `block`, notFound `search_off`,
    /// tooManyRequests `speed`, server `cloud_off`, status `error_outline`,
    /// configuration `settings`, connection `wifi_off`, unknown
    /// `error_outline`.
    public enum Kind: String, Equatable, Sendable {
        case unauthorized, forbidden, notFound, tooManyRequests, server, status
        case configuration, connection, unknown
    }

    public let kind: Kind
    public let title: String
    public let message: String

    init(kind: Kind, title: String, message: String) {
        self.kind = kind
        self.title = title
        self.message = message
    }

    public init(_ error: Error) {
        switch error {
        case OrcaClientError.http(let status, _):
            self = Self.status(status, otherwise: "Failed to fetch page: \(status)")
        case OrcaClientError.action(let status, let message):
            self = Self.status(status, otherwise: message)
        case OrcaClientError.invalidURL, is DecodingError:
            self.init(kind: .configuration, title: "Configuration Error",
                      message: "Invalid value in configuration. Please check your setup.")
        case let error as URLError where Self.unreached.contains(error.code):
            self.init(kind: .connection, title: "Connection Failed",
                      message: "Unable to reach the server. Please check your network and server status.")
        default:
            self.init(kind: .unknown, title: "Something Went Wrong",
                      message: "An unexpected error occurred. Please try again.")
        }
    }

    /// The `URLError` codes of a request that never reached the server: no
    /// network, no host, no connection, or no answer in time.
    static let unreached: [URLError.Code] = [
        .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost,
        .dnsLookupFailed, .timedOut, .internationalRoamingOff, .dataNotAllowed, .callIsActive,
    ]

    /// The `OrcaClientException` switch of `buildOrcaError`.
    static func status(_ status: Int, otherwise message: String) -> OrcaErrorInfo {
        switch status {
        case 401:
            return OrcaErrorInfo(kind: .unauthorized, title: "Unauthorized",
                                 message: "Invalid or missing API key. Please check your configuration.")
        case 403:
            return OrcaErrorInfo(kind: .forbidden, title: "Forbidden",
                                 message: "You do not have permission to access this resource.")
        case 404:
            return OrcaErrorInfo(kind: .notFound, title: "Not Found",
                                 message: "The requested page could not be found.")
        case 429:
            return OrcaErrorInfo(kind: .tooManyRequests, title: "Too Many Requests",
                                 message: "Please slow down and try again in a moment.")
        case 500...:
            return OrcaErrorInfo(kind: .server, title: "Server Error",
                                 message: "Something went wrong on the server. Please try again later.")
        default:
            return OrcaErrorInfo(kind: .status, title: "Error", message: message)
        }
    }
}
