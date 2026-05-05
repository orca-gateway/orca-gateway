import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'orca_icon.dart';

/// Monospace block that pretty-prints any JSON-ish value with light
/// syntax highlighting. A copy-to-clipboard button sits in the top-right
/// corner; click feedback is a brief icon-swap to a check mark.
/// Ported from the prototype's `JSONViewer` + the tiny regex-based
/// tokenizer in `screens/timeline-state.jsx`.
class JsonViewer extends StatefulWidget {
  final dynamic value;

  const JsonViewer({super.key, required this.value});

  @override
  State<JsonViewer> createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer> {
  bool _copied = false;
  Timer? _copyResetTimer;

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  String _stringify() {
    final v = widget.value;
    if (v is String) return v;
    try {
      return const JsonEncoder.withIndent('  ').convert(v);
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _stringify()));
    if (!mounted) return;
    setState(() => _copied = true);
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    if (widget.value == null) {
      return Text(
        '—',
        style: TextStyle(
          fontFamily: kSfMono,
          fontFamilyFallback: kSfMonoFallback,
          fontSize: fs(12, theme.fontScale),
          color: theme.text.tertiary,
        ),
      );
    }
    final text = _stringify();
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 40, 14),
          decoration: BoxDecoration(
            color: theme.surface.raised,
            border: Border.all(color: theme.border.hairline, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: kSfMono,
                fontFamilyFallback: kSfMonoFallback,
                fontSize: fs(12, theme.fontScale),
                color: theme.text.primary,
                height: 1.55,
              ),
              children: _tokenize(text, theme),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: _CopyButton(
            copied: _copied,
            onTap: _copy,
          ),
        ),
      ],
    );
  }

  /// Lightweight token coloring: strings (key vs value), numbers,
  /// booleans/null, punctuation. Mirrors `syntaxHighlight` in the JSX.
  static List<TextSpan> _tokenize(String text, OrcaTheme theme) {
    final spans = <TextSpan>[];
    final pattern = RegExp(
      r'("(?:\\.|[^"\\])*")|(\b-?\d+(?:\.\d+)?\b)|(\btrue\b|\bfalse\b|\bnull\b)|([\{\}\[\],:])',
    );
    int cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final str = match.group(1);
      final num = match.group(2);
      final kw = match.group(3);
      final punct = match.group(4);
      Color color;
      if (str != null) {
        final next = match.end < text.length ? text[match.end] : '';
        color = next == ':' ? theme.semantic.info : theme.semantic.success;
      } else if (num != null) {
        color = theme.semantic.warning;
      } else if (kw != null) {
        color = theme.semantic.scopeApp;
      } else if (punct != null) {
        color = theme.text.tertiary;
      } else {
        color = theme.text.primary;
      }
      spans.add(TextSpan(text: match.group(0), style: TextStyle(color: color)));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}

class _CopyButton extends StatefulWidget {
  final bool copied;
  final VoidCallback onTap;

  const _CopyButton({required this.copied, required this.onTap});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final isCopied = widget.copied;
    final fg = isCopied ? theme.semantic.success : theme.text.secondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: isCopied ? 'Copied!' : 'Copy',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _hover
                  ? theme.surface.hover
                  : theme.surface.content.withValues(alpha: 0.7),
              border: Border.all(color: theme.border.hairline, width: 1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: OrcaIcon(
                isCopied ? 'check' : 'copy',
                key: ValueKey(isCopied),
                size: 11,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
