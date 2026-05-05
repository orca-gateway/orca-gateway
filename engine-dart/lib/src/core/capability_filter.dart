import '../types/context.dart';
import '../types/node.dart';
import 'fallback_policy.dart';

class FilterResult {
  final List<ComponentNode> components;
  final List<String> droppedFeatures;
  final bool replacedWithBlocker;
  final bool addedWarnBanner;

  const FilterResult({
    required this.components,
    this.droppedFeatures = const [],
    this.replacedWithBlocker = false,
    this.addedWarnBanner = false,
  });
}

const _warnRootId = '__caps_warn_root__';
const _warnBannerId = '__caps_warn_banner__';
const _blockRootId = '__caps_block_root__';
const _alwaysSupportedWidgets = {'FallbackPrompt'};

FilterResult filterByCapabilities(
  List<ComponentNode> components,
  CapabilityVector? caps,
  FallbackPolicyResolver resolver,
) {
  if (caps == null || components.isEmpty) {
    return FilterResult(components: components);
  }

  final support = _buildSupportLookup(caps);

  // Pass 1: per-node unsupported-feature detection
  final nodeIssues = <String, List<String>>{};
  for (final node in components) {
    final missing = _collectUnsupportedFeatures(node, support);
    if (missing.isNotEmpty) {
      nodeIssues[node.id] = missing;
    }
  }

  if (nodeIssues.isEmpty) {
    return FilterResult(components: components);
  }

  // Pass 2: per-node policy decision
  final nodeMode = <String, FallbackMode>{};
  final droppedFeatures = <String>[];
  var anyRequire = false;
  var anyWarn = false;

  for (final entry in nodeIssues.entries) {
    final modes = entry.value.map((f) => resolver.resolve(f)).toList();
    final mode = highestSeverity(modes);
    nodeMode[entry.key] = mode;
    if (mode == FallbackMode.require) anyRequire = true;
    if (mode == FallbackMode.warn) anyWarn = true;
    if (mode == FallbackMode.graceful) {
      droppedFeatures.addAll(entry.value);
    }
  }

  // Pass 3: apply decisions
  if (anyRequire) {
    return FilterResult(
      components: [_buildBlockingRoot(nodeIssues)],
      replacedWithBlocker: true,
    );
  }

  // Graceful drops may promote to warn for structure widget slot children.
  final parentOf = _buildParentMap(components);
  final byId = {for (final n in components) n.id: n};
  final toDrop = <String>{};

  for (final entry in nodeMode.entries) {
    if (entry.value != FallbackMode.graceful) continue;
    final parentId = parentOf[entry.key];
    if (parentId != null) {
      final parent = byId[parentId];
      if (parent != null && parent.kind == 'structure') {
        nodeMode[entry.key] = FallbackMode.warn;
        anyWarn = true;
        continue;
      }
    }
    toDrop.add(entry.key);
  }

  var filtered = components;
  if (toDrop.isNotEmpty) {
    filtered = _dropNodes(components, toDrop);
  }

  if (anyWarn) {
    final warnFeatureKeys = <String>[];
    for (final entry in nodeMode.entries) {
      if (entry.value == FallbackMode.warn) {
        final missing = nodeIssues[entry.key];
        if (missing != null) warnFeatureKeys.addAll(missing);
      }
    }
    filtered = _wrapWithWarnBanner(filtered, warnFeatureKeys);
  }

  return FilterResult(
    components: filtered,
    droppedFeatures: droppedFeatures,
    addedWarnBanner: anyWarn,
  );
}

// ── Support lookup ──────────────────────────────────────────

class _SupportLookup {
  final Set<String> widgets;
  final Set<String> valueKinds;
  final Set<String> actionKinds;
  final Set<String> transformKinds;
  final Set<String> boolExprOps;

  _SupportLookup({
    required this.widgets,
    required this.valueKinds,
    required this.actionKinds,
    required this.transformKinds,
    required this.boolExprOps,
  });
}

_SupportLookup _buildSupportLookup(CapabilityVector caps) {
  return _SupportLookup(
    widgets: {...caps.widgets, ..._alwaysSupportedWidgets},
    valueKinds: caps.valueKinds.toSet(),
    actionKinds: caps.actionKinds.toSet(),
    transformKinds: caps.transformKinds.toSet(),
    boolExprOps: caps.boolExprOps.toSet(),
  );
}

