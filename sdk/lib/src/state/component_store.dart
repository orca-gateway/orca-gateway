import 'dart:collection' show UnmodifiableMapView;
import 'package:flutter/foundation.dart';
import '../models/component_node.dart';

/// Mutable store for the component tree.
///
/// Holds a flat map of [ComponentNode]s by ID and supports structural
/// mutations (update props, delete, add subtree, replace subtree).
/// Notifies listeners on every mutation so the renderer can rebuild.
///
/// Node IDs are expected to be unique — the server uses `keyPrefix` on
/// addComponent/replaceComponent responses to namespace flattened IDs.
/// Signature for a SubPage content update callback.
typedef SubPageUpdateCallback = Future<void> Function(
    String pageId, Map<String, dynamic>? params, String mode);

class ComponentStore extends ChangeNotifier {
  final Map<String, ComponentNode> _nodeMap = {};
  String? _rootId;

  /// Registry of SubPage update callbacks, keyed by subPageId (stable key).
  /// SubPage widgets register themselves on mount and unregister on dispose.
  final Map<String, SubPageUpdateCallback> _subPageCallbacks = {};

  /// Register a SubPage update callback.
  void registerSubPage(String subPageId, SubPageUpdateCallback callback) {
    _subPageCallbacks[subPageId] = callback;
  }

  /// Unregister a SubPage update callback.
  void unregisterSubPage(String subPageId) {
    _subPageCallbacks.remove(subPageId);
  }

  /// Invoke the update callback for a SubPage. Returns false if not found.
  Future<bool> updateSubPage(
      String subPageId, String pageId, Map<String, dynamic>? params, String mode) async {
    final callback = _subPageCallbacks[subPageId];
    if (callback == null) return false;
    await callback(pageId, params, mode);
    return true;
  }

  /// Initialize from a flat node list (as received from the server).
  void init(List<ComponentNode> nodes) {
    _nodeMap.clear();
    for (final node in nodes) {
      _nodeMap[node.id] = node;
    }
    _rootId = nodes.isNotEmpty ? nodes.first.id : null;
  }

  /// The current node map (unmodifiable — use mutation methods to modify).
  Map<String, ComponentNode> get nodeMap => UnmodifiableMapView(_nodeMap);

  /// The root component ID.
  String? get rootId => _rootId;

  /// Build a flat node list from the current map (root first).
  List<ComponentNode> toList() {
    if (_rootId == null) return [];
    final result = <ComponentNode>[];
    _collectSubtree(_rootId!, result);
    return result;
  }

  void _collectSubtree(String id, List<ComponentNode> out) {
    final node = _nodeMap[id];
    if (node == null) return;
    out.add(node);
    for (final childId in node.children) {
      _collectSubtree(childId, out);
    }
  }

  /// Update props of an existing component by ID.
  /// Merges [props] into the existing props (shallow merge).
  void updateComponent(String id, Map<String, dynamic> props) {
    final node = _nodeMap[id];
    if (node == null) return;
    _nodeMap[id] = node.copyWith(props: {...node.props, ...props});
    notifyListeners();
  }

  /// Delete a component and its entire subtree.
  void deleteComponent(String id) {
    // Remove from parent's children list
    for (final entry in _nodeMap.entries) {
      if (entry.value.children.contains(id)) {
        final newChildren = List<String>.from(entry.value.children)..remove(id);
        _nodeMap[entry.key] = entry.value.copyWith(children: newChildren);
        break;
      }
    }
    _removeSubtree(id);
    notifyListeners();
  }

  /// Insert a widget subtree (flat ComponentNode list, root first) into a parent.
  /// Node IDs must already be unique (server applies keyPrefix before sending).
  void addComponent(
    String parentId,
    List<ComponentNode> components, {
    int? position,
  }) {
    if (components.isEmpty) return;
    final parent = _nodeMap[parentId];
    if (parent == null) return;

    // Add all nodes to the map
    for (final node in components) {
      _nodeMap[node.id] = node;
    }

    // Insert the subtree root into the parent's children
    final rootId = components.first.id;
    final newChildren = List<String>.from(parent.children);
    if (position != null && position <= newChildren.length) {
      newChildren.insert(position, rootId);
    } else {
      newChildren.add(rootId);
    }
    _nodeMap[parentId] = parent.copyWith(children: newChildren);
    notifyListeners();
  }

  /// Replace a component (and its subtree) with a new widget subtree.
  /// Node IDs must already be unique (server applies keyPrefix before sending).
  void replaceComponent(String targetId, List<ComponentNode> components) {
    if (components.isEmpty) return;

    // Find the parent and position of the target
    String? parentId;
    int? position;
    for (final entry in _nodeMap.entries) {
      final idx = entry.value.children.indexOf(targetId);
      if (idx != -1) {
        parentId = entry.key;
        position = idx;
        break;
      }
    }

    // Remove old subtree
    _removeSubtree(targetId);

    if (parentId != null) {
      // Add new nodes to map
      for (final node in components) {
        _nodeMap[node.id] = node;
      }

      // Update parent's children — swap target for new root
      final parent = _nodeMap[parentId]!;
      final newChildren = List<String>.from(parent.children)..remove(targetId);
      final rootId = components.first.id;
      if (position != null && position <= newChildren.length) {
        newChildren.insert(position, rootId);
      } else {
        newChildren.add(rootId);
      }
      _nodeMap[parentId] = parent.copyWith(children: newChildren);
    }
    notifyListeners();
  }

  void _removeSubtree(String id) {
    final node = _nodeMap.remove(id);
    if (node != null) {
      for (final childId in node.children) {
        _removeSubtree(childId);
      }
    }
  }
}
