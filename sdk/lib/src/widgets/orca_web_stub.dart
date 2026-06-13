import 'package:flutter/material.dart';

/// A branded placeholder a plugin can register as a web stub (Epic 38 task
/// 38.5) for a widget that has no real Flutter Web implementation — a native
/// platform view such as a camera preview, a map, a video surface, or an audio
/// recorder.
///
/// Register it via the plugin's `webStubs` map so the renderer substitutes it
/// on web (`kIsWeb`) when the widget's metadata marks it `isSupportedOnWeb:
/// false`:
///
/// ```dart
/// webStubs: {
///   'GoogleMap': (ctx) => const OrcaWebStub(
///     label: 'Google Maps',
///     icon: Icons.map_outlined,
///   ),
/// },
/// ```
///
/// Unlike the generic `UnsupportedWidgetPlaceholder`, this stub fills the slot
/// the real widget would occupy (so layout stays stable in the preview) and
/// reads as a recognizable, intentionally-disabled surface rather than an
/// error. It is deliberately self-contained — no plugin needs to reimplement
/// the card styling, and the look stays consistent across every Phase 1 plugin.
class OrcaWebStub extends StatelessWidget {
  const OrcaWebStub({
    super.key,
    required this.label,
    required this.icon,
    this.note = 'Preview unavailable on web — runs in the mobile app.',
    this.minHeight = 160,
  });

  /// The human-readable name of the feature, e.g. "Google Maps".
  final String label;

  /// A representative icon for the feature.
  final IconData icon;

  /// One-line explanation shown under the label.
  final String note;

  /// Minimum height so the stub visibly occupies the platform view's slot
  /// instead of collapsing to its intrinsic size.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6B7280);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // A subtle hatched-feeling neutral fill so it reads as an inert
          // surface, distinct from real, interactive content.
          color: accent.withValues(alpha: 0.06),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: accent),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              note,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