// ── Unsupported feature collection ──────────────────────────

const _knownValueKinds = {
  'static', 'state', 'info', 'request', 'event',
  'transform', 'conditional', 'tween', 'tweenSequence',
};

List<String> _collectUnsupportedFeatures(
  ComponentNode node,
  _SupportLookup support,
) {
  final missing = <String>[];

  if (!support.widgets.contains(node.type)) {
    missing.add('widget.${node.type}');
  }

  _walkPropsForFeatures(node.props, support, missing);

  if (node.actions != null) {
    _walkActionsForFeatures(node.actions!, support, missing);
  }

  return missing;
}

void _walkPropsForFeatures(
  dynamic value,
  _SupportLookup support,
  List<String> missing,
) {
  if (value == null) return;

  if (value is List) {
    for (final item in value) {
      _walkPropsForFeatures(item, support, missing);
    }
    return;
  }

  if (value is! Map) return;

  final valueType = value['type'];
  if (valueType is String) {
    if (_knownValueKinds.contains(valueType)) {
      if (!support.valueKinds.contains(valueType)) {
        missing.add('value.$valueType');
      }
    }
    // Transforms inside TransformValue.by
    if (valueType == 'transform') {
      final by = value['by'];
      if (by is List) {
        for (final t in by) {
          if (t is Map) {
            final tt = t['type'];
            if (tt is String && !support.transformKinds.contains(tt)) {
              missing.add('transform.$tt');
            }
            _walkPropsForFeatures(t, support, missing);
          }
        }
      }
      _walkPropsForFeatures(value['input'], support, missing);
      return;
    }
    // Conditional values
    if (valueType == 'conditional') {
      final branches = value['branches'];
      if (branches is List) {
        for (final branch in branches) {
          if (branch is Map) {
            _walkBoolExprForFeatures(branch['when'], support, missing);
            _walkPropsForFeatures(branch['then'], support, missing);
          }
        }
      }
      _walkPropsForFeatures(value['else'], support, missing);
      return;
    }
  }

  final opKind = value['op'];
  if (opKind is String) {
    _walkBoolExprForFeatures(value, support, missing);
    return;
  }

  // Plain object: recurse
  for (final v in value.values) {
    _walkPropsForFeatures(v, support, missing);
  }
}

void _walkBoolExprForFeatures(
  dynamic expr,
  _SupportLookup support,
  List<String> missing,
) {
  if (expr is! Map) return;
  final op = expr['op'];
  if (op is String) {
    if (!support.boolExprOps.contains(op)) {
      missing.add('boolExpr.$op');
    }
  }
  for (final v in expr.values) {
    if (v is List) {
      for (final item in v) {
        _walkBoolExprForFeatures(item, support, missing);
      }
    } else if (v is Map) {
      if (v['op'] is String) {
        _walkBoolExprForFeatures(v, support, missing);
      } else if (v['type'] is String) {
        _walkPropsForFeatures(v, support, missing);
      }
    }
  }
}

void _walkActionsForFeatures(
  Map<String, dynamic> actions,
  _SupportLookup support,
  List<String> missing,
) {
  for (final action in actions.values) {
    _walkSingleAction(action, support, missing);
  }
}

void _walkSingleAction(
  dynamic action,
  _SupportLookup support,
  List<String> missing,
) {
  if (action is! Map) return;
  final kind = action['type'];
  if (kind is! String) return;

  if (!support.actionKinds.contains(kind)) {
    missing.add('action.$kind');
  }

  if (kind == 'actionGroup') {
    final nested = action['actions'];
    if (nested is List) {
      for (final a in nested) {
        _walkSingleAction(a, support, missing);
      }
    }
  } else if (kind == 'conditionalAction') {
    final branches = action['branches'];
    if (branches is List) {
      for (final branch in branches) {
        if (branch is Map) {
          _walkBoolExprForFeatures(branch['when'], support, missing);
          _walkSingleAction(branch['then'], support, missing);
        }
      }
    }
    if (action['else'] != null) {
      _walkSingleAction(action['else'], support, missing);
    }
  } else if (kind == 'lifecycle') {
    _walkSingleAction(action['action'], support, missing);
    for (final k in ['onLoading', 'onSuccess', 'onError', 'onComplete']) {
      final v = action[k];
      if (v is List) {
        for (final item in v) {
          _walkSingleAction(item, support, missing);
        }
      } else if (v != null) {
        _walkSingleAction(v, support, missing);
      }
    }
  }

  for (final entry in (action as Map).entries) {
    final key = entry.key;
    if (key == 'type' || key == 'actions' || key == 'branches') continue;
    _walkPropsForFeatures(entry.value, support, missing);
  }
}

