import '../types/context.dart';
import '../types/value.dart';

const _maxRegexPatternLength = 200;
const _maxRegexInputLength = 10000;

// ── Value Resolver (Server-Side) ───────────────────────────
//
// Resolves Values that are static from the client's perspective:
//   V.static, V.info, V.request → resolved to plain values
//
// Values that reference client-side state are left as Value objects
// so the SDK can re-resolve them when state changes:
//   V.pageState, V.appState, V.transform(V.pageState(...), [...])

class ValueResolver {
  final ValueResolverContext ctx;

  ValueResolver(this.ctx);

  /// Resolve a Value to its concrete value. Non-Value inputs pass through.
  dynamic resolve(dynamic value) {
    if (!isValue(value)) return value;

    final type = (value as Map)['type'] as String;
    switch (type) {
      case 'static':
        return value['value'];
      case 'state':
        return value['scope'] == 'page'
            ? getByDotPath(ctx.pageState, value['key'] as String)
            : getByDotPath(ctx.appState, value['key'] as String);
      case 'info':
        return getByDotPath(ctx.infoData, value['key'] as String);
      case 'request':
        return getByDotPath(ctx.requestInfo, value['key'] as String);
      case 'event':
      case 'tween':
      case 'tweenSequence':
        return value; // Client-side constructs — return as-is.
      case 'transform':
        return _resolveTransform(
          resolve(value['input']),
          value['by'] as List,
        );
      case 'conditional':
        return _resolveConditional(value);
      default:
        return value;
    }
  }

  /// Recursively resolve all Value objects in a props record.
  Map<String, dynamic> resolveProps(Map<String, dynamic> props) {
    final resolved = <String, dynamic>{};
    for (final entry in props.entries) {
      resolved[entry.key] = resolveDeep(entry.value);
    }
    return resolved;
  }

  // ── Transform pipeline ────────────────────────────────

  dynamic _resolveTransform(dynamic input, List transforms) {
    dynamic current = input;
    for (final t in transforms) {
      current = _applyTransform(current, t as Map);
    }
    return current;
  }

