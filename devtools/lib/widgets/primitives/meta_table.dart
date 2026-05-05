import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';

/// Bordered zebra-striped key/value block. Ported from `MetaTable` in
/// `screens/timeline-state.jsx`.
class MetaTable extends StatelessWidget {
  final List<(String, String)> rows;
  final double keyColumnWidth;

  const MetaTable({
    super.key,
    required this.rows,
    this.keyColumnWidth = 170,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.border.hairline, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: i.isOdd ? theme.surface.zebra : Colors.transparent,
                  border: i == rows.length - 1
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: theme.border.divider,
                            width: 1,
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: keyColumnWidth,
                      child: Text(
                        rows[i].$1,
                        style: TextStyle(
                          fontFamily: kSfMono,
                          fontFamilyFallback: kSfMonoFallback,
                          fontSize: fs(11.5, theme.fontScale),
                          color: theme.text.secondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].$2,
                        style: TextStyle(
                          fontFamily: kSfMono,
                          fontFamilyFallback: kSfMonoFallback,
                          fontSize: fs(11.5, theme.fontScale),
                          fontWeight: FontWeight.w500,
                          color: theme.text.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
