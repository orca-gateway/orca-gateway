import 'package:flutter/widgets.dart';

/// Wraps a child widget to fire lifecycle-based actions
/// (onInit, onVisible, onBackground, onForeground).
class OrcaLifecycleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onInit;
  final VoidCallback? onVisible;
  final VoidCallback? onBackground;
  final VoidCallback? onForeground;

  const OrcaLifecycleWrapper({
    super.key,
    required this.child,
    this.onInit,
    this.onVisible,
    this.onBackground,
    this.onForeground,
  });

  @override
  State<OrcaLifecycleWrapper> createState() => _OrcaLifecycleWrapperState();
}

class _OrcaLifecycleWrapperState extends State<OrcaLifecycleWrapper>
    with WidgetsBindingObserver {
  bool _initFired = false;
  bool _visibleFired = false;
  bool _observingLifecycle = false;

  @override
  void initState() {
    super.initState();
    if (widget.onInit != null && !_initFired) {
      _initFired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onInit?.call();
      });
    }
    if (widget.onVisible != null && !_visibleFired) {
      _visibleFired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onVisible?.call();
      });
    }
    if (widget.onBackground != null || widget.onForeground != null) {
      _observingLifecycle = true;
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.onBackground?.call();
    } else if (state == AppLifecycleState.resumed) {
      widget.onForeground?.call();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
