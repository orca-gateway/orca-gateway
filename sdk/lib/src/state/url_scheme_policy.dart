/// Central allowlist of URL schemes the SDK will hand to `url_launcher` —
/// used by the `openUrl` action and by built-in widgets that render
/// server-supplied links.
///
/// `tel` and `sms` are excluded by default: link targets come from the
/// server, and a compromised or misconfigured server could otherwise
/// pre-fill premium-rate numbers in the user's dialer. Apps that
/// legitimately use dialer/SMS links can opt in at startup:
///
/// ```dart
/// OrcaUrlPolicy.allowedSchemes.addAll({'tel', 'sms'});
/// ```
class OrcaUrlPolicy {
  OrcaUrlPolicy._();

  /// Schemes `openUrl` and link widgets may launch. Compared lowercase.
  /// Mutable so apps can extend (or restrict) it at startup.
  static final Set<String> allowedSchemes = {'http', 'https', 'mailto'};

  static bool isAllowed(Uri uri) =>
      allowedSchemes.contains(uri.scheme.toLowerCase());
}
