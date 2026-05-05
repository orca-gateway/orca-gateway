import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';

/// iOS-style toggle switch. Ported from `Toggle` in the prototype.
class OrcaToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const OrcaToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 36,
        height: 20,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: value ? theme.semantic.success : theme.surface.content,
          border: Border.all(color: theme.border.hairline, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              left: value ? 16 : 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