  dynamic _applyTransform(dynamic current, Map t) {
    final type = t['type'] as String;
    switch (type) {
      // ── String transforms ─────────────────────────────
      case 'toString':
        return '${current ?? ""}';
      case 'toUpperCase':
        return '$current'.toUpperCase();
      case 'toLowerCase':
        return '$current'.toLowerCase();
      case 'trim':
        return '$current'.trim();
      case 'template':
        return _expandPlaceholders(
          t['template'] as String,
          current,
          t['params'] as Map?,
        );
      case 'regex':
        final pattern = t['pattern'] as String;
        if (pattern.length > _maxRegexPatternLength) return null;
        try {
          final input = '$current';
          final truncated = input.length > _maxRegexInputLength
              ? input.substring(0, _maxRegexInputLength)
              : input;
          final flags = t['flags'] as String?;
          final caseSensitive = flags == null || !flags.contains('i');
          final multiLine = flags != null && flags.contains('m');
          final dotAll = flags != null && flags.contains('s');
          final unicode = flags != null && flags.contains('u');
          final re = RegExp(
            pattern,
            caseSensitive: caseSensitive,
            multiLine: multiLine,
            dotAll: dotAll,
            unicode: unicode,
          );
          final replacement = t['replacement'] as String?;
          // Match-only mode: preserve pre-existing behavior.
          if (replacement == null) {
            return re.firstMatch(truncated)?.group(0);
          }
          // Replace mode: `g` flag → all matches, else first-only (mirrors JS
          // String.replace and the TS engine).
          final global = flags != null && flags.contains('g');
          final params = t['params'] as Map?;
          String expand(Match m) {
            final matched = m.group(0) ?? '';
            // Native `$1..$9` backref substitution first…
            final backreffed = replacement.replaceAllMapped(
              RegExp(r'\$([1-9])'),
              (mm) {
                final idx = int.parse(mm.group(1)!) - 1;
                if (idx >= m.groupCount) return '';
                return m.group(idx + 1) ?? '';
              },
            );
            // …then {{value}} / {{name}} expansion, same helper as template.
            return _expandPlaceholders(backreffed, matched, params);
          }
          if (global) {
            return truncated.replaceAllMapped(re, expand);
          }
          return truncated.replaceFirstMapped(re, expand);
        } catch (_) {
          return null;
        }
      case 'substring':
        final s = '$current';
        final start = _toInt(t['start']);
        final length = t['length'] != null ? _toInt(t['length']) : null;
        final end = length != null ? start + length : null;
        if (start >= s.length) return '';
        return s.substring(start, end != null && end < s.length ? end : null);
      case 'split':
        return '$current'.split(t['separator'] as String);
      case 'join':
        if (current is List) return current.join(t['separator'] as String);
        return '$current';

      // ── Number transforms ─────────────────────────────
      case 'add':
        return _toNum(current) + _toNum(resolve(t['by']));
      case 'subtract':
        return _toNum(current) - _toNum(resolve(t['by']));
      case 'multiply':
        return _toNum(current) * _toNum(resolve(t['by']));
      case 'divide':
        return _toNum(current) / _toNum(resolve(t['by']));
      case 'modulo':
        return _toNum(current) % _toNum(resolve(t['by']));
      case 'round':
        return _toNum(current).round();
      case 'floor':
        return _toNum(current).floor();
      case 'ceil':
        return _toNum(current).ceil();
      case 'abs':
        return _toNum(current).abs();
      case 'toFixed':
        return _toNum(current).toStringAsFixed(_toInt(t['decimals']));

      // ── Boolean transforms ────────────────────────────
      case 'not':
        return !_toBool(current);
      case 'toBool':
        return _toBool(current);

      // ── Collection transforms ─────────────────────────
      case 'length':
        if (current is List) return current.length;
        if (current is String) return current.length;
        return 0;
      case 'at':
        if (current is List) {
          final idx = _toInt(t['index']);
          return idx >= 0 && idx < current.length ? current[idx] : null;
        }
        return null;
      case 'first':
        if (current is List && current.isNotEmpty) return current.first;
        return null;
      case 'last':
        if (current is List && current.isNotEmpty) return current.last;
        return null;
      case 'map':
        if (current is List) {
          return current
              .map((item) => _applyTransform(item, t['transform'] as Map))
              .toList();
        }
        return current;
      case 'filter':
        if (current is List) {
          return current
              .where((item) => evaluateBoolExpr(t['expr'], item))
              .toList();
        }
        return current;
      case 'contains':
        final needle = resolve(t['value']);
        if (current is List) return current.contains(needle);
        if (current is String) return current.contains('$needle');
        return false;

      // ── Format transforms ─────────────────────────────
      case 'formatCurrency':
        final num = _toNum(current);
        final decimals = t['decimals'] as int? ?? 2;
        final currency = t['currency'] as String;
        // Match JS Intl.NumberFormat currency output: symbol + formatted number
        return _formatCurrency(num, currency, decimals);
      case 'formatDate':
        final date = current is DateTime
            ? current
            : DateTime.tryParse('$current') ?? DateTime.now();
        return _formatDateString(date, t['format'] as String);
      case 'formatNumber':
        final num = _toNum(current);
        final decimals = t['decimals'] as int?;
        final useGrouping = t['useGrouping'] as bool? ?? true;
        return _formatNumber(num, decimals, useGrouping);

      default:
        return current;
    }
  }

  // ── Conditional resolution ───────────────────────────────

  dynamic _resolveConditional(Map value) {
    final branches = value['branches'] as List;
    for (final branch in branches) {
      if (branch is Map && evaluateBoolExpr(branch['when'])) {
        return resolve(branch['then']);
      }
    }
    final elseValue = value['else'];
    return elseValue != null ? resolve(elseValue) : null;
  }

  /// Evaluate a BoolExpr. Optional contextValue for filter expressions.
  bool evaluateBoolExpr(dynamic expr, [dynamic contextValue]) {
    if (expr is! Map) return false;
    final op = expr['op'] as String;
    switch (op) {
      case 'eq':
        return resolve(expr['left']) == resolve(expr['right']);
      case 'neq':
        return resolve(expr['left']) != resolve(expr['right']);
      case 'gt':
        return _toNum(resolve(expr['left'])) > _toNum(resolve(expr['right']));
      case 'gte':
        return _toNum(resolve(expr['left'])) >= _toNum(resolve(expr['right']));
      case 'lt':
        return _toNum(resolve(expr['left'])) < _toNum(resolve(expr['right']));
      case 'lte':
        return _toNum(resolve(expr['left'])) <= _toNum(resolve(expr['right']));
      case 'and':
        return (expr['exprs'] as List)
            .every((e) => evaluateBoolExpr(e, contextValue));
      case 'or':
        return (expr['exprs'] as List)
            .any((e) => evaluateBoolExpr(e, contextValue));
      case 'not':
        return !evaluateBoolExpr(expr['expr'], contextValue);
      case 'isNull':
        final val = resolve(expr['value']);
        return val == null;
      case 'contains':
        final haystack = resolve(expr['haystack']);
        final needle = resolve(expr['needle']);
        if (haystack is String) return haystack.contains('$needle');
        if (haystack is List) return haystack.contains(needle);
        return false;
      case 'startsWith':
        return '${resolve(expr['str'])}'
            .startsWith('${resolve(expr['prefix'])}');
      case 'matches':
        final regex = expr['regex'] as String;
        if (regex.length > _maxRegexPatternLength) return false;
        try {
          final input = '${resolve(expr['str'])}';
          final truncated = input.length > _maxRegexInputLength
              ? input.substring(0, _maxRegexInputLength)
              : input;
          return RegExp(regex).hasMatch(truncated);
        } catch (_) {
          return false;
        }
      default:
        return false;
    }
  }

