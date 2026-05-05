import 'package:flutter/material.dart';

/// Named-icon wrapper for the DevTools UI. Maps the symbolic names used by
/// the design prototype (`timeline`, `state`, `iphone`, `chevron-right` …) to
/// the closest Material icon. A later polish pass replaces selected icons
/// with pixel-accurate `CustomPainter` ports from the prototype's SVG paths.
class OrcaIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const OrcaIcon(this.name, {super.key, this.size = 14, this.color});

  static const Map<String, IconData> _map = {
    'timeline': Icons.bar_chart_rounded,
    'state': Icons.account_tree_outlined,
    'actions': Icons.bolt_rounded,
    'network': Icons.language_rounded,
    'errors': Icons.error_outline_rounded,
    'settings': Icons.settings_outlined,
    'iphone': Icons.phone_iphone_rounded,
    'android': Icons.phone_android_rounded,
    'search': Icons.search_rounded,
    'export': Icons.ios_share_rounded,
    'pause': Icons.pause_circle_outline_rounded,
    'play': Icons.play_circle_outline_rounded,
    'chevron-right': Icons.chevron_right_rounded,
    'chevron-down': Icons.expand_more_rounded,
    'chevron-up': Icons.expand_less_rounded,
    'copy': Icons.content_copy_rounded,
    'check': Icons.check_rounded,
    'close': Icons.close_rounded,
    'filter': Icons.filter_list_rounded,
    'dot': Icons.circle,
    'sidebar': Icons.view_sidebar_outlined,
    'inspector': Icons.dashboard_outlined,
    'command': Icons.keyboard_command_key,
    'refresh': Icons.refresh_rounded,
    'terminal': Icons.terminal_rounded,
    'clear': Icons.delete_outline_rounded,
    'open-external': Icons.open_in_new_rounded,
    'brace': Icons.data_object_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Icon(
      _map[name] ?? Icons.circle,
      size: size,
      color: color,
    );
  }
}
