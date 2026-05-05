// ignore_for_file: avoid_print
/// Generates lib/src/components/widgets.g.dart — typed widget shells
/// for every widget in open-source/schema/widget-registry.json.
///
/// Props are read from the registry's `props` array (added after the
/// registry schema was extended to carry a typed prop shape) and emitted as
/// named constructor parameters:
///
///   * kind="value"     → `dynamic` (accepts a literal or a V.* map)
///   * kind="widget"    → `Widget?` (stored in the widget's child slot on
///                        single-child/button kinds, or surfaced as a
///                        separate param on structure kinds)
///   * kind="widgetList"→ `List<Widget>` (used for dynamic-slot patterns;
///                        each item becomes a `item_N` slot so the shell
///                        also exposes `getSlotWidgets()` accordingly)
///   * kind="actionMap" → `Map<String, dynamic>?` (rare — most widgets use
///                        the base `actions` channel)
///
/// Required props emit as `required dynamic <name>`. Anything else defaults
/// to an optional named parameter. The generator does not emit widgets
/// listed in [handWritten] — those live in lib/src/components/ as
/// hand-maintained typed builders (used when the typed shell cannot
/// faithfully represent the widget's slot/prop layout, e.g. Scaffold or
/// BottomNavigationBar).
///
/// Run: dart run tool/gen_widget_builders.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final registryPath =
      '${scriptDir.parent.parent.path}/schema/widget-registry.json';
  final outputPath =
      '${scriptDir.parent.path}/lib/src/components/widgets.g.dart';

  final registryFile = File(registryPath);
  if (!registryFile.existsSync()) {
    print('ERROR: widget-registry.json not found at $registryPath');
    exit(1);
  }

  final json =
      jsonDecode(registryFile.readAsStringSync()) as Map<String, dynamic>;
  final widgets = json['widgets'] as List;

  // Widgets with hand-written typed builders in lib/src/components/.
  // Typically those that (a) have non-fixed slot shapes (e.g. dynamic
  // `item_N` slots), (b) predate the registry-driven generator and already
  // ship ergonomic constructors, or (c) need API shapes the generator
  // cannot express (e.g. heterogeneous required params).
  const handWritten = <String>{
    'Column', 'Row', 'Text', 'Container', 'Scaffold', 'Padding',
    'Center', 'SizedBox', 'Stack', 'Positioned', 'Expanded', 'Flexible',
    'ListView', 'SingleChildScrollView', 'Opacity',
    'ElevatedButton', 'TextButton', 'OutlinedButton', 'IconButton',
    'TextField', 'Icon', 'Image', 'Spacer', 'Divider',
    'AppBar', 'Card',
    'BottomNavigationBar', 'BottomNavItem', 'Drawer',
  };

  final buf = StringBuffer();
  buf.writeln('// GENERATED FILE — DO NOT EDIT');
  buf.writeln('// Source: open-source/schema/widget-registry.json');
  buf.writeln('// Run: dart run tool/gen_widget_builders.dart');
  buf.writeln(
      '// For typed builders, see hand-written files in lib/src/components/.');
  buf.writeln();
  buf.writeln("import '../types/widget.dart';");
  buf.writeln();
  // Valueable-prop alias. TS widgets declare props as `Valueable<T>` —
  // either a literal of type T, or a `V.*` map reference resolved by the
  // client. Dart has no union types, so we erase to `Object` at runtime
  // but preserve T on the typedef so IDEs show the expected inner type.
  buf.writeln(
      '/// A value prop. Accepts either a literal of type [T] or a `V.*` map.');
  buf.writeln('typedef ValueOf<T> = Object;');
  buf.writeln();

  var generated = 0;
  for (final w in widgets) {
    final type = w['type'] as String;
    if (handWritten.contains(type)) continue;

    final kind = w['kind'] as String;
    final childMode = w['childMode'] as String;
    final slots = (w['slots'] as List?)?.cast<String>() ?? const [];
    final props = ((w['props'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    final baseClass = _baseClass(kind, childMode);
    final className = _dartClassName(type);

    // Partition props by kind so the emitter can handle each group cleanly.
    final valueProps = props.where((p) => p['kind'] == 'value').toList();
    final widgetProps = props.where((p) => p['kind'] == 'widget').toList();
    final widgetListProps =
        props.where((p) => p['kind'] == 'widgetList').toList();
    final actionMapProps =
        props.where((p) => p['kind'] == 'actionMap').toList();

    // Widget[] props have two shapes:
    //   * structure widget → each item becomes an `item_N` slot, so the
    //     generated class overrides `getSlotWidgets()`.
    //   * multi-child layout → the list is an alias for the base class's
    //     `children` channel (e.g. CustomScrollView.slivers). Route the
    //     constructor arg to `this.children` and skip the slot override.
    //
    // Anything else (multiple widgetList props, widgetList on a non-multi
    // non-structure base) is not expressible by the generator — the author
    // should hand-write the typed shell and add it to [handWritten].
    final hasDynamicSlots = widgetListProps.isNotEmpty;
    if (hasDynamicSlots && widgetListProps.length > 1) {
      print(
          'WARN: $type has multiple widgetList props — generator only '
          'supports one. Promote to handWritten. Skipping.');
      continue;
    }
    final widgetListAsChildren =
        hasDynamicSlots && kind != 'structure' && childMode == 'multi';
    final widgetListAsSlots =
        hasDynamicSlots && kind == 'structure';
    if (hasDynamicSlots && !widgetListAsChildren && !widgetListAsSlots) {
      print(
          'WARN: $type has a widgetList prop but neither multi-child nor '
          'structure kind — promote to handWritten. Skipping.');
      continue;
    }

    buf.writeln('/// $type widget (generated shell).');
    buf.writeln('class $className extends $baseClass {');
    buf.writeln('  @override');
    buf.writeln("  String get type => '$type';");

    if (kind == 'structure') {
      buf.writeln('  @override');
      buf.writeln("  String get childMode => '$childMode';");
    }

    // Backing storage: a Map<String, dynamic> for serialized props and
    // Widget?/List<Widget> fields for slot-shaped props.
    buf.writeln('  final Map<String, dynamic> _props;');
    for (final slot in slots) {
      buf.writeln('  final Widget? _$slot;');
    }
    for (final wp in widgetProps) {
      if (kind == 'structure') {
        // Surface as independent slot field when the widget is structural.
        buf.writeln("  final Widget? _${wp['name']};");
      }
    }
    if (widgetListAsSlots) {
      buf.writeln('  final List<Widget> _${widgetListProps.first['name']};');
    }

    // Constructor ───────────────────────────────────────────────────
    buf.writeln();
    buf.writeln('  $className({');
    // Base-class child/children slots. For a multi-child layout that
    // aliases its child list under a different prop name (e.g.
    // CustomScrollView.slivers), the list param is emitted below via
    // widgetListProps — skip the default `children` param here to avoid
    // exposing a dead parameter that silently does nothing.
    if (childMode == 'single' && kind != 'structure') {
      buf.writeln('    Widget? child,');
    } else if (childMode == 'multi' && !widgetListAsChildren) {
      buf.writeln('    List<Widget> children = const [],');
    }
    // Structure fixed slots (declared via getSlotWidgets() in the source).
    for (final slot in slots) {
      buf.writeln('    Widget? $slot,');
    }
    // Widget props (only relevant as independent params for structure kind —
    // non-structure `Widget` typed props are already mapped through `child`).
    if (kind == 'structure') {
      for (final wp in widgetProps) {
        buf.writeln("    Widget? ${wp['name']},");
      }
    }
    // Named widget list — parameter is always exposed; its wiring (into
    // `children` vs. dynamic `item_N` slots) is decided above.
    if (hasDynamicSlots) {
      // Skip generating a second param if a duplicate name already came
      // from the fixed-children channel above (childMode=='multi' with
      // the prop literally named `children`).
      final name = widgetListProps.first['name'] as String;
      if (!(childMode == 'multi' && name == 'children')) {
        buf.writeln("    List<Widget> $name = const [],");
      }
    }
    // Value props — typed via [_dartParamType]. Required flag maps to the
    // TS `?:` annotation so non-optional props become `required` named
    // params in Dart (compile-time enforcement of the wire contract).
    for (final vp in valueProps) {
      final req = vp['optional'] == false;
      final paramType = _dartParamType(
        vp['type'] as String,
        vp['valueable'] as bool,
        req,
      );
      buf.writeln("    ${req ? 'required ' : ''}$paramType ${vp['name']},");
    }
    // Action-map props
    for (final ap in actionMapProps) {
      buf.writeln("    Map<String, dynamic>? ${ap['name']},");
    }
    // Standard actions channel (unless widget already has a prop named
    // `actions`, in which case the registry scraper will have filtered it).
    buf.writeln('    Map<String, dynamic>? actions,');
    buf.writeln('  })  : _props = {');
    for (final vp in valueProps) {
      final req = vp['optional'] == false;
      if (req) {
        buf.writeln("          '${vp['name']}': ${vp['name']},");
      } else {
        buf.writeln(
            "          if (${vp['name']} != null) '${vp['name']}': ${vp['name']},");
      }
    }
    for (final ap in actionMapProps) {
      buf.writeln(
          "          if (${ap['name']} != null) '${ap['name']}': ${ap['name']},");
    }
    buf.write('        }');
    // Slot field initializers
    for (final slot in slots) {
      buf.write(",\n        _$slot = $slot");
    }
    if (kind == 'structure') {
      for (final wp in widgetProps) {
        buf.write(",\n        _${wp['name']} = ${wp['name']}");
      }
    }
    if (widgetListAsSlots) {
      final name = widgetListProps.first['name'];
      buf.write(',\n        _$name = $name');
    }
    buf.writeln(' {');
    if (childMode == 'single' && kind != 'structure') {
      buf.writeln('    this.child = child;');
    } else if (childMode == 'multi') {
      // If the layout exposes the child list under a prop name other than
      // `children`, wire that prop into the base children channel instead.
      if (widgetListAsChildren) {
        final name = widgetListProps.first['name'];
        buf.writeln('    this.children = $name;');
      } else {
        buf.writeln('    this.children = children;');
      }
    }
    buf.writeln('    this.actions = actions;');
    buf.writeln('  }');

    // getSlotWidgets() ──────────────────────────────────────────────
    final needsSlotFn = slots.isNotEmpty ||
        widgetListAsSlots ||
        (kind == 'structure' && widgetProps.isNotEmpty);
    if (needsSlotFn) {
      buf.writeln();
      buf.writeln('  @override');
      buf.writeln('  List<SlotEntry> getSlotWidgets() {');
      buf.writeln('    final slots = <SlotEntry>[];');
      for (final slot in slots) {
        buf.writeln(
            "    if (_$slot != null) slots.add(SlotEntry('$slot', _$slot));");
      }
      if (kind == 'structure') {
        for (final wp in widgetProps) {
          buf.writeln(
              "    if (_${wp['name']} != null) slots.add(SlotEntry('${wp['name']}', _${wp['name']}));");
        }
      }
      if (widgetListAsSlots) {
        final name = widgetListProps.first['name'];
        buf.writeln('    for (var i = 0; i < _$name.length; i++) {');
        buf.writeln("      slots.add(SlotEntry('item_\$i', _$name[i]));");
        buf.writeln('    }');
      }
      buf.writeln('    return slots;');
      buf.writeln('  }');
    }

    buf.writeln();
    buf.writeln('  @override');
    buf.writeln(
        '  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);');
    buf.writeln('}');
    buf.writeln();
    generated++;
  }

  final outputDir = Directory(File(outputPath).parent.path);
  if (!outputDir.existsSync()) outputDir.createSync(recursive: true);
  File(outputPath).writeAsStringSync(buf.toString());

  print('Generated $generated widget shells → $outputPath');
  print('Skipped ${handWritten.length} hand-written widgets.');
}

String _baseClass(String kind, String childMode) {
  switch (kind) {
    case 'layout':
      return childMode == 'single' ? 'SingleChildLayout' : 'MultiChildLayout';
    case 'primitive':
      return 'PrimitiveWidget';
    case 'input':
      return 'InputWidget';
    case 'button':
      return 'ButtonWidget';
    case 'structure':
      return 'StructureWidget';
    default:
      return 'PrimitiveWidget';
  }
}

String _dartClassName(String type) {
  // Avoid Dart keyword / class-name conflicts.
  if (type == 'Switch') return 'SwitchWidget';
  return type;
}

/// Map a TS prop type (as recorded in `props[].type`) to a Dart parameter
/// type. For `Valueable<T>` props the result is wrapped in `ValueOf<T>` so
/// the IDE still shows the expected inner type even though at runtime the
/// alias erases to `Object`. Optional params get a trailing `?`; required
/// params do not (they must be non-null to satisfy `required`).
String _dartParamType(String tsType, bool valueable, bool required) {
  final inner = _mapInnerType(tsType);
  final base = valueable ? 'ValueOf<$inner>' : inner;
  return required ? base : '$base?';
}

/// Translate a TS inner type into its closest Dart equivalent.
///
/// Known scalars map directly. String-literal unions (`"a" | "b" | …`) map
/// to `String`. The engine's helper data types (`EdgeInsetsData`,
/// `TextStyleData`, …) are wire-shaped maps, so they map to
/// `Map<String, dynamic>`. Engine-level enum aliases (`MainAxisAlignment`,
/// `AlignmentValue`, …) are string constants and map to `String`.
/// Anything not explicitly recognized falls back to `Object` so the
/// generator stays future-proof when a new TS type shows up.
String _mapInnerType(String tsType) {
  final t = tsType.trim();
  if (t.startsWith('"') || t.contains(' | "') || t.startsWith("'")) {
    return 'String';
  }
  switch (t) {
    case 'number':
      return 'num';
    case 'string':
      return 'String';
    case 'boolean':
      return 'bool';
    case 'string | MaterialIcons':
    case 'MaterialIcons':
      return 'String';
    case 'AlignmentValue':
    case 'MainAxisAlignment':
    case 'CrossAxisAlignment':
    case 'MainAxisSize':
    case 'Axis':
    case 'StackFit':
    case 'ImageFit':
    case 'InputType':
    case 'FontWeight':
    case 'TextDecoration':
    case 'Curve':
    case 'FallbackPromptSeverity':
      return 'String';
    case 'EdgeInsetsData':
    case 'TextStyleData':
    case 'BoxDecorationData':
    case 'BorderRadiusData':
    case 'BoxConstraintsData':
    case 'TextSpanData':
    case 'PositionedData':
    case 'BoxShadowData':
    case 'BorderData':
    case 'GradientData':
      return 'Map<String, dynamic>';
    case 'TransformMatrix':
      return 'List<num>';
    case 'Record<number, number>':
      return 'Map<num, num>';
    case 'Record<string, Value>':
      return 'Map<String, dynamic>';
  }
  // Inline object type like `{ color?: string; width?: number }` — always
  // serializes as a map on the wire.
  if (t.startsWith('{') && t.endsWith('}')) return 'Map<String, dynamic>';
  return 'Object';
}
