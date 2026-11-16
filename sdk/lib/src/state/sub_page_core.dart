/// The pure core of the SubPage widget and the updateSubPage action.
///
/// No Flutter, no I/O: JSON maps in, JSON maps out. The contract (S1 to S8)
/// and the normative table of rewritten fields are in
/// `schema/fixtures/subpage/README.md`; every function here is pinned by the
/// fixtures of that folder, and the Swift and Kotlin SDKs carry the same
/// functions one to one.
///
/// A page mounted in a SubPage lives in the host page's node store and page
/// state. What keeps the two apart is a prefix, put by [mergeSubPage] in front
/// of every id and every page-state key of the mounted page.
library;

import 'dart:convert';

/// The prefix of a page mounted in the SubPage whose node id is [subPageKey]:
/// `K:` for page 0, `K#j:` for the [join]-th joined page (from 1).
String subPagePrefix(String subPageKey, [int join = 0]) =>
    join == 0 ? '$subPageKey:' : '$subPageKey#$join:';

/// What [mergeSubPage] gives: the rewritten nodes, in the response's order
/// (the root first), and the state seeds (prefixed key to initial value).
class SubPageMerge {
  final List<Map<String, dynamic>> nodes;
  final Map<String, dynamic> state;
  const SubPageMerge(this.nodes, this.state);
}

/// Rewrites a page [response] (`components` and `state`) for mounting under
/// [prefix]: ids, children, slot props, page-state references and keys,
/// watches and node-addressing ids get the prefix; each page-scoped state
/// definition gives one seed. The response is not changed.
///
/// The response is a page response as `page-response.schema.json` has it:
/// `components` and `state` are there, and every node carries `props`,
/// `children` and `watches`.
SubPageMerge mergeSubPage(String prefix, Map<String, dynamic> response) {
  final nodes = <Map<String, dynamic>>[
    for (final node in response['components'] as List)
      _node(prefix, node as Map),
  ];
  final state = <String, dynamic>{};
  for (final def in response['state'] as List) {
    if (_isPage((def as Map)['scope'])) {
      state['$prefix${def['key']}'] = def['initial'];
    }
  }
  return SubPageMerge(nodes, state);
}

/// Rewrites a bare action list (what a server returns to a serverAction fired
/// inside the page mounted under [prefix]) by the rules [mergeSubPage] applies
/// to a node's actions. The list is not changed.
List<dynamic> rewriteSubPageActions(String prefix, List<dynamic> actions) => [
  for (final action in actions) _walk(prefix, action, true),
];

/// Where a sub-page is fetched: [path] on the normal page route and [query],
/// without its question mark, empty when no param is sent.
class SubPageRequest {
  final String path;
  final String query;
  const SubPageRequest(this.path, this.query);

  /// The path with its query: what is handed to the page fetch.
  String get location => query.isEmpty ? path : '$path?$query';
}

/// The fetch of [pageId] with the resolved [params]. The path is the page id
/// without its leading slashes, each segment between slashes percent-encoded
/// (so a `?` or a `#` in it stays in the path). The query: keys sorted by
/// code point, keys and values percent-encoded, null params left out.
SubPageRequest subPageRequest(String pageId, [Map<String, dynamic>? params]) {
  final keys = [
    for (final entry in (params ?? const <String, dynamic>{}).entries)
      if (entry.value != null) entry.key,
  ]..sort(_byCodePoint);
  final query = [
    for (final key in keys) '${_percent(key)}=${_percent(_text(params![key]))}',
  ].join('&');
  var start = 0;
  while (start < pageId.length && pageId[start] == '/') {
    start++;
  }
  final path = pageId.substring(start).split('/').map(_percent).join('/');
  return SubPageRequest(path, query);
}

/// The mounted page a node belongs to: the longest of [prefixes] that
/// [sourceId] starts with (an id equal to a prefix starts with it), or null
/// (a host node, an empty id, or no source).
String? subPagePrefixOf(Iterable<String> prefixes, String? sourceId) {
  if (sourceId == null) return null;
  String? best;
  for (final prefix in prefixes) {
    if (sourceId.startsWith(prefix) &&
        (best == null || prefix.length > best.length)) {
      best = prefix;
    }
  }
  return best;
}

/// The page state a serverAction posts when its source belongs to [prefix]
/// (see [subPagePrefixOf]): the keys under the prefix, with the prefix
/// removed. A null prefix posts the whole [pageState].
Map<String, dynamic> subPagePostedState(
  String? prefix,
  Map<String, dynamic> pageState,
) {
  if (prefix == null) return pageState;
  return {
    for (final entry in pageState.entries)
      if (entry.key.startsWith(prefix))
        entry.key.substring(prefix.length): entry.value,
  };
}

/// One page mounted in a SubPage.
class SubPageMounted {
  final String prefix;

  /// The merged nodes, the root first.
  final List<Map<String, dynamic>> nodes;
  const SubPageMounted(this.prefix, this.nodes);

