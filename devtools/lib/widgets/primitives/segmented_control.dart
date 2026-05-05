import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';

class OrcaSegmentedControl<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  const OrcaSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.surface.content,
        border: Border.all(color: theme.border.hairline, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final (v, label) = opt;
          final selected = v == value;
          return InkWell(
            onTap: () => onChanged(v),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? theme.accent.base : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: kSfPro,
                  fontFamilyFallback: kSfProFallback,
                  fontSize: fs(11.5, theme.fontScale),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? theme.text.onAccent : theme.text.secondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
