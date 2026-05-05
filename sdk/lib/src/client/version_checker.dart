import '../models/page_response.dart' show VersionResponse;
import 'orca_client.dart';
import 'static_flow_manager.dart';

/// Result of a version check against the server.
enum VersionCheckResult {
  /// All flow versions match local cache.
  fresh,
  /// Some flows have newer versions on the server.
  stale,
  /// Server demands an app update.
  forceUpdate,
  /// Network unavailable — use cached data.
  offline,
}

/// Outcome of a version check, including which flows are stale.
class VersionCheckOutcome {
  final VersionCheckResult result;
  final List<String> staleFlows;

  const VersionCheckOutcome({
    required this.result,
    this.staleFlows = const [],
  });
}

/// Checks flow versions against locally stored versions.
class VersionChecker {
  final OrcaClient client;
  final String appId;
  final StaticFlowManager flowManager;

  VersionChecker({
    required this.client,
    required this.appId,
    required this.flowManager,
  });

  /// Check remote versions against local cache.
  /// Fetches remote versions and reads local versions in parallel.
  Future<VersionCheckOutcome> check() async {
    try {
      // Parallel: network + disk read
      final results = await Future.wait([
        client.fetchVersion(appId),
        flowManager.getLocalVersions(),
      ]);
      final remote = results[0] as VersionResponse;
      final local = results[1] as Map<String, int>;

      if (remote.forceUpdate) {
        return const VersionCheckOutcome(
          result: VersionCheckResult.forceUpdate,
        );
      }

      final stale = <String>[];
      for (final entry in remote.flows.entries) {
        if (local[entry.key] != entry.value) {
          stale.add(entry.key);
        }
      }

      if (stale.isEmpty) {
        return const VersionCheckOutcome(result: VersionCheckResult.fresh);
      }

      return VersionCheckOutcome(
        result: VersionCheckResult.stale,
        staleFlows: stale,
      );
    } catch (_) {
      return const VersionCheckOutcome(result: VersionCheckResult.offline);
    }
  }
}