  /// Shared placeholder expansion for the `template` and `regex` (replace-
  /// mode) transforms. `{{value}}` → [currentValue]; any other
  /// `{{identifier}}` → resolved [params] entry; unknown names → empty string.
  /// Identifier-only — no dot paths — matching the TS engine behavior byte
  /// for byte.
  static final RegExp _placeholderRe =
      RegExp(r'\{\{\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\}\}');

  String _expandPlaceholders(
    String template,
    dynamic currentValue,
    Map? params,
  ) {
    return template.replaceAllMapped(_placeholderRe, (m) {
      final name = m.group(1)!;
      if (name == 'value') return '${currentValue ?? ""}';
      if (params != null && params.containsKey(name)) {
        final resolved = resolve(params[name]);
        return resolved == null ? '' : '$resolved';
      }
      return '';
    });
  }

  /// Substitute {{requestInfo.X}} and {{config.X}} tokens.
  String interpolateTemplates(String s) {
    if (!s.contains('{{')) return s;
    final buf = StringBuffer();
    var i = 0;
    while (i < s.length) {
      if (i + 1 < s.length && s[i] == '{' && s[i + 1] == '{') {
        final end = s.indexOf('}}', i + 2);
        if (end == -1) {
          buf.write(s.substring(i));
          return buf.toString();
        }
        final path = s.substring(i + 2, end).trim();
        buf.write(_lookupTemplatePath(path));
        i = end + 2;
        continue;
      }
      buf.write(s[i]);
      i++;
    }
    return buf.toString();
  }

  String _lookupTemplatePath(String path) {
    if (path.startsWith('requestInfo.')) {
      final val = getByDotPath(ctx.requestInfo, path.substring('requestInfo.'.length));
      return val == null ? '' : '$val';
    }
    if (path.startsWith('config.')) {
      final val = getByDotPath(ctx.config, path.substring('config.'.length));
      return val == null ? '' : '$val';
    }
    return '{{$path}}';
  }

  /// Deep-resolve a value, handling nested objects, arrays, and template strings.
  dynamic resolveDeep(dynamic val) {
    if (val == null) return val;
    if (val is String) return interpolateTemplates(val);
    if (val is num || val is bool) return val;

    if (isValue(val)) {
      if (!_hasStateRefs(val)) {
        // No state refs → fully resolve to plain value
        return resolve(val);
      }
      // Has state refs → partially resolve
      return _partialResolve(val);
    }

    if (val is List) {
      return val.map(resolveDeep).toList();
    }

    if (val is Map) {
      final result = <String, dynamic>{};
      for (final entry in val.entries) {
        result['${entry.key}'] = resolveDeep(entry.value);
      }
      return result;
    }

    return val;
  }

  /// Partially resolve: replace server-only leaves with V.static(resolved)
  /// while keeping state refs intact for SDK-side resolution.
  dynamic _partialResolve(dynamic value) {
    if (value is! Map) return value;
    final type = value['type'] as String?;
    switch (type) {
      case 'static':
      case 'state':
      case 'event':
      case 'tween':
      case 'tweenSequence':
        return value;
      case 'info':
        return V.static$(getByDotPath(ctx.infoData, value['key'] as String));
      case 'request':
        return V.static$(getByDotPath(ctx.requestInfo, value['key'] as String));
      case 'transform':
        return {
          'type': 'transform',
          'input': _partialResolve(value['input']),
          'by': (value['by'] as List).map(_partialResolveTransform).toList(),
        };
      case 'conditional':
        final result = <String, dynamic>{
          'type': 'conditional',
          'branches': (value['branches'] as List).map((b) {
            if (b is! Map) return b;
            return {
              'when': _partialResolveBoolExpr(b['when']),
              'then': _partialResolve(b['then']),
            };
          }).toList(),
        };
        if (value['else'] != null) {
          result['else'] = _partialResolve(value['else']);
        }
        return result;
      default:
        return value;
    }
  }

