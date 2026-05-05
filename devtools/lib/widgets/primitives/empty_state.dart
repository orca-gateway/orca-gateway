import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';
import 'orca_icon.dart';

/// Centered icon + title + body. Used by every inspector when its data list
/// is empty.
class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String body;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.5,
              child: OrcaIcon(icon, size: 48, color: theme.text.tertiary),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: kSfPro,
                fontFamilyFallback: kSfProFallback,
                fontSize: fs(14, theme.fontScale),
                fontWeight: FontWeight.w500,
                color: theme.text.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kSfPro,
                fontFamilyFallback: kSfProFallback,
                fontSize: fs(12, theme.fontScale),
                color: theme.text.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
