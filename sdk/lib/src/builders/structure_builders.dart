import 'package:flutter/material.dart' show
    BottomNavigationBar,
    BottomNavigationBarItem,
    Drawer,
    RoundedRectangleBorder,
    Scaffold,
    AppBar,
    Card,
    SliverAppBar,
    Theme,
    ThemeData;
import 'package:flutter/widgets.dart';
import '../navigation/navigation_handler.dart';
import '../rendering/component_context.dart';
import '../rendering/component_registry.dart';
import 'builder_helpers.dart';

/// Register all structure component builders.
void registerStructureBuilders(ComponentRegistry registry) {
  registry.register('Scaffold', _buildScaffold);
  registry.register('AppBar', _buildAppBar);
  registry.register('Card', _buildCard);
  registry.register('ListView', _buildListView);
  registry.register('GridView', _buildGridView);
  registry.register('Dialog', _buildDialog);
  registry.register('BottomSheet', _buildBottomSheet);
  registry.register('BottomNavigationBar', _buildBottomNavigationBar);
  registry.register('BottomNavItem', _buildBottomNavItem);
  registry.register('Drawer', _buildDrawer);
  registry.register('CustomScrollView', _buildCustomScrollView);
  registry.register('SliverList', _buildSliverList);
  registry.register('SliverGrid', _buildSliverGrid);
  registry.register('SliverToBoxAdapter', _buildSliverToBoxAdapter);
  registry.register('SliverAppBar', _buildSliverAppBar);
  registry.register('SnackBar', _buildSnackBar);
}

Widget _buildScaffold(OrcaComponentContext ctx) {
  final body = renderSlot(ctx, 'body');
  final appBar = renderSlot(ctx, 'appBar');
  final fab = renderSlot(ctx, 'floatingActionButton');
  final bottomNav = renderSlot(ctx, 'bottomNavigationBar');
  final drawer = renderSlot(ctx, 'drawer');
  final endDrawer = renderSlot(ctx, 'endDrawer');
  final bottomSheet = renderSlot(ctx, 'bottomSheet');
  final bgColor = parseColor(ctx.prop('backgroundColor'));
  final resizeToAvoidBottomInset = ctx.prop<bool>('resizeToAvoidBottomInset');

  // Collect indexed persistentFooterButton_N slots (same pattern as AppBar.actions).
  final persistentFooterButtons = <Widget>[];
  for (var i = 0; i < 10; i++) {
    final btn = renderSlot(ctx, 'persistentFooterButton_$i');
    if (btn == null) break;
    persistentFooterButtons.add(btn);
  }

  // Use AppBar's toolbarHeight prop when the preview harness set one, falling
  // back to Material's default 56 — matches Scaffold's own pre-M3 default.
  final toolbarHeight =
      (ctx.prop<num>('toolbarHeight'))?.toDouble() ?? 56;

  return Theme(
    data: ThemeData(),
    child: Scaffold(
      appBar: appBar != null
          ? PreferredSize(
              preferredSize: Size.fromHeight(toolbarHeight),
              child: appBar,
            )
          : null,
      body: body,
      floatingActionButton: fab,
      bottomNavigationBar: bottomNav,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomSheet: bottomSheet,
      persistentFooterButtons:
          persistentFooterButtons.isNotEmpty ? persistentFooterButtons : null,
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    ),
  );
}

Widget _buildAppBar(OrcaComponentContext ctx) {
  final title = renderSlot(ctx, 'title');
  final leading = renderSlot(ctx, 'leading');
  final bgColor = parseColor(ctx.prop('backgroundColor'));
  final elevation = (ctx.prop<num>('elevation'))?.toDouble();
  final centerTitle = ctx.prop<bool>('centerTitle');
  final toolbarHeight = (ctx.prop<num>('toolbarHeight'))?.toDouble();
  final leadingWidth = (ctx.prop<num>('leadingWidth'))?.toDouble();
  final automaticallyImplyLeading =
      ctx.propOr<bool>('automaticallyImplyLeading', true);
  final shadowColor = parseColor(ctx.prop('shadowColor'));

  // Collect indexed action slots
  final actions = <Widget>[];
  for (var i = 0; i < 10; i++) {
    final action = renderSlot(ctx, 'action_$i');
    if (action == null) break;
    actions.add(action);
  }

  return Theme(
    data: ThemeData(),
    child: AppBar(
      title: title,
      leading: leading,
      actions: actions.isNotEmpty ? actions : null,
      backgroundColor: bgColor,
      elevation: elevation,
      centerTitle: centerTitle,
      toolbarHeight: toolbarHeight,
      leadingWidth: leadingWidth,
      automaticallyImplyLeading: automaticallyImplyLeading,
      shadowColor: shadowColor,
    ),
  );
}

