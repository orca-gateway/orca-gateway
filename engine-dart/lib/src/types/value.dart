// ── Value Types ──────────────────────────────────────────────

const _valueKinds = {
  'static', 'state', 'info', 'request', 'event',
  'transform', 'conditional', 'tween', 'tweenSequence',
};

/// Check whether a dynamic value (typically from JSON) is a Value object.
/// Works on raw Map<String, dynamic>, not just typed Value instances.
bool isValue(dynamic v) {
  if (v is! Map) return false;
  final type = v['type'];
  return type is String && _valueKinds.contains(type);
}

// ── V.* Helper Constructors ─────────────────────────────────

abstract final class V {
  static Map<String, dynamic> static$(dynamic value) =>
      {'type': 'static', 'value': value};

  static Map<String, dynamic> pageState(String key) =>
      {'type': 'state', 'key': key, 'scope': 'page'};

  static Map<String, dynamic> appState(String key) =>
      {'type': 'state', 'key': key, 'scope': 'app'};

  static Map<String, dynamic> info(String key) =>
      {'type': 'info', 'key': key};

  static Map<String, dynamic> request(String key) =>
      {'type': 'request', 'key': key};

  static Map<String, dynamic> event(String key) =>
      {'type': 'event', 'key': key};

  static Map<String, dynamic> transform(
    Map<String, dynamic> input,
    List<Map<String, dynamic>> by,
  ) =>
      {'type': 'transform', 'input': input, 'by': by};

  static Map<String, dynamic> when(
    List<Map<String, dynamic>> branches, [
    Map<String, dynamic>? elseValue,
  ]) {
    final v = <String, dynamic>{'type': 'conditional', 'branches': branches};
    if (elseValue != null) v['else'] = elseValue;
    return v;
  }

  static Map<String, dynamic> tween(
    dynamic begin,
    dynamic end, [
    String? animationId,
  ]) {
    final v = <String, dynamic>{'type': 'tween', 'begin': begin, 'end': end};
    if (animationId != null) v['animationId'] = animationId;
    return v;
  }

  static Map<String, dynamic> tweenSequence(
    List<Map<String, dynamic>> items, [
    String? animationId,
  ]) {
    final v = <String, dynamic>{'type': 'tweenSequence', 'items': items};
    if (animationId != null) v['animationId'] = animationId;
    return v;
  }

  /// Recursively extract all state watch keys from a Value tree.
  static List<String> extractWatches(dynamic value) {
    final keys = <String>{};
    collectWatches(value, keys);
    return keys.toList();
  }
}

// ── Watch Collection ─────────────────────────────────────────

void collectWatches(dynamic value, Set<String> keys) {
  if (value is! Map) return;
  switch (value['type']) {
    case 'static':
    case 'info':
    case 'request':
    case 'event':
    case 'tween':
    case 'tweenSequence':
      break;
    case 'state':
      final key = value['key'];
      if (key is String) keys.add(key);
      break;
    case 'transform':
      collectWatches(value['input'], keys);
      final by = value['by'];
      if (by is List) {
        for (final t in by) {
          collectTransformWatches(t, keys);
        }
      }
      break;
    case 'conditional':
      final branches = value['branches'];
      if (branches is List) {
        for (final branch in branches) {
          if (branch is Map) {
            collectExprWatches(branch['when'], keys);
            collectWatches(branch['then'], keys);
          }
        }
      }
      final elseValue = value['else'];
      if (elseValue != null) collectWatches(elseValue, keys);
      break;
  }
}

void collectTransformWatches(dynamic t, Set<String> keys) {
  if (t is! Map) return;
  switch (t['type']) {
    case 'multiply':
    case 'divide':
    case 'add':
    case 'subtract':
    case 'modulo':
      collectWatches(t['by'], keys);
      break;
    case 'contains':
      collectWatches(t['value'], keys);
      break;
    case 'filter':
      collectExprWatches(t['expr'], keys);
      break;
    case 'template':
    case 'regex':
      // Named params may reference page/app state — without this, a watch
      // buried in a template param wouldn't trigger the SDK's WatchBuilder.
      final params = t['params'];
      if (params is Map) {
        for (final v in params.values) {
          collectWatches(v, keys);
        }
      }
      break;
  }
}

void collectExprWatches(dynamic expr, Set<String> keys) {
  if (expr is! Map) return;
  switch (expr['op']) {
    case 'eq':
    case 'neq':
    case 'gt':
    case 'gte':
    case 'lt':
    case 'lte':
      collectWatches(expr['left'], keys);
      collectWatches(expr['right'], keys);
      break;
    case 'and':
    case 'or':
      final exprs = expr['exprs'];
      if (exprs is List) {
        for (final e in exprs) {
          collectExprWatches(e, keys);
        }
      }
      break;
    case 'not':
      collectExprWatches(expr['expr'], keys);
      break;
    case 'isNull':
      collectWatches(expr['value'], keys);
      break;
    case 'contains':
      collectWatches(expr['haystack'], keys);
      collectWatches(expr['needle'], keys);
      break;
    case 'startsWith':
      collectWatches(expr['str'], keys);
      collectWatches(expr['prefix'], keys);
      break;
    case 'matches':
      collectWatches(expr['str'], keys);
      break;
  }
}

// ── Expr.* Helper Constructors ──────────────────────────────

abstract final class Expr {
  static Map<String, dynamic> eq(dynamic left, dynamic right) =>
      {'op': 'eq', 'left': _ensureValue(left), 'right': _ensureValue(right)};

  static Map<String, dynamic> neq(dynamic left, dynamic right) =>
      {'op': 'neq', 'left': _ensureValue(left), 'right': _ensureValue(right)};

  static Map<String, dynamic> gt(dynamic left, dynamic right) =>
      {'op': 'gt', 'left': _ensureValue(left), 'right': _ensureValue(right)};

