import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import 'tokens.dart';

/// Exposes the built [OrcaTheme] to the widget tree via `OrcaThemeScope.of(context)`.
/// Rebuilds whenever [AppSettings] notifies (theme mode / accent / density /
/// font scale / translucency changes all route through AppSettings).
class OrcaThemeScope extends InheritedNotifier<AppSettings> {
  final OrcaTheme theme;

  const OrcaThemeScope({
    super.key,
    required this.theme,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static OrcaTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OrcaThemeScope>();
    assert(scope != null, 'No OrcaThemeScope found in context');
    return scope!.theme;
  }

  @override
  bool updateShouldNotify(OrcaThemeScope oldWidget) =>
      theme != oldWidget.theme || notifier != oldWidget.notifier;
}

/// Convenience builder — wraps a subtree in an [AnimatedBuilder] listening to
/// [AppSettings], rebuilds an [OrcaTheme] on each change, and provides it via
/// [OrcaThemeScope]. Use at the top of the app.
class OrcaThemeBuilder extends StatelessWidget {
  final AppSettings settings;
  final Widget Function(BuildContext context, OrcaTheme theme) builder;

  const OrcaThemeBuilder({
    super.key,
    required this.settings,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final theme = OrcaTheme.build(
          mode: settings.themeMode,
          accent: settings.accent,
          density: settings.density,
          fontScale: settings.fontScale,
          translucent: settings.translucent,
        );
        return OrcaThemeScope(
          theme: theme,
          settings: settings,
          child: Builder(builder: (context) => builder(context, theme)),
        );
      },
    );
  }
}
