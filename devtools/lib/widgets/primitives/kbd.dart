import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';

/// Keyboard-cap chip for shortcuts (⌘K, esc, ↑↓ etc.).
/// Ported from `Kbd` in the prototype.
class Kbd extends StatelessWidget {
  final String label;
  const Kbd(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.surface.raised,
        border: Border.all(color: theme.border.hairline, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kSfPro,
          fontFamilyFallback: kSfProFallback,
          fontSize: fs(10.5, theme.fontScale),
          color: theme.text.secondary,
          height: 1.2,
        ),
      ),
    );
  }
}
