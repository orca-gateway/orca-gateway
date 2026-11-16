import 'dart:collection' show UnmodifiableMapView;
import 'package:flutter/foundation.dart';
import '../models/component_node.dart';
import 'sub_page_core.dart';

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

/// What one SubPage node has mounted. It belongs to the node, not to the
/// widget that draws it: the [ComponentStore] holds it under the node's id
/// for as long as the node is in the store, so a widget that is built anew
/// for the same node (a list scrolled it away and back, a parent re-keyed
/// it) finds the pages as they were and does not fetch.
class SubPageSlot {
  /// The pages mounted in the SubPage, oldest first.
  final SubPageMounts mounts;

  /// Whether the SubPage node was in the store when the slot was made. A
  /// slot of a node the store never had lives as long as its widget.
  final bool anchored;

  /// Location of the last fetch for the node's own `pageId` and `params`
  /// that came back, mounted or failed; null before the first.
  String? location;

  /// Counts the mounts that are not a join (see the widget's page keys).
  int generation = 0;

  SubPageSlot(String subPageKey, {this.anchored = false})
    : mounts = SubPageMounts(subPageKey);
}

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

  /// Unregister a SubPage update callback. With [callback], only when it is
  /// the one registered (another SubPage may have taken the id since).
  /// Returns whether a registration was removed.
  bool unregisterSubPage(String subPageId, [SubPageUpdateCallback? callback]) {
    if (callback != null && _subPageCallbacks[subPageId] != callback) {
      return false;
    }
    return _subPageCallbacks.remove(subPageId) != null;
  }

  /// Invoke the update callback for a SubPage. Returns false if not found.
  Future<bool> updateSubPage(
      String subPageId, String pageId, Map<String, dynamic>? params, String mode) async {
    final callback = _subPageCallbacks[subPageId];
    if (callback == null) return false;
    await callback(pageId, params, mode);
    return true;
  }

  /// What each SubPage node has mounted, keyed by the node's id.
  final Map<String, SubPageSlot> _subPageSlots = {};

  /// The slot of the SubPage node [subPageId]: the one it has, else a new
  /// one. It stays until the node leaves the store (S8).
  SubPageSlot subPageSlot(String subPageId) => _subPageSlots.putIfAbsent(
    subPageId,
    () => SubPageSlot(subPageId, anchored: _nodeMap.containsKey(subPageId)),
  );

  /// Called by a SubPage widget that goes away. While the SubPage node is in
  /// the store its pages stay mounted for the next widget of that node; a
  /// slot whose node is not there is unmounted. A [slot] that is no longer
  /// the node's (it was unmounted already) is left alone.
  void releaseSubPage(String subPageId, SubPageSlot slot) {
    if (!identical(_subPageSlots[subPageId], slot)) return;
    if (slot.anchored && _nodeMap.containsKey(subPageId)) return;
    _unmountSubPage(subPageId);
  }

  /// S8: forgets the SubPage [subPageId] and takes the nodes of its pages
  /// out of the store, with the SubPages nested in them.
  void _unmountSubPage(String subPageId) {
    final slot = _subPageSlots.remove(subPageId);
    final prefixes = <String>{
      ...?_subPagePrefixes.remove(subPageId),
      ...?slot?.mounts.prefixes,
    };
    removeSubPagePages(prefixes);
  }

  /// Unmounts every SubPage whose node the store had and has no more.
  void _unmountMissingSubPages() {
    for (final id in _subPageSlots.keys.toList()) {
      final slot = _subPageSlots[id];
      if (slot != null && slot.anchored && !_nodeMap.containsKey(id)) {
        _unmountSubPage(id);
      }
    }
  }

  /// Prefixes of the pages mounted in each SubPage, keyed by subPageId.
  final Map<String, List<String>> _subPagePrefixes = {};

  /// Prefix of every page mounted in a SubPage of this page, nested ones
  /// included: what `subPagePrefixOf` is asked with.
  Iterable<String> get subPagePrefixes =>
      _subPagePrefixes.values.expand((prefixes) => prefixes);

  /// Record the prefixes of the pages mounted in a SubPage (oldest first).
  /// An empty list forgets the SubPage.
  void setSubPagePrefixes(String subPageId, List<String> prefixes) {
    if (prefixes.isEmpty) {
      _subPagePrefixes.remove(subPageId);
    } else {
      _subPagePrefixes[subPageId] = List.of(prefixes);
    }
  }

  /// Put the merged nodes of a mounted sub-page into the store. They hang
  /// under no parent: the SubPage widget draws them from their root. Does not
  /// notify; the SubPage redraws itself.
  void putSubPageNodes(Iterable<ComponentNode> nodes) {
    for (final node in nodes) {
      _nodeMap[node.id] = node;
    }
  }

  /// Take the nodes with these ids out of the store; a SubPage among them
  /// is unmounted. Does not notify.
  void removeSubPageNodes(Iterable<String> ids) {
    for (final id in ids.toList()) {
      _nodeMap.remove(id);
      if (_subPageSlots.containsKey(id)) _unmountSubPage(id);
    }
  }

  /// Take every node of the pages mounted under [prefixes] out of the store:
  /// each node whose id starts with one of them, so the nodes added to a page
  /// after it was mounted go with it, and a SubPage among them is unmounted.
  /// Does not notify.
  void removeSubPagePages(Iterable<String> prefixes) {
    final gone = prefixes.toList();
    if (gone.isEmpty) return;
    _nodeMap.removeWhere((id, _) => gone.any(id.startsWith));
    for (final id in _subPageSlots.keys.toList()) {
      if (gone.any(id.startsWith)) _unmountSubPage(id);
    }
  }

  /// The node [id] and everything under it, the root first; empty when the
  /// node is not in the store.
  List<ComponentNode> subtree(String id) {
    final result = <ComponentNode>[];
    _collectSubtree(id, result);
    return result;
  }

  /// Initialize from a flat node list (as received from the server). The
  /// nodes of the sub-pages whose SubPage node is still there stay; a
  /// SubPage the new list no longer has is unmounted.
  void init(List<ComponentNode> nodes) {
    final prefixes = subPagePrefixes.toList();
    _nodeMap.removeWhere(
      (id, _) => !prefixes.any((prefix) => id.startsWith(prefix)),
    );
    for (final node in nodes) {
      _nodeMap[node.id] = node;
    }
    _rootId = nodes.isNotEmpty ? nodes.first.id : null;
    _unmountMissingSubPages();
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
    _unmountMissingSubPages();
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
    _unmountMissingSubPages();
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
