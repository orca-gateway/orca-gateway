import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../server/connection_manager.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';

const String kDevToolsVersion = '0.9.2';

class OrcaStatusBar extends StatelessWidget {
  final ConnectionManager connectionManager;
  final AppSettings settings;

  const OrcaStatusBar({
    super.key,
    required this.connectionManager,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final paused = connectionManager.streamPaused;
    final buffered = connectionManager.bufferedCount;
    final deviceCount = connectionManager.deviceIds.length;
    final eventCount = connectionManager.totalEventCount;

    final baseStyle = TextStyle(
      fontFamily: kSfMono,
      fontFamilyFallback: kSfMonoFallback,
      fontSize: fs(10.5, theme.fontScale),
      color: theme.text.secondary,
    );

    // Pack the primary info line into a single text so it can ellipsis
    // gracefully on narrow windows.
    final primary =
        'ws://localhost:${settings.port} · listening   ·   $deviceCount '
        '${deviceCount == 1 ? 'device' : 'devices'}   ·   ${_fmtNum(eventCount)} events';

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.isDark ? const Color(0xFF202024) : const Color(0xFFF6F6F8),
        border: Border(top: BorderSide(color: theme.border.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.semantic.success,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              primary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseStyle,
            ),
          ),
          if (paused) ...[
            const SizedBox(width: 10),
            Text(
              '● PAUSED · $buffered buffered',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseStyle.copyWith(color: theme.semantic.warning),
            ),
          ],
          const SizedBox(width: 10),
          Text(
            'v$kDevToolsVersion',
            style: baseStyle.copyWith(color: theme.text.tertiary),
          ),
        ],
      ),
    );
  }

  static String _fmtNum(int n) {
    if (n < 1000) return '$n';
    return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}k';
  }
}