// ── Structural transforms ──────────────────────────────────

Map<String, String> _buildParentMap(List<ComponentNode> components) {
  final parentOf = <String, String>{};
  for (final node in components) {
    for (final childId in node.children) {
      parentOf[childId] = node.id;
    }
  }
  return parentOf;
}

List<ComponentNode> _dropNodes(
  List<ComponentNode> components,
  Set<String> toDrop,
) {
  final byId = {for (final n in components) n.id: n};

  List<String> expandChildList(List<String> ids) {
    final out = <String>[];
    for (final id in ids) {
      if (toDrop.contains(id)) {
        final dropped = byId[id];
        if (dropped != null) {
          out.addAll(expandChildList(dropped.children));
        }
      } else {
        out.add(id);
      }
    }
    return out;
  }

  final survivors = <ComponentNode>[];
  for (final node in components) {
    if (toDrop.contains(node.id)) continue;
    final newChildren = expandChildList(node.children);
    if (_listsEqual(newChildren, node.children)) {
      survivors.add(node);
    } else {
      survivors.add(ComponentNode(
        id: node.id,
        type: node.type,
        kind: node.kind,
        childMode: node.childMode,
        props: node.props,
        children: newChildren,
        watches: node.watches,
        actions: node.actions,
      ));
    }
  }
  return survivors;
}

bool _listsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ── Synthesized FallbackPrompt nodes ──────────────��─────────

ComponentNode _buildBlockingRoot(Map<String, List<String>> nodeIssues) {
  final allFeatures = <String>[];
  for (final missing in nodeIssues.values) {
    allFeatures.addAll(missing);
  }
  final uniqueFeatures = allFeatures.toSet().toList();
  final preview = uniqueFeatures.take(3).join(', ');
  final extra =
      uniqueFeatures.length > 3 ? ', +${uniqueFeatures.length - 3} more' : '';

  return ComponentNode(
    id: _blockRootId,
    type: 'FallbackPrompt',
    kind: 'primitive',
    childMode: 'none',
    props: {
      'title': 'Update required',
      'body':
          'This screen needs features that this app version can\'t render '
          '($preview$extra). '
          'Please update from your app store to continue.',
      'severity': 'blocking',
    },
    children: [],
    watches: [],
  );
}

List<ComponentNode> _wrapWithWarnBanner(
  List<ComponentNode> components,
  List<String> missingFeatures,
) {
  if (components.isEmpty) return components;
  final originalRoot = components[0];
  final uniqueFeatures = missingFeatures.toSet().toList();
  final preview = uniqueFeatures.take(2).join(', ');
  final extra =
      uniqueFeatures.length > 2 ? ', +${uniqueFeatures.length - 2} more' : '';

  final banner = ComponentNode(
    id: _warnBannerId,
    type: 'FallbackPrompt',
    kind: 'primitive',
    childMode: 'none',
    props: {
      'title': 'Some content needs an update',
      'body':
          'Parts of this screen use features that your current app version '
          'can\'t fully render ($preview$extra). '
          'Please update when convenient for the full experience.',
      'severity': 'warn',
    },
    children: [],
    watches: [],
  );

  final wrapper = ComponentNode(
    id: _warnRootId,
    type: 'Column',
    kind: 'layout',
    childMode: 'multi',
    props: {
      'mainAxisAlignment': 'start',
      'crossAxisAlignment': 'stretch',
    },
    children: [_warnBannerId, originalRoot.id],
    watches: [],
  );

  return [wrapper, banner, ...components];
}