Widget _buildCard(OrcaComponentContext ctx) {
  final elevation = (ctx.prop<num>('elevation'))?.toDouble() ?? 1;
  final padding = parseEdgeInsets(ctx.prop('padding'));
  final margin = parseEdgeInsets(ctx.prop('margin'));
  final color = parseColor(ctx.prop('color'));
  final shadowColor = parseColor(ctx.prop('shadowColor'));
  final surfaceTintColor = parseColor(ctx.prop('surfaceTintColor'));
  final borderRadius = ctx.prop<num>('borderRadius')?.toDouble();

  Widget child = ctx.childIds.isNotEmpty
      ? renderChild(ctx)
      : const SizedBox.shrink();

  if (padding != null) {
    child = Padding(padding: padding, child: child);
  }

  final clipBehavior = ctx.prop<String>('clipBehavior');

  return Theme(
    data: ThemeData(),
    child: Card(
      elevation: elevation,
      color: color,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      margin: margin,
      // Card defaults to Clip.none when unset — match Flutter's default only
      // by passing the parsed value when the author opted in, otherwise let
      // Card pick its own (matches pre-change behavior).
      clipBehavior: clipBehavior != null ? parseClip(clipBehavior) : null,
      shape: borderRadius != null
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius))
          : null,
      child: child,
    ),
  );
}

Widget _buildListView(OrcaComponentContext ctx) {
  final scrollDirection = ctx.prop<String>('scrollDirection') == 'horizontal'
      ? Axis.horizontal
      : Axis.vertical;
  final padding = parseEdgeInsets(ctx.prop('padding'));
  final shrinkWrap = ctx.propOr<bool>('shrinkWrap', false);
  final reverse = ctx.propOr<bool>('reverse', false);
  final primary = ctx.prop<bool>('primary');
  final itemExtent = (ctx.prop<num>('itemExtent'))?.toDouble();
  final children = renderChildren(ctx);
  final separator = renderSlot(ctx, 'separator');

  Widget listView;
  if (separator != null) {
    final withSeparators = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      withSeparators.add(children[i]);
      if (i < children.length - 1) withSeparators.add(separator);
    }
    listView = ListView(
      scrollDirection: scrollDirection,
      padding: padding,
      shrinkWrap: shrinkWrap,
      reverse: reverse,
      primary: primary,
      itemExtent: itemExtent,
      children: withSeparators,
    );
  } else {
    listView = ListView(
      scrollDirection: scrollDirection,
      padding: padding,
      shrinkWrap: shrinkWrap,
      reverse: reverse,
      primary: primary,
      itemExtent: itemExtent,
      children: children,
    );
  }

  return wrapScrollNotifier(ctx, listView);
}

Widget _buildGridView(OrcaComponentContext ctx) {
  final crossAxisCount = ctx.propOr<int>('crossAxisCount', 2);
  final spacing = (ctx.prop<num>('mainAxisSpacing'))?.toDouble() ?? 0;
  final crossSpacing = (ctx.prop<num>('crossAxisSpacing'))?.toDouble() ?? 0;
  final childAspectRatio = (ctx.prop<num>('childAspectRatio'))?.toDouble() ?? 1.0;
  final padding = parseEdgeInsets(ctx.prop('padding'));
  final shrinkWrap = ctx.propOr<bool>('shrinkWrap', false);
  final primary = ctx.prop<bool>('primary');
  final scrollDirection = ctx.prop<String>('scrollDirection') == 'horizontal'
      ? Axis.horizontal
      : Axis.vertical;

  return wrapScrollNotifier(ctx, GridView.count(
    crossAxisCount: crossAxisCount,
    mainAxisSpacing: spacing,
    crossAxisSpacing: crossSpacing,
    childAspectRatio: childAspectRatio,
    scrollDirection: scrollDirection,
    padding: padding,
    shrinkWrap: shrinkWrap,
    primary: primary,
    children: renderChildren(ctx),
  ));
}