  dynamic _partialResolveTransform(dynamic t) {
    if (t is! Map) return t;
    final type = t['type'] as String?;
    switch (type) {
      case 'multiply':
      case 'divide':
      case 'add':
      case 'subtract':
      case 'modulo':
        return {...t, 'by': _partialResolve(t['by'])};
      case 'contains':
        return {...t, 'value': _partialResolve(t['value'])};
      case 'filter':
        return {...t, 'expr': _partialResolveBoolExpr(t['expr'])};
      case 'template':
      case 'regex':
        // Params may contain state refs that must survive partial-resolve so
        // the SDK re-resolves them client-side. Without this, info/request
        // leaves inside params would leak to the SDK unresolved.
        final params = t['params'];
        if (params is! Map) return t;
        final resolved = <String, dynamic>{};
        params.forEach((k, v) {
          resolved[k as String] = _partialResolve(v);
        });
        return {...t, 'params': resolved};
      default:
        return t;
    }
  }

  dynamic _partialResolveBoolExpr(dynamic expr) {
    if (expr is! Map) return expr;
    final op = expr['op'] as String?;
    switch (op) {
      case 'eq':
      case 'neq':
      case 'gt':
      case 'gte':
      case 'lt':
      case 'lte':
        return {
          ...expr,
          'left': _partialResolve(expr['left']),
          'right': _partialResolve(expr['right']),
        };
      case 'and':
      case 'or':
        return {
          ...expr,
          'exprs':
              (expr['exprs'] as List).map(_partialResolveBoolExpr).toList(),
        };
      case 'not':
        return {...expr, 'expr': _partialResolveBoolExpr(expr['expr'])};
      case 'isNull':
        return {...expr, 'value': _partialResolve(expr['value'])};
      case 'contains':
        return {
          ...expr,
          'haystack': _partialResolve(expr['haystack']),
          'needle': _partialResolve(expr['needle']),
        };
      case 'startsWith':
        return {
          ...expr,
          'str': _partialResolve(expr['str']),
          'prefix': _partialResolve(expr['prefix']),
        };
      case 'matches':
        return {...expr, 'str': _partialResolve(expr['str'])};
      default:
        return expr;
    }
  }
}

// ── State reference detection ──────────────────────────────

bool _hasStateRefs(dynamic value) {
  return V.extractWatches(value).isNotEmpty || _containsEventRefs(value);
}

bool _containsEventRefs(dynamic value) {
  if (value is! Map) return false;
  switch (value['type']) {
    case 'event':
      return true;
    case 'transform':
      return _containsEventRefs(value['input']);
    case 'conditional':
      final branches = value['branches'];
      if (branches is List) {
        for (final b in branches) {
          if (b is Map && _containsEventRefs(b['then'])) return true;
        }
      }
      final elseValue = value['else'];
      return elseValue != null && _containsEventRefs(elseValue);
    default:
      return false;
  }
}

// ── Dot-path traversal ─────────────────────────────────────

/// Traverse an object/array by dot-delimited path. Numeric segments index arrays.
dynamic getByDotPath(dynamic obj, String path) {
  final segments = path.split('.');
  dynamic current = obj;

  for (final seg in segments) {
    if (current == null) return null;

    if (current is List) {
      final idx = int.tryParse(seg);
      if (idx == null || idx < 0 || idx >= current.length) return null;
      current = current[idx];
    } else if (current is Map) {
      current = current[seg];
    } else {
      return null;
    }
  }

  return current;
}

// ── Helpers ────────────────────────────────────────────────

num _toNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

bool _toBool(dynamic v) {
  if (v is bool) return v;
  if (v == null || v == 0 || v == '' || v == false) return false;
  return true;
}

// ── Date formatting ────────────────────────────────────────

String _formatDateString(DateTime date, String format) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return format
      .replaceAll('yyyy', '${date.year}')
      .replaceAll('MM', pad(date.month))
      .replaceAll('dd', pad(date.day))
      .replaceAll('HH', pad(date.hour))
      .replaceAll('mm', pad(date.minute))
      .replaceAll('ss', pad(date.second));
}

// ── Currency formatting ────────────────────────────────────

String _formatCurrency(num value, String currency, int decimals) {
  // Match JS Intl.NumberFormat: currency symbol prefix + formatted number
  // For simplicity, use currency code as prefix (same as JS with undefined locale
  // falling back to en-US style).
  final formatted = value.toStringAsFixed(decimals);
  // Add grouping separators
  final parts = formatted.split('.');
  final intPart = _addGrouping(parts[0]);
  final result = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  return '$currency\u00A0$result'; // non-breaking space like Intl
}

String _formatNumber(num value, int? decimals, bool useGrouping) {
  final formatted =
      decimals != null ? value.toStringAsFixed(decimals) : '$value';
  if (!useGrouping) return formatted;
  final parts = formatted.split('.');
  final intPart = _addGrouping(parts[0]);
  return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
}

String _addGrouping(String intPart) {
  final negative = intPart.startsWith('-');
  final digits = negative ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return negative ? '-${buf.toString()}' : buf.toString();
}