  /// Id of the node to draw, null for a page without components.
  String? get rootId => nodes.isEmpty ? null : nodes.first['id'] as String;
}

/// What one [SubPageMounts.apply] asks of the host page, in this order: take
/// [removedNodeIds] out of the node store and [removedStateKeys] out of the
/// page state, then put [nodes] in the store and write [seeds].
class SubPageChange {
  /// Prefix of the page this step mounted.
  final String prefix;
  final List<Map<String, dynamic>> nodes;
  final Map<String, dynamic> seeds;
  final List<String> removedNodeIds;
  final List<String> removedStateKeys;
  const SubPageChange({
    required this.prefix,
    required this.nodes,
    required this.seeds,
    required this.removedNodeIds,
    required this.removedStateKeys,
  });
}

/// The pages mounted in one SubPage, oldest first.
class SubPageMounts {
  /// Id of the SubPage node in the host page's node store.
  final String subPageKey;
  final List<SubPageMounted> pages = [];
  int _joins = 0;

  SubPageMounts(this.subPageKey);

  /// Prefix of each mounted page, oldest first.
  List<String> get prefixes => [for (final page in pages) page.prefix];

  /// Root id of each mounted page that has one: the drawing order.
  List<String> get roots => [for (final page in pages) ?page.rootId];

  /// Id of every node this SubPage has in the host's node store.
  List<String> get nodeIds => [
    for (final page in pages)
      for (final node in page.nodes) node['id'] as String,
  ];

  /// Mounts a fetched [response]. Mode `join`, with a page already mounted,
  /// adds it after the others under the next `K#j:` prefix and removes
  /// nothing. Any other mode (the first load is a `replace`) removes every
  /// mounted page and every key of [pageStateKeys] under `K:` or
  /// `K#<digits>:`, and mounts the response as page 0.
  SubPageChange apply(
    String mode,
    Map<String, dynamic> response,
    Iterable<String> pageStateKeys,
  ) {
    final join = mode == 'join' && pages.isNotEmpty;
    final removedNodeIds = join ? const <String>[] : nodeIds;
    final removedStateKeys = join
        ? const <String>[]
        : pageStateKeys.where(_owns).toList();
    if (!join) {
      pages.clear();
      _joins = 0;
    }
    final prefix = subPagePrefix(subPageKey, join ? ++_joins : 0);
    final merged = mergeSubPage(prefix, response);
    pages.add(SubPageMounted(prefix, merged.nodes));
    return SubPageChange(
      prefix: prefix,
      nodes: merged.nodes,
      seeds: merged.state,
      removedNodeIds: removedNodeIds,
      removedStateKeys: removedStateKeys,
    );
  }

  /// Whether a page-state key is under `K:` or `K#<digits>:`.
  bool _owns(String key) {
    if (!key.startsWith(subPageKey)) return false;
    var i = subPageKey.length;
    if (i >= key.length) return false;
    if (key[i] == ':') return true;
    if (key[i] != '#') return false;
    final digits = ++i;
    while (i < key.length && _isDigit(key.codeUnitAt(i))) {
      i++;
    }
    return i > digits && i < key.length && key[i] == ':';
  }
}

// ── The rewrite ─────────────────────────────────────────────

bool _isPage(Object? scope) => scope == null || scope == 'page';

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

/// Props that name a page-state key or a node of the page as a plain string.
const _nodeProps = {'animationId', 'stateKey'};

/// Actions whose `key` is a state key in `scope`.
const _stateActions = {'setState', 'clearState', 'persistState'};

/// Per action kind, the field that holds the id of a node of the page.
const _idFields = <String, String>{
  'openDialog': 'dialogId',
  'animateForward': 'animationId',
  'animateReverse': 'animationId',
  'updateComponent': 'id',
  'deleteComponent': 'id',
  'addComponent': 'parentId',
  'replaceComponent': 'targetId',
  'updateSubPage': 'subPageId',
};

Map<String, dynamic> _node(String prefix, Map<dynamic, dynamic> node) {
  final out = Map<String, dynamic>.from(node);
  final children = List<String>.from(node['children'] as List);
  final props = node['props'] as Map;
  out['id'] = '$prefix${node['id']}';
  out['children'] = [for (final child in children) '$prefix$child'];
  out['props'] = _props(prefix, props, children);

  final pageKeys = <String>{};
  final appKeys = <String>{};
  _refs(props, pageKeys, appKeys);
  out['watches'] = [
    for (final watch in node['watches'] as List)
      if (pageKeys.contains(watch)) ...[
        '$prefix$watch',
        if (appKeys.contains(watch)) watch,
      ] else
        watch,
  ];
  if (node.containsKey('actions')) {
    out['actions'] = _walk(prefix, node['actions'], true);
  }
  return out;
}

