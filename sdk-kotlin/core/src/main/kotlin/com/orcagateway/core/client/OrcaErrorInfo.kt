package com.orcagateway.core.client

import kotlinx.serialization.SerializationException
import java.io.InterruptedIOException
import java.net.SocketException
import java.net.UnknownHostException

/**
 * What an error screen shows for an error: the title and message of Flutter's
 * `buildOrcaError` (sdk/lib/src/widgets/orca_error.dart), verbatim, and a
 * [kind] that stands for its icon. Built by [from]; the page view and a
 * host's error view read it.
 */
public data class OrcaErrorInfo(
    public val kind: Kind,
    public val title: String,
    public val message: String,
) {
    /** Flutter's branches, each with the icon Flutter shows for it. */
    public enum class Kind {
        /** A 401 (`Icons.lock_outline`). */
        Unauthorized,

        /** A 403 (`Icons.block`). */
        Forbidden,

        /** A 404 (`Icons.search_off`). */
        NotFound,

        /** A 429 (`Icons.speed`). */
        TooManyRequests,

        /** A status of 500 or more (`Icons.cloud_off`). */
        Server,

        /** Any other status, with the error's own message (`Icons.error_outline`). */
        Status,

        /** A server answer that does not decode, or a URL that cannot be built (`Icons.settings`). */
        Configuration,

        /** The server was not reached (`Icons.wifi_off`). */
        Connection,

        /** Anything else (`Icons.error_outline`). */
        Unknown,
    }

    public companion object {
        /**
         * Flutter's mapping, branch by branch:
         * - [OrcaClientException.Http] and [OrcaActionException] (Dart
         *   `OrcaClientException`) map their status; any other status keeps
         *   the error's message. A failed `/config` or `/version` reads
         *   "Failed to fetch page: N" here, where Flutter says "Failed to
         *   fetch config: N" or "Failed to fetch version: N": a native
         *   difference. A server action keeps its body's `error`, or "Server
         *   action failed", as in Flutter.
         * - A [SerializationException] (Dart `FormatException`) and
         *   [OrcaClientException.InvalidUrl] (Dart's `Uri.parse` throws a
         *   `FormatException`) are a configuration error. Only those: a plain
         *   [IllegalArgumentException], such as a plugin conflict, is unknown.
         * - The transport's errors for a server never reached (Flutter looks
         *   for `SocketException` or "Connection refused" in the text): any
         *   [SocketException] (refused, no route, unreachable network),
         *   [UnknownHostException], and [InterruptedIOException], which
         *   covers [java.net.SocketTimeoutException] and OkHttp's call
         *   timeout. A timeout is a connection failure on the natives, where
         *   Flutter's `TimeoutException` falls to the default. A plain
         *   [java.io.IOException] (a connection dropped mid-answer, a TLS
         *   failure) is unknown, as Flutter's `HttpException` and
         *   `HandshakeException` are.
         */
        public fun from(error: Throwable): OrcaErrorInfo = when (error) {
            is OrcaClientException.Http -> status(error.status, error.message.orEmpty())
            is OrcaActionException -> status(error.status, error.message)
            is OrcaClientException.InvalidUrl, is SerializationException -> OrcaErrorInfo(
                Kind.Configuration, "Configuration Error", "Invalid value in configuration. Please check your setup.",
            )
            is SocketException, is UnknownHostException, is InterruptedIOException -> OrcaErrorInfo(
                Kind.Connection, "Connection Failed",
                "Unable to reach the server. Please check your network and server status.",
            )
            else -> OrcaErrorInfo(
                Kind.Unknown, "Something Went Wrong", "An unexpected error occurred. Please try again.",
            )
        }

        private fun status(status: Int, message: String): OrcaErrorInfo = when {
            status == 401 -> OrcaErrorInfo(
                Kind.Unauthorized, "Unauthorized", "Invalid or missing API key. Please check your configuration.",
            )
            status == 403 -> OrcaErrorInfo(
                Kind.Forbidden, "Forbidden", "You do not have permission to access this resource.",
            )
            status == 404 -> OrcaErrorInfo(Kind.NotFound, "Not Found", "The requested page could not be found.")
            status == 429 -> OrcaErrorInfo(
                Kind.TooManyRequests, "Too Many Requests", "Please slow down and try again in a moment.",
            )
            status >= 500 -> OrcaErrorInfo(
                Kind.Server, "Server Error", "Something went wrong on the server. Please try again later.",
            )
            else -> OrcaErrorInfo(Kind.Status, "Error", message)
        }
    }
}
