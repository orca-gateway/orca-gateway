import 'package:flutter/widgets.dart';

/// Holds both the controller (for forward/reverse) and the curved
/// animation (for reading the current progress value).
class AnimationEntry {
  final AnimationController controller;
  final Animation<double> animation;

  const AnimationEntry(this.controller, this.animation);
}

/// Page-scoped registry mapping animation IDs to their entries.
///
/// Used by [OrcaAnimatedBuilder] to register controllers, and by
/// [ActionExecutor] to look them up when handling `animateForward`
/// and `animateReverse` actions, and by [ValueResolver] to read
/// progress for targeted tweens.
class AnimationRegistry {
  final Map<String, AnimationEntry> _entries = {};

  /// Register a controller and its curved animation with the given [id].
  void register(String id, AnimationController controller, Animation<double> animation) {
    _entries[id] = AnimationEntry(controller, animation);
  }

  /// Remove the entry for [id].
  void unregister(String id) {
    _entries.remove(id);
  }

  /// Look up a controller by [id]. Returns null if not registered.
  AnimationController? getController(String id) => _entries[id]?.controller;

  /// Look up the curved animation progress (0.0–1.0) by [id].
  double? getProgress(String id) => _entries[id]?.animation.value;
}
