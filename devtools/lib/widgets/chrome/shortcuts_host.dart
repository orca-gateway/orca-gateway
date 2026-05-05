import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Root-level keyboard shortcuts host.
/// Registers ⌘ / Ctrl key bindings and an autofocused [Focus] node so raw
/// key events have somewhere to land when no TextField is focused.
///
/// Both `meta:` and `control:` variants are registered so the same binding
/// fires from ⌘ on macOS and Ctrl on Linux / Windows without branching.
class ShortcutsHost extends StatelessWidget {
  final VoidCallback onTogglePalette;
  final VoidCallback onClosePalette;
  final VoidCallback onExport;
  final ValueChanged<String> onJumpToInspector;
  final Widget child;

  const ShortcutsHost({
    super.key,
    required this.onTogglePalette,
    required this.onClosePalette,
    required this.onExport,
    required this.onJumpToInspector,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, VoidCallback>{
      // Command palette
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          onTogglePalette,
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          onTogglePalette,
      const SingleActivator(LogicalKeyboardKey.escape): onClosePalette,

      // Jump to inspector
      const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
          onJumpToInspector('timeline'),
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
          onJumpToInspector('timeline'),
      const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
          onJumpToInspector('state'),
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
          onJumpToInspector('state'),
      const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () =>
          onJumpToInspector('actions'),
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
          onJumpToInspector('actions'),
      const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () =>
          onJumpToInspector('network'),
      const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
          onJumpToInspector('network'),
      const SingleActivator(LogicalKeyboardKey.digit5, meta: true): () =>
          onJumpToInspector('errors'),
      const SingleActivator(LogicalKeyboardKey.digit5, control: true): () =>
          onJumpToInspector('errors'),
      const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
          onJumpToInspector('settings'),
      const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
          onJumpToInspector('settings'),

      // Export
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true): onExport,
      const SingleActivator(LogicalKeyboardKey.keyE, control: true):
          onExport,
    };

    // Nesting matters: the primary-focused widget must be a *descendant* of
    // CallbackShortcuts, not an ancestor, or the handler never fires. Put
    // shortcuts outside and the autofocused Focus inside.
    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
