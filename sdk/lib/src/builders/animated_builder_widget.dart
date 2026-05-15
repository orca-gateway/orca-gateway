import 'package:flutter/widgets.dart';
import '../rendering/component_context.dart';
import '../rendering/component_registry.dart';
import '../state/elm_store.dart';
import '../state/watch_builder.dart';

/// Flutter StatefulWidget that drives explicit animations for
/// the Orca Gateway `AnimatedBuilder` component type.
///
/// Creates an [AnimationController] and re-renders its children on every
/// frame with [animationProgress] set, so that `V.Tween` / `V.TweenSequence`
/// values in descendant props are interpolated automatically.
class OrcaAnimatedBuilder extends StatefulWidget {
  final int duration;
  final Curve curve;
  final bool repeat;
  final bool reverse;
  final bool autoStart;
  final String? animationId;
  final OrcaComponentContext parentContext;
  final ElmStore? pageStore;
  final ElmStore? appStore;

  const OrcaAnimatedBuilder({
    super.key,
    required this.duration,
    required this.curve,
    this.repeat = false,
    this.reverse = false,
    this.autoStart = true,
    this.animationId,
    required this.parentContext,
    this.pageStore,
    this.appStore,
  });

  @override
  State<OrcaAnimatedBuilder> createState() => _OrcaAnimatedBuilderState();
}

class _OrcaAnimatedBuilderState extends State<OrcaAnimatedBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.duration),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    // Register in the AnimationRegistry if an animationId is provided.
    final animationId = widget.animationId;
    if (animationId != null) {
      widget.parentContext.actionExecutor?.animationRegistry
          ?.register(animationId, _controller, _animation);
    }

    _controller.addStatusListener(_onAnimationStatus);

    if (widget.autoStart) {
      if (widget.repeat) {
        _controller.repeat(reverse: widget.reverse);
      } else {
        _controller.forward();
      }
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      widget.parentContext.fireAction('onComplete');
    }
  }

  @override
  void dispose() {
    final animationId = widget.animationId;
    if (animationId != null) {
      widget.parentContext.actionExecutor?.animationRegistry
          ?.unregister(animationId);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => _buildChildrenWithProgress(_animation.value),
    );
  }

  Widget _buildChildrenWithProgress(double progress) {
    final ctx = widget.parentContext;
    final registry = ctx.registry;
    if (registry == null) return const SizedBox.shrink();

    final children = <Widget>[];
    for (final childId in ctx.childIds) {
      final child = _buildDescendant(childId, progress, ctx, registry);
      children.add(child);
    }

    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1 && !_hasPositionedChild(ctx)) {
      return children.first;
    }
    return Stack(fit: StackFit.expand, children: children);
  }

  bool _hasPositionedChild(OrcaComponentContext ctx) {
    for (final childId in ctx.childIds) {
      final node = ctx.nodeMap[childId];
      if (node != null && node.type == 'Positioned') return true;
    }
    return false;
  }

  Widget _buildDescendant(
    String nodeId,
    double progress,
    OrcaComponentContext ancestorCtx,
    ComponentRegistry registry,
  ) {
    final node = ancestorCtx.nodeMap[nodeId];
    if (node == null) return ErrorWidget('Node not found: $nodeId');

    final builder = registry.get(node.type);
    if (builder == null) return ErrorWidget('Unknown type: ${node.type}');

    // Wrap nodes with watches in WatchBuilder so reactive state (e.g.
    // V.pageState("balanceVisible")) updates even inside AnimatedBuilder.
    if ((widget.pageStore != null || widget.appStore != null) &&
        node.watches.isNotEmpty) {
      return WatchBuilder(
        key: ValueKey('anim_watch_$nodeId'),
        pageStore: widget.pageStore,
        appStore: widget.appStore,
        watches: node.watches.toSet(),
        builder: (_, watchedState) {
          final merged = {...ancestorCtx.state, ...watchedState};
          return _buildNodeWithState(node, merged, progress, ancestorCtx, registry, builder);
        },
      );
    }

    return _buildNodeWithState(node, ancestorCtx.state, progress, ancestorCtx, registry, builder);
  }

  Widget _buildNodeWithState(
    dynamic node,
    Map<String, dynamic> state,
    double progress,
    OrcaComponentContext ancestorCtx,
    ComponentRegistry registry,
    dynamic builder,
  ) {
    final childContext = OrcaComponentContext(
      node: node,
      nodeMap: ancestorCtx.nodeMap,
      renderChild: (grandchildId) =>
          _buildDescendant(grandchildId, progress, ancestorCtx, registry),
      state: state,
      actionExecutor: ancestorCtx.actionExecutor,
      animationProgress: progress,
      registry: registry,
    );
    return builder(childContext);
  }
}
