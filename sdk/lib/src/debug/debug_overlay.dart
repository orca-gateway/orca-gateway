import 'package:flutter/material.dart';

class OrcaDebugOverlay extends StatefulWidget {
  final Widget child;
  final double? lastLoadTimeMs;
  final int? componentCount;
  final String? cacheStatus;

  const OrcaDebugOverlay({
    super.key,
    required this.child,
    this.lastLoadTimeMs,
    this.componentCount,
    this.cacheStatus,
  });

  @override
  State<OrcaDebugOverlay> createState() => _OrcaDebugOverlayState();
}

class _OrcaDebugOverlayState extends State<OrcaDebugOverlay> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 8,
          bottom: 8,
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: _expanded ? _buildExpanded() : _buildCollapsed(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsed() {
    final time = widget.lastLoadTimeMs?.toStringAsFixed(0) ?? '-';
    return Text('${time}ms',
        style: const TextStyle(
            color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace'));
  }

  Widget _buildExpanded() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Load: ${widget.lastLoadTimeMs?.toStringAsFixed(1) ?? "-"}ms',
            style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontFamily: 'monospace')),
        Text('Components: ${widget.componentCount ?? "-"}',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace')),
        Text('Cache: ${widget.cacheStatus ?? "-"}',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace')),
      ],
    );
  }
}