/// A props map: a string that is one of the node's [children] is a slot, the
/// strings of [_nodeProps] name a key or a node; everything else is walked.
Map<String, dynamic> _props(
  String prefix,
  Map<dynamic, dynamic> props,
  List<String> children,
) => {
  for (final entry in props.entries)
    entry.key as String: switch (entry.value) {
      final String s
          when children.contains(s) || _nodeProps.contains(entry.key) =>
        '$prefix$s',
      final value => _walk(prefix, value, false),
    },
};

/// A static Value is data, whatever it holds and with or without a `value`.
bool _isStatic(Map<dynamic, dynamic> map) => map['type'] == 'static';

/// Deep copy of [value] with every page-state reference and every targeted
/// tween rewritten; with [actions], the action fields too.
dynamic _walk(String prefix, dynamic value, bool actions) {
  if (value is List) return [for (final v in value) _walk(prefix, v, actions)];
  if (value is! Map) return value;
  if (_isStatic(value)) return value;

  final type = value['type'];
  final out = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key as String;
    final v = entry.value;
    if (actions && type == 'updateComponent' && key == 'props' && v is Map) {
      out[key] = _props(prefix, v, const []);
    } else if (actions &&
        (type == 'addComponent' || type == 'replaceComponent') &&
        key == 'components' &&
        v is List) {
      out[key] = [for (final n in v) n is Map ? _node(prefix, n) : n];
    } else {
      out[key] = _walk(prefix, v, actions);
    }
  }

  void put(String field) {
    final v = out[field];
    if (v is String) out[field] = '$prefix$v';
  }

  if (type == 'state' && _isPage(value['scope'])) put('key');
  if (type == 'tween' || type == 'tweenSequence') put('animationId');
  if (actions) {
    if (_stateActions.contains(type) && _isPage(value['scope'])) put('key');
    final idField = _idFields[type];
    if (idField != null) put(idField);
  }
  return out;
}

/// Collects the keys of the state references under [value], by scope.
void _refs(dynamic value, Set<String> pageKeys, Set<String> appKeys) {
  if (value is List) {
    for (final v in value) {
      _refs(v, pageKeys, appKeys);
    }
  } else if (value is Map && !_isStatic(value)) {
    final key = value['key'];
    if (value['type'] == 'state' && key is String) {
      (_isPage(value['scope']) ? pageKeys : appKeys).add(key);
    }
    for (final v in value.values) {
      _refs(v, pageKeys, appKeys);
    }
  }
}

// ── The query string ────────────────────────────────────────

/// Code point order, which is the order of the UTF-8 bytes.
int _byCodePoint(String a, String b) {
  final x = a.runes.iterator;
  final y = b.runes.iterator;
  while (true) {
    final hasX = x.moveNext();
    final hasY = y.moveNext();
    if (!hasX || !hasY) return hasX ? 1 : (hasY ? -1 : 0);
    if (x.current != y.current) return x.current - y.current;
  }
}

const _unreserved =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

/// RFC 3986 percent-encoding of everything but the unreserved characters.
String _percent(String text) {
  final out = StringBuffer();
  for (final byte in utf8.encode(text)) {
    if (byte < 0x80 && _unreserved.contains(String.fromCharCode(byte))) {
      out.writeCharCode(byte);
    } else {
      out
        ..write('%')
        ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
  }
  return out.toString();
}

/// A resolved param as text: a string as it is, a list or a map as JSON.
String _text(Object? value) => value is String ? value : _json(value);

/// 2^53: up to it, either way, every whole number is exact in a double.
const _maxWhole = 9007199254740992.0;

/// A whole number up to 2^53 as its digits, however it was spelt (`3.0`,
/// `1e3`, `-0.0`); any other number as Dart prints it, which is the shortest
/// plain decimal that reads back the same from 0.0001 up to 2^53. Outside
/// that the forms differ between platforms and the contract pins none.
String _number(num n) =>
    n is double && n == n.truncateToDouble() && n.abs() <= _maxWhole
    ? n.toInt().toString()
    : n.toString();

/// Compact JSON with sorted keys, the same on every platform. [value] is a
/// decoded JSON value: null, a boolean, a number, a string, a list or a map.
String _json(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return _number(value);
  if (value is String) return _quoted(value);
  if (value is List) return '[${value.map(_json).join(',')}]';
  final map = value as Map;
  final keys = [for (final key in map.keys) key as String]..sort(_byCodePoint);
  return '{${keys.map((k) => '${_quoted(k)}:${_json(map[k])}').join(',')}}';
}

const _escapes = <int, String>{
  0x22: r'\"',
  0x5C: r'\\',
  0x08: r'\b',
  0x0C: r'\f',
  0x0A: r'\n',
  0x0D: r'\r',
  0x09: r'\t',
};

/// A JSON string: only the quote, the backslash and the control characters
/// are escaped.
String _quoted(String text) {
  final out = StringBuffer('"');
  for (final unit in text.codeUnits) {
    final escape = _escapes[unit];
    if (escape != null) {
      out.write(escape);
    } else if (unit < 0x20) {
      out.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
    } else {
      out.writeCharCode(unit);
    }
  }
  out.write('"');
  return out.toString();
}
