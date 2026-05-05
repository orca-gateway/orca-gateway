import 'package:flutter/widgets.dart';
import '../models/page_response.dart';

/// InheritedWidget that provides [NavConfig] to the widget tree.
/// Used by [ActionExecutor] to resolve tab routes for switchTab actions.
class OrcaNavConfig extends InheritedWidget {
  final NavConfig config;

  const OrcaNavConfig({
    super.key,
    required this.config,
    required super.child,
  });

  static OrcaNavConfig? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OrcaNavConfig>();
  }

  static NavConfig? configOf(BuildContext context) {
    return maybeOf(context)?.config;
  }

  @override
  bool updateShouldNotify(OrcaNavConfig oldWidget) {
    return config != oldWidget.config;
  }
}