  static Map<String, dynamic> gte(dynamic left, dynamic right) =>
      {'op': 'gte', 'left': _ensureValue(left), 'right': _ensureValue(right)};

  static Map<String, dynamic> lt(dynamic left, dynamic right) =>
      {'op': 'lt', 'left': _ensureValue(left), 'right': _ensureValue(right)};

  static Map<String, dynamic> lte(dynamic left, dynamic right) =>
      {'op': 'lte', 'left': _ensureValue(left), 'right': _ensureValue(right)};

  static Map<String, dynamic> and(List<Map<String, dynamic>> exprs) =>
      {'op': 'and', 'exprs': exprs};

  static Map<String, dynamic> or(List<Map<String, dynamic>> exprs) =>
      {'op': 'or', 'exprs': exprs};

  static Map<String, dynamic> not(Map<String, dynamic> expr) =>
      {'op': 'not', 'expr': expr};

  static Map<String, dynamic> isNull(dynamic value) =>
      {'op': 'isNull', 'value': _ensureValue(value)};

  static Map<String, dynamic> contains(dynamic haystack, dynamic needle) =>
      {
        'op': 'contains',
        'haystack': _ensureValue(haystack),
        'needle': _ensureValue(needle),
      };

  static Map<String, dynamic> startsWith(dynamic str, dynamic prefix) =>
      {
        'op': 'startsWith',
        'str': _ensureValue(str),
        'prefix': _ensureValue(prefix),
      };

  static Map<String, dynamic> matches(dynamic str, String regex) =>
      {'op': 'matches', 'str': _ensureValue(str), 'regex': regex};
}

dynamic _ensureValue(dynamic v) => isValue(v) ? v : V.static$(v);

// ── TV: Transform Value Helpers ─────────────────────────────

abstract final class TV {
  // String
  static Map<String, dynamic> toString$() => {'type': 'toString'};
  static Map<String, dynamic> toUpperCase() => {'type': 'toUpperCase'};
  static Map<String, dynamic> toLowerCase() => {'type': 'toLowerCase'};
  static Map<String, dynamic> trim() => {'type': 'trim'};
  static Map<String, dynamic> template(
    String template, [
    Map<String, dynamic>? params,
  ]) {
    final m = <String, dynamic>{'type': 'template', 'template': template};
    if (params != null && params.isNotEmpty) m['params'] = params;
    return m;
  }
  static Map<String, dynamic> regex(
    String pattern, [
    String? flags,
    String? replacement,
    Map<String, dynamic>? params,
  ]) {
    final m = <String, dynamic>{'type': 'regex', 'pattern': pattern};
    if (flags != null) m['flags'] = flags;
    if (replacement != null) m['replacement'] = replacement;
    if (params != null && params.isNotEmpty) m['params'] = params;
    return m;
  }

  static Map<String, dynamic> substring(int start, [int? length]) {
    final m = <String, dynamic>{'type': 'substring', 'start': start};
    if (length != null) m['length'] = length;
    return m;
  }

  static Map<String, dynamic> split(String separator) =>
      {'type': 'split', 'separator': separator};
  static Map<String, dynamic> join(String separator) =>
      {'type': 'join', 'separator': separator};

  // Number
  static Map<String, dynamic> multiply(dynamic by) =>
      {'type': 'multiply', 'by': _ensureValue(by)};
  static Map<String, dynamic> divide(dynamic by) =>
      {'type': 'divide', 'by': _ensureValue(by)};
  static Map<String, dynamic> add(dynamic by) =>
      {'type': 'add', 'by': _ensureValue(by)};
  static Map<String, dynamic> subtract(dynamic by) =>
      {'type': 'subtract', 'by': _ensureValue(by)};
  static Map<String, dynamic> modulo(dynamic by) =>
      {'type': 'modulo', 'by': _ensureValue(by)};
  static Map<String, dynamic> round() => {'type': 'round'};
  static Map<String, dynamic> floor() => {'type': 'floor'};
  static Map<String, dynamic> ceil() => {'type': 'ceil'};
  static Map<String, dynamic> abs() => {'type': 'abs'};
  static Map<String, dynamic> toFixed(int decimals) =>
      {'type': 'toFixed', 'decimals': decimals};

  // Boolean
  static Map<String, dynamic> not() => {'type': 'not'};
  static Map<String, dynamic> toBool() => {'type': 'toBool'};

  // Collection
  static Map<String, dynamic> length() => {'type': 'length'};
  static Map<String, dynamic> at(int index) => {'type': 'at', 'index': index};
  static Map<String, dynamic> first() => {'type': 'first'};
  static Map<String, dynamic> last() => {'type': 'last'};
  static Map<String, dynamic> map(Map<String, dynamic> transform) =>
      {'type': 'map', 'transform': transform};
  static Map<String, dynamic> filter(Map<String, dynamic> expr) =>
      {'type': 'filter', 'expr': expr};
  static Map<String, dynamic> contains(dynamic value) =>
      {'type': 'contains', 'value': _ensureValue(value)};

  // Format
  static Map<String, dynamic> formatCurrency(String currency,
      [int? decimals]) {
    final m = <String, dynamic>{
      'type': 'formatCurrency',
      'currency': currency,
    };
    if (decimals != null) m['decimals'] = decimals;
    return m;
  }

  static Map<String, dynamic> formatDate(String format) =>
      {'type': 'formatDate', 'format': format};

  static Map<String, dynamic> formatNumber([int? decimals, bool? useGrouping]) {
    final m = <String, dynamic>{'type': 'formatNumber'};
    if (decimals != null) m['decimals'] = decimals;
    if (useGrouping != null) m['useGrouping'] = useGrouping;
    return m;
  }
}
