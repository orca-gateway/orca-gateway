import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';

enum OrcaChipSize { sm, md }

/// Small pill used across the UI for tones (success / warning / danger / info /
/// stage / scopeApp / scopePage / accent). Ported from `Chip` in the
/// prototype's `tokens.jsx`.
class OrcaChip extends StatelessWidget {
  final String tone;
  final String label;
  final bool mono;
  final bool strong;
  final OrcaChipSize size;

  const OrcaChip({
    super.key,
    required this.label,
    this.tone = 'info',
    this.mono = true,
    this.strong = false,
    this.size = OrcaChipSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final color = theme.toneColor(tone);
    final isDark = theme.isDark;
    final fontSize = size == OrcaChipSize.sm
        ? fs(10, theme.fontScale)
        : fs(10.5, theme.fontScale);
    final verticalPad = size == OrcaChipSize.sm ? 1.0 : theme.density.chipY;
    final horizontalPad = size == OrcaChipSize.sm ? 5.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      decoration: BoxDecoration(
        color: strong
            ? color
            : color.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: mono ? kSfMono : kSfPro,
          fontFamilyFallback: mono ? kSfMonoFallback : kSfProFallback,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: strong ? theme.text.onAccent : color,
          letterSpacing: 0.2,
          height: 1.2,
        ),
      ),
    );
  }
}
