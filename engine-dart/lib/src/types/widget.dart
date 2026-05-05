import 'node.dart';
import 'value.dart';

// ── Flatten ───────────────────────────────────────────────��─

/// Flatten a widget tree into a ComponentNode list with root first.
List<ComponentNode> flatten(Widget widget) {
  final encoder = WidgetEncoder();
  encoder.addNode(widget);
  final nodes = encoder.getNodes();
  return nodes.reversed.toList();
}

// ── Encoder ───────────────────��────────────────────────────���

class WidgetEncoder {
  final _nodes = <ComponentNode>[];
  int _nextId = 0;

  String addNode(Widget widget) {
    final id = widget.key ?? '${_nextId++}';
    final childIds = <String>[];

    if (widget is SingleChildLayout && widget.child != null) {
      childIds.add(addNode(widget.child!));
    } else if (widget is MultiChildLayout) {
      for (final child in widget.children) {
        childIds.add(addNode(child));
      }
    } else if (widget is ButtonWidget && widget.child != null) {
      childIds.add(addNode(widget.child!));
    }

    final props = widget.getProps();

    // Handle structure widgets with named slots
    if (widget is StructureWidget) {
      for (final slot in widget.getSlotWidgets()) {
        final slotId = addNode(slot.widget);
        childIds.add(slotId);
        props[slot.name] = slotId;
      }
    }

    final watches = _extractPropsWatches(props);

    _nodes.add(ComponentNode(
      id: id,
      type: widget.type,
      kind: widget.kind,
      childMode: widget.childMode,
      props: props,
      children: childIds,
      watches: watches,
      actions: widget.actions,
    ));

    return id;
  }

  List<ComponentNode> getNodes() => _nodes;
}

List<String> _extractPropsWatches(Map<String, dynamic> props) {
  final keys = <String>{};
  _walkForValues(props, keys);
  return keys.toList();
}

void _walkForValues(dynamic obj, Set<String> keys) {
  if (obj == null) return;

  if (isValue(obj)) {
    for (final k in V.extractWatches(obj)) {
      keys.add(k);
    }
    return;
  }

  if (obj is List) {
    for (final item in obj) {
      _walkForValues(item, keys);
    }
    return;
  }

  if (obj is Map) {
    for (final val in obj.values) {
      _walkForValues(val, keys);
    }
  }
}

// ── Widget Base Classes ───────────────────────────���─────────

abstract class Widget {
  String get type;
  String get kind;
  String get childMode;
  Map<String, dynamic>? actions;
  String? key;

  /// Set a stable key on this widget (fluent).
  Widget withKey(String key) {
    this.key = key;
    return this;
  }

  Map<String, dynamic> getProps();
}

// Layout widgets
abstract class LayoutWidget extends Widget {
  @override
  String get kind => 'layout';
}

abstract class SingleChildLayout extends LayoutWidget {
  @override
  String get childMode => 'single';
  Widget? child;
}

abstract class MultiChildLayout extends LayoutWidget {
  @override
  String get childMode => 'multi';
  List<Widget> children = [];
}

// Primitive widgets (no children)
abstract class PrimitiveWidget extends Widget {
  @override
  String get kind => 'primitive';
  @override
  String get childMode => 'none';
}

// Input widgets (no children)
abstract class InputWidget extends Widget {
  @override
  String get kind => 'input';
  @override
  String get childMode => 'none';
}

// Button widgets (single child)
abstract class ButtonWidget extends Widget {
  @override
  String get kind => 'button';
  @override
  String get childMode => 'single';
  Widget? child;
}

// Structure widgets (named slots)
abstract class StructureWidget extends Widget {
  @override
  String get kind => 'structure';

  /// Return named slots (e.g. appBar, body for Scaffold).
  List<SlotEntry> getSlotWidgets() => [];
}

class SlotEntry {
  final String name;
  final Widget widget;
  const SlotEntry(this.name, this.widget);
}