Widget _buildDialog(OrcaComponentContext ctx) {
  // Dialog nodes are hidden in the normal page tree.
  // They are rendered on-demand by the openDialog action handler.
  return const SizedBox.shrink();
}

Widget _buildBottomSheet(OrcaComponentContext ctx) {
  final bgColor = parseColor(ctx.prop('backgroundColor')) ?? const Color(0xFFFFFFFF);
  final borderRadius = ctx.prop<num>('borderRadius')?.toDouble() ?? 16;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(borderRadius),
        topRight: Radius.circular(borderRadius),
      ),
    ),
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : const SizedBox.shrink(),
  );
}

Widget _buildBottomNavigationBar(OrcaComponentContext ctx) {
  final bgColor = parseColor(ctx.prop('backgroundColor'));
  final selectedColor = parseColor(ctx.prop('selectedItemColor'));
  final unselectedColor = parseColor(ctx.prop('unselectedItemColor'));
  final currentIndex = ctx.propOr<int>('currentIndex', 0);

  // Collect items from indexed slots (item_0, item_1, ...)
  final items = <BottomNavigationBarItem>[];
  for (var i = 0; i < 10; i++) {
    final slotId = ctx.prop<String>('item_$i');
    if (slotId == null) break;
    final itemNode = ctx.nodeMap[slotId];
    if (itemNode == null) break;

    // BottomNavItem has icon, label, activeIcon props
    final iconName = itemNode.props['icon'] as String?;
    final activeIconName = itemNode.props['activeIcon'] as String?;
    final label = itemNode.props['label'] as String? ?? '';

    items.add(BottomNavigationBarItem(
      icon: Icon(NavigationHandler.resolveIcon(iconName)),
      activeIcon: activeIconName != null
          ? Icon(NavigationHandler.resolveIcon(activeIconName))
          : null,
      label: label,
    ));
  }

  if (items.isEmpty) return const SizedBox.shrink();

  return Theme(
    data: ThemeData(),
    child: BottomNavigationBar(
      currentIndex: currentIndex.clamp(0, items.length - 1),
      backgroundColor: bgColor,
      selectedItemColor: selectedColor,
      unselectedItemColor: unselectedColor,
      items: items,
      onTap: (index) {
        // Update the state key that currentIndex is bound to
        final raw = ctx.node.props['currentIndex'];
        if (raw is Map && raw['type'] == 'state') {
          final key = raw['key'] as String?;
          if (key != null) {
            final scope = raw['scope'] as String? ?? 'page';
            if (scope == 'app') {
              ctx.actionExecutor?.stateManager.setAppState(key, index);
            } else {
              ctx.actionExecutor?.stateManager.setPageState(
                ctx.actionExecutor!.pageId, key, index,
              );
            }
          }
        }
        ctx.fireAction('onChange', eventData: {'value': index});
      },
    ),
  );
}

/// BottomNavItem is a data-only component — it's consumed by BottomNavigationBar.
/// When rendered standalone (shouldn't happen normally), show a placeholder.
Widget _buildBottomNavItem(OrcaComponentContext ctx) {
  final label = ctx.prop<String>('label') ?? '';
  final iconName = ctx.prop<String>('icon');
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(NavigationHandler.resolveIcon(iconName)),
      if (label.isNotEmpty) ...[
        const SizedBox(width: 4),
        Text(label),
      ],
    ],
  );
}

