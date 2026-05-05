/// How a route change was initiated.
enum OrcaRouteChangeType { push, replace, pop }

/// Fired by [OrcaApp.onRouteChanged] on every GoRouter-level navigation,
/// including in-app `navigate` actions, pops, and replacements.
///
/// For deeplinks specifically (external entry points), prefer
/// [OrcaApp.onDeeplink] — it fires in addition to this callback and
/// carries extra context about the incoming URI.
class OrcaRouteChangeEvent {
  /// The new location after the navigation completes.
  final String location;

  /// The location immediately before the change, if known.
  final String? previousLocation;

  /// Kind of navigation that occurred.
  final OrcaRouteChangeType type;

  const OrcaRouteChangeEvent({
    required this.location,
    required this.type,
    this.previousLocation,
  });

  @override
  String toString() =>
      'OrcaRouteChangeEvent($type, $previousLocation -> $location)';
}

/// Fired by [OrcaApp.onDeeplink] after the SDK has fully resolved an
/// externally-initiated deeplink — i.e. after any server-defined
/// [RedirectRule] or auth gate has run.
///
/// The developer receives the FINAL route, not the raw incoming URI,
/// so they never have to reimplement SDK-owned redirect logic.
class OrcaDeeplinkEvent {
  /// The raw platform URI that entered the app.
  final Uri incoming;

  /// The final GoRouter location after SDK redirects.
  final String resolvedLocation;

  /// Path parameters extracted from the final matched route.
  final Map<String, String> pathParameters;

  /// Query parameters extracted from the final matched route.
  final Map<String, String> queryParameters;

  /// True if the SDK's redirect rules rewrote the path between
  /// [incoming] and [resolvedLocation].
  final bool wasRedirected;

  /// True if this deeplink caused the app to launch from cold start
  /// (as opposed to resuming an already-running instance).
  final bool isColdStart;

  const OrcaDeeplinkEvent({
    required this.incoming,
    required this.resolvedLocation,
    required this.pathParameters,
    required this.queryParameters,
    required this.wasRedirected,
    required this.isColdStart,
  });

  @override
  String toString() =>
      'OrcaDeeplinkEvent(cold=$isColdStart, redirected=$wasRedirected, '
      '${incoming.toString()} -> $resolvedLocation)';
}
