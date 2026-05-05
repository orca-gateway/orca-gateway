import '../types/widget.dart';

// ── Scaffold ────────────────────────────────────────────────

class Scaffold extends StructureWidget {
  @override
  String get type => 'Scaffold';
  @override
  String get childMode => 'none';

  Widget? _body;
  Widget? _appBar;
  Widget? _floatingActionButton;
  Widget? _bottomNavigationBar;
  Widget? _drawer;
  final Map<String, dynamic> _props;

  Scaffold({
    Widget? body,
    Widget? appBar,
    Widget? floatingActionButton,
    Widget? bottomNavigationBar,
    Widget? drawer,
    dynamic backgroundColor,
    Map<String, dynamic>? actions,
  })  : _body = body,
        _appBar = appBar,
        _floatingActionButton = floatingActionButton,
        _bottomNavigationBar = bottomNavigationBar,
        _drawer = drawer,
        _props = {
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
        } {
    this.actions = actions;
  }

  @override
  List<SlotEntry> getSlotWidgets() {
    final slots = <SlotEntry>[];
    if (_appBar != null) slots.add(SlotEntry('appBar', _appBar!));
    if (_body != null) slots.add(SlotEntry('body', _body!));
    if (_floatingActionButton != null) {
      slots.add(SlotEntry('floatingActionButton', _floatingActionButton!));
    }
    if (_bottomNavigationBar != null) {
      slots.add(SlotEntry('bottomNavigationBar', _bottomNavigationBar!));
    }
    if (_drawer != null) slots.add(SlotEntry('drawer', _drawer!));
    return slots;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── AppBar ──────────────────────────────────────────────────

class AppBar extends StructureWidget {
  @override
  String get type => 'AppBar';
  @override
  String get childMode => 'none';

  Widget? _title;
  Widget? _leading;
  final Map<String, dynamic> _props;

  AppBar({
    Widget? title,
    Widget? leading,
    dynamic backgroundColor,
    dynamic elevation,
    dynamic centerTitle,
    Map<String, dynamic>? actions,
  })  : _title = title,
        _leading = leading,
        _props = {
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (elevation != null) 'elevation': elevation,
          if (centerTitle != null) 'centerTitle': centerTitle,
        } {
    this.actions = actions;
  }

  @override
  List<SlotEntry> getSlotWidgets() {
    final slots = <SlotEntry>[];
    if (_title != null) slots.add(SlotEntry('title', _title!));
    if (_leading != null) slots.add(SlotEntry('leading', _leading!));
    return slots;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── BottomNavigationBar ────────────────────────────────────

class BottomNavigationBar extends StructureWidget {
  @override
  String get type => 'BottomNavigationBar';
  @override
  String get childMode => 'none';

  final List<Widget> _items;
  final Map<String, dynamic> _props;

  BottomNavigationBar({
    List<Widget> items = const [],
    dynamic currentIndex,
    dynamic backgroundColor,
    dynamic selectedItemColor,
    dynamic unselectedItemColor,
    Map<String, dynamic>? actionTriggers,
  })  : _items = items,
        _props = {
          if (currentIndex != null) 'currentIndex': currentIndex,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (selectedItemColor != null) 'selectedItemColor': selectedItemColor,
          if (unselectedItemColor != null)
            'unselectedItemColor': unselectedItemColor,
        } {
    actions = actionTriggers;
  }

  @override
  List<SlotEntry> getSlotWidgets() {
    final slots = <SlotEntry>[];
    for (var i = 0; i < _items.length; i++) {
      slots.add(SlotEntry('item_$i', _items[i]));
    }
    return slots;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── BottomNavItem ──────────────────────────────────────────

class BottomNavItem extends PrimitiveWidget {
  @override
  String get type => 'BottomNavItem';

  final Map<String, dynamic> _props;

  BottomNavItem({
    required dynamic icon,
    required dynamic label,
    dynamic activeIcon,
    dynamic tooltip,
    dynamic backgroundColor,
  }) : _props = {
          'icon': icon,
          'label': label,
          if (activeIcon != null) 'activeIcon': activeIcon,
          if (tooltip != null) 'tooltip': tooltip,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
        };

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Drawer ──────────────────────────────────────────────────

class Drawer extends SingleChildLayout {
  @override
  String get type => 'Drawer';
  final Map<String, dynamic> _props;

  Drawer({
    Widget? child,
    dynamic backgroundColor,
    dynamic elevation,
    dynamic width,
    Map<String, dynamic>? actions,
  }) : _props = {
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (elevation != null) 'elevation': elevation,
          if (width != null) 'width': width,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Card ────────────────────────────────────────────────────

class Card extends SingleChildLayout {
  @override
  String get type => 'Card';
  final Map<String, dynamic> _props;

  Card({
    Widget? child,
    dynamic elevation,
    dynamic color,
    dynamic borderRadius,
    dynamic margin,
    Map<String, dynamic>? actions,
  }) : _props = {
          if (elevation != null) 'elevation': elevation,
          if (color != null) 'color': color,
          if (borderRadius != null) 'borderRadius': borderRadius,
          if (margin != null) 'margin': margin,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}