Widget _buildDrawer(OrcaComponentContext ctx) {
  final bgColor = parseColor(ctx.prop('backgroundColor'));
  final elevation = (ctx.prop<num>('elevation'))?.toDouble();
  final width = (ctx.prop<num>('width'))?.toDouble();

  return Theme(
    data: ThemeData(),
    child: Drawer(
      backgroundColor: bgColor,
      elevation: elevation,
      width: width,
      child: ctx.childIds.isNotEmpty ? renderChild(ctx) : const SizedBox.shrink(),
    ),
  );
}

Widget _buildCustomScrollView(OrcaComponentContext ctx) {
  final scrollDirection = ctx.prop<String>('scrollDirection') == 'horizontal'
      ? Axis.horizontal
      : Axis.vertical;
  final reverse = ctx.propOr<bool>('reverse', false);
  final shrinkWrap = ctx.propOr<bool>('shrinkWrap', false);

  // Children should be sliver widgets (SliverList, SliverGrid, SliverToBoxAdapter, SliverAppBar).
  return wrapScrollNotifier(ctx, CustomScrollView(
    scrollDirection: scrollDirection,
    reverse: reverse,
    shrinkWrap: shrinkWrap,
    slivers: renderChildren(ctx),
  ));
}

Widget _buildSliverList(OrcaComponentContext ctx) {
  return SliverList(
    delegate: SliverChildListDelegate(renderChildren(ctx)),
  );
}

Widget _buildSliverGrid(OrcaComponentContext ctx) {
  final crossAxisCount = ctx.propOr<int>('crossAxisCount', 2);
  final mainAxisSpacing = (ctx.prop<num>('mainAxisSpacing'))?.toDouble() ?? 0;
  final crossAxisSpacing = (ctx.prop<num>('crossAxisSpacing'))?.toDouble() ?? 0;
  final childAspectRatio = (ctx.prop<num>('childAspectRatio'))?.toDouble() ?? 1.0;

  return SliverGrid(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
    ),
    delegate: SliverChildListDelegate(renderChildren(ctx)),
  );
}

Widget _buildSliverToBoxAdapter(OrcaComponentContext ctx) {
  return SliverToBoxAdapter(
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : const SizedBox.shrink(),
  );
}

Widget _buildSliverAppBar(OrcaComponentContext ctx) {
  final title = renderSlot(ctx, 'title');
  final leading = renderSlot(ctx, 'leading');
  final flexibleSpace = renderSlot(ctx, 'flexibleSpace');
  final bgColor = parseColor(ctx.prop('backgroundColor'));
  final elevation = (ctx.prop<num>('elevation'))?.toDouble();
  final centerTitle = ctx.prop<bool>('centerTitle');
  final floating = ctx.propOr<bool>('floating', false);
  final pinned = ctx.propOr<bool>('pinned', false);
  final snap = ctx.propOr<bool>('snap', false);
  final expandedHeight = (ctx.prop<num>('expandedHeight'))?.toDouble();
  final collapsedHeight = (ctx.prop<num>('collapsedHeight'))?.toDouble();

  final actions = <Widget>[];
  for (var i = 0; i < 10; i++) {
    final action = renderSlot(ctx, 'action_$i');
    if (action == null) break;
    actions.add(action);
  }

  return Theme(
    data: ThemeData(),
    child: SliverAppBar(
      title: title,
      leading: leading,
      actions: actions.isNotEmpty ? actions : null,
      flexibleSpace: flexibleSpace,
      backgroundColor: bgColor,
      elevation: elevation,
      centerTitle: centerTitle,
      floating: floating,
      pinned: pinned,
      snap: snap,
      expandedHeight: expandedHeight,
      collapsedHeight: collapsedHeight,
    ),
  );
}

Widget _buildSnackBar(OrcaComponentContext ctx) {
  final content = resolveStringValue(ctx.prop('content'), ctx.state);
  final bgColor = parseColor(ctx.prop('backgroundColor'));
  final actionLabel = ctx.prop<String>('actionLabel');

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: bgColor ?? const Color(0xFF323232),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            content,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
          ),
        ),
        if (actionLabel != null && actionLabel.isNotEmpty) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ctx.fireAction('onAction'),
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: Color(0xFFBB86FC),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
