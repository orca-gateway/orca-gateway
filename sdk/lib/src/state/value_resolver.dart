import 'animation_registry.dart';

const int _maxRegexPatternLength = 200;
const int _maxRegexInputLength = 10000;

/// Resolves value expressions from the server wire format.
///
/// Supports:
/// - Literals (string, num, bool, null)
/// - `{ "type": "static", "value": <any> }`
/// - `{ "type": "state", "key": "count", "scope": "page" }`
/// - `{ "type": "transform", "input": <value>, "by": [<operation>, ...] }`
///
/// Transform operations are pluggable via [PipeTransformRegistry].

class ValueResolver {
  final Map<String, dynamic> state;
  final PipeTransformRegistry transforms;

  /// Animation progress (0.0–1.0) for resolving tween values.
  /// Null when not inside an AnimatedBuilder context.
  final double? animationProgress;

  /// Registry for looking up targeted animation progress by animationId.
  final AnimationRegistry? animationRegistry;

  /// Event data from the trigger that fired the current action (e.g. onChange value).
  /// Null when no event context is active.
  final Map<String, dynamic>? eventData;

  /// When non-null, transform steps are recorded here for debugging.
  List<TransformTrace>? _activeTrace;

  ValueResolver({
    required this.state,
    PipeTransformRegistry? transforms,
    this.animationProgress,
    this.animationRegistry,
    this.eventData,
  }) : transforms = transforms ?? (PipeTransformRegistry()..registerDefaults());

  /// Resolve any value expression to a concrete value.
  dynamic resolve(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is! Map) return value;

    final map = value as Map<String, dynamic>;
    final type = map['type'] as String?;

    return switch (type) {
      'static' => map['value'],
      'state' => _resolveState(map),
      'event' => _resolveEvent(map),
      'transform' => _resolveTransform(map),
      'conditional' => _resolveConditional(map),
      'tween' => _resolveTween(map),
      'tweenSequence' => _resolveTweenSequence(map),
      _ => value,
    };
  }

  /// Resolve and convert to String (for display in Text widgets, etc.).
  String resolveToString(dynamic value) {
    final resolved = resolve(value);
    if (resolved == null) return '';
    return '$resolved';
  }

  dynamic _resolveState(Map<String, dynamic> map) {
    final key = map['key'] as String?;
    if (key == null) return null;
    final value = state[key];
    _activeTrace?.add(TransformTrace(operation: 'state', input: key, output: value, definition: map));
    return value;
  }

  dynamic _resolveEvent(Map<String, dynamic> map) {
    final key = map['key'] as String?;
    if (key == null || eventData == null) return null;
    final value = eventData![key];
    _activeTrace?.add(TransformTrace(operation: 'event', input: key, output: value, definition: map));
    return value;
  }

  dynamic _resolveConditional(Map<String, dynamic> map) {
    final branches = map['branches'] as List?;
    if (branches != null) {
      for (final branch in branches) {
        if (branch is! Map) continue;
        final branchMap = branch as Map<String, dynamic>;
        final when = branchMap['when'] as Map<String, dynamic>?;
        if (when != null && evaluateBoolExpr(when)) {
          return resolve(branchMap['then']);
        }
      }
    }
    final elseValue = map['else'];
    return elseValue != null ? resolve(elseValue) : null;
  }

  /// Evaluate a boolean expression from the wire format.
  bool evaluateBoolExpr(Map<String, dynamic> expr) {
    final op = expr['op'] as String?;
    if (op == null) return false;

    switch (op) {
      case 'eq':
        return resolve(expr['left']) == resolve(expr['right']);
      case 'neq':
        return resolve(expr['left']) != resolve(expr['right']);
      case 'gt':
        return _compareNum(expr['left'], expr['right']) > 0;
      case 'gte':
        return _compareNum(expr['left'], expr['right']) >= 0;
      case 'lt':
        return _compareNum(expr['left'], expr['right']) < 0;
      case 'lte':
        return _compareNum(expr['left'], expr['right']) <= 0;
      case 'and':
        final andExprs = expr['exprs'] as List? ?? [];
        return andExprs.every((e) =>
            e is Map<String, dynamic> && evaluateBoolExpr(e));
      case 'or':
        final orExprs = expr['exprs'] as List? ?? [];
        return orExprs.any((e) =>
            e is Map<String, dynamic> && evaluateBoolExpr(e));
      case 'not':
        final inner = expr['expr'] as Map<String, dynamic>?;
        return inner != null ? !evaluateBoolExpr(inner) : true;
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
        return '${ resolve(expr['str']) }'.startsWith('${ resolve(expr['prefix']) }');
      case 'matches':
        final regex = expr['regex'] as String? ?? '';
        if (regex.length > _maxRegexPatternLength) return false;
        try {
          final input = '${ resolve(expr['str']) }';
          final safeInput = input.length > _maxRegexInputLength
              ? input.substring(0, _maxRegexInputLength)
              : input;
          return RegExp(regex).hasMatch(safeInput);
        } catch (_) {
          return false;
        }
      default:
        return false;
    }
  }

  int _compareNum(dynamic left, dynamic right) {
    final l = resolve(left);
    final r = resolve(right);
    if (l is num && r is num) return l.compareTo(r);
    return 0;
  }

  dynamic _resolveTransform(Map<String, dynamic> map) {
    var current = resolve(map['input']);

    final pipeline = map['by'] as List?;
    if (pipeline == null) return current;

    _activeTrace?.add(TransformTrace(operation: 'input', input: null, output: current, definition: map['input']));

    for (final step in pipeline) {
      if (step is! Map) continue;
      final stepMap = step as Map<String, dynamic>;
      final opType = stepMap['type'] as String?;
      if (opType == null) continue;

      final op = transforms.get(opType);
      if (op == null) continue;
      final prev = current;
      current = op(stepMap, current, this);
      _activeTrace?.add(TransformTrace(operation: opType, input: prev, output: current, definition: stepMap));
    }

    return current;
  }

  /// Resolve the animation progress for a tween, checking for a targeted
  /// [animationId] first, falling back to the enclosing [animationProgress].
  double _progressFor(Map<String, dynamic> map) {
    final targetId = map['animationId'] as String?;
    if (targetId != null && animationRegistry != null) {
      return animationRegistry!.getProgress(targetId) ?? 0.0;
    }
    return animationProgress ?? 0.0;
  }

  dynamic _resolveTween(Map<String, dynamic> map) {
    final t = _progressFor(map);
    final begin = map['begin'];
    final end = map['end'];

    if (begin is num && end is num) {
      return begin + (end - begin) * t;
    }

    if (begin is String && end is String &&
        begin.startsWith('#') && end.startsWith('#')) {
      return _lerpColor(begin, end, t);
    }

    return t < 0.5 ? begin : end;
  }

  dynamic _resolveTweenSequence(Map<String, dynamic> map) {
    final t = _progressFor(map);
    final items = map['items'] as List?;
    if (items == null || items.isEmpty) return null;

    // Calculate total duration from items (skipping duration-0 keyframes).
    double totalDuration = 0;
    for (final item in items) {
      if (item is Map) {
        totalDuration += ((item['duration'] as num?) ?? 0).toDouble();
      }
    }
    if (totalDuration <= 0) {
      return (items.first as Map)['value'];
    }

    final currentTime = t * totalDuration;
    double elapsed = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i] as Map;
      final duration = ((item['duration'] as num?) ?? 0).toDouble();
      final value = item['value'];

      if (duration <= 0) continue;

      if (currentTime <= elapsed + duration) {
        final segmentProgress = (currentTime - elapsed) / duration;
        final prevValue = i > 0 ? (items[i - 1] as Map)['value'] : value;

        if (prevValue is num && value is num) {
          return prevValue + (value - prevValue) * segmentProgress;
        }
        if (prevValue is String && value is String &&
            prevValue.startsWith('#') && value.startsWith('#')) {
          return _lerpColor(prevValue, value, segmentProgress);
        }
        return segmentProgress < 0.5 ? prevValue : value;
      }
      elapsed += duration;
    }

    return (items.last as Map)['value'];
  }

  static String _lerpColor(String hexA, String hexB, double t) {
    int parseHex(String hex) {
      final h = hex.substring(1);
      if (h.length == 6) return int.parse('FF$h', radix: 16);
      if (h.length == 8) return int.parse(h, radix: 16);
      return 0xFF000000;
    }

    int lerpChannel(int a, int b, double t) =>
        (a + (b - a) * t).round().clamp(0, 255);

    final a = parseHex(hexA);
    final b = parseHex(hexB);

    final alpha = lerpChannel((a >> 24) & 0xFF, (b >> 24) & 0xFF, t);
    final red   = lerpChannel((a >> 16) & 0xFF, (b >> 16) & 0xFF, t);
    final green = lerpChannel((a >> 8)  & 0xFF, (b >> 8)  & 0xFF, t);
    final blue  = lerpChannel(a & 0xFF, b & 0xFF, t);

    final value = (alpha << 24) | (red << 16) | (green << 8) | blue;
    return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// Recursively resolve all Value objects nested within maps and lists.
  /// Used by AnimatedBuilder contexts so that tween values inside nested
  /// structures (e.g. `style: { fontSize: V.Tween(16, 24) }`) are resolved
  /// before builder helpers like `parseTextStyle` see them.
  dynamic resolveDeep(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (value is List) {
      return value.map((item) => resolveDeep(item)).toList();
    }

    if (value is! Map) return value;

    final map = value as Map<String, dynamic>;
    final type = map['type'] as String?;

    if (type != null && _isValueType(type)) {
      return resolve(map);
    }

    // Plain data map — recursively resolve nested values.
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      result[entry.key] = resolveDeep(entry.value);
    }
    return result;
  }

  static bool _isValueType(String type) {
    return const {
      'static', 'state', 'info', 'request', 'event', 'transform',
      'conditional', 'tween', 'tweenSequence',
    }.contains(type);
  }

  /// Resolve a value while collecting transform step traces.
  /// Returns the resolved value and the list of transform steps.
  ///
  /// Not reentrant — must not be called while another [resolveWithTrace] is
  /// in progress on the same instance. Safe in Dart's single-threaded model
  /// as long as [resolve] remains synchronous.
  (dynamic value, List<TransformTrace> trace) resolveWithTrace(dynamic raw) {
    assert(_activeTrace == null, 'resolveWithTrace is not reentrant');
    _activeTrace = [];
    // Use resolveDeep so nested Values inside plain-data props (e.g.
    // `decoration.border.width: V.when(...)`) get resolved too. `resolve`
    // alone returns the raw map unchanged for plain-data containers, which
    // then crashes builder casts like `borderData['width'] as num?`.
    // `_activeTrace` stays sticky for the full walk, so any transform
    // pipelines reached via the recursion still populate the trace — no
    // observability lost by this change.
    final value = resolveDeep(raw);
    final trace = _activeTrace!;
    _activeTrace = null;
    return (value, trace);
  }
}

/// A single step in a transform pipeline, captured for debugging.
class TransformTrace {
  final String operation;
  final dynamic input;
  final dynamic output;
  final dynamic definition;

  TransformTrace({required this.operation, this.input, this.output, this.definition});

  Map<String, dynamic> toJson() => {
    'op': operation,
    if (input != null) 'in': '$input',
    'out': '$output',
  };
}

/// Signature for a pipeline transform operation.
///
/// Receives the operation definition, the current pipeline value,
/// and the [ValueResolver] (to resolve nested value expressions like `by`).
typedef PipeTransform = dynamic Function(
    Map<String, dynamic> definition, dynamic current, ValueResolver resolver);

/// Registry of pluggable pipeline transform operations.
class PipeTransformRegistry {
  final Map<String, PipeTransform> _transforms = {};

  PipeTransformRegistry();

  /// Look up a transform by type name.
  PipeTransform? get(String type) => _transforms[type];

  /// Register a named transform operation.
  void register(String type, PipeTransform transform) {
    _transforms[type] = transform;
  }

  /// Register the built-in transforms shipped with the SDK.
  void registerDefaults() {
    // Number transforms
    register('add', (def, current, resolver) {
      final by = resolver.resolve(def['by']);
      return ((current ?? 0) as num) + (by as num);
    });
    register('subtract', (def, current, resolver) {
      final by = resolver.resolve(def['by']);
      return ((current ?? 0) as num) - (by as num);
    });
    register('multiply', (def, current, resolver) {
      final by = resolver.resolve(def['by']);
      return ((current ?? 0) as num) * (by as num);
    });
    register('divide', (def, current, resolver) {
      final by = resolver.resolve(def['by']);
      return ((current ?? 0) as num) / (by as num);
    });
    register('modulo', (def, current, resolver) {
      final by = resolver.resolve(def['by']);
      return ((current ?? 0) as num) % (by as num);
    });
    register('round', (_, current, _) => (current as num).round());
    register('floor', (_, current, _) => (current as num).floor());
    register('ceil', (_, current, _) => (current as num).ceil());
    register('abs', (_, current, _) => (current as num).abs());
    register('toFixed', (def, current, _) {
      final decimals = (def['decimals'] as num?)?.toInt() ?? 2;
      return (current as num).toStringAsFixed(decimals);
    });

    // String transforms
    register('toString', (_, current, _) => '$current');
    register('toUpperCase', (_, current, _) => '$current'.toUpperCase());
    register('toLowerCase', (_, current, _) => '$current'.toLowerCase());
    register('trim', (_, current, _) => '$current'.trim());
    register('template', (def, current, resolver) {
      final template = def['template'] as String? ?? '';
      return _expandPlaceholders(
        template,
        current,
        def['params'] as Map?,
        resolver,
      );
    });
    // The engine (TS + Dart port) has always shipped a `regex` transform —
    // and the SDK has always *advertised* one in its capability vector — but
    // the actual Dart implementation was missing until now, so `TV.regex(...)`
    // silently no-op'd on the client. The feature we're adding to support
    // replacement is also the natural moment to close that gap.
    register('regex', (def, current, resolver) {
      final pattern = def['pattern'] as String? ?? '';
      if (pattern.length > _maxRegexPatternLength) return null;
      try {
        final inputStr = '${current ?? ''}';
        final safeInput = inputStr.length > _maxRegexInputLength
            ? inputStr.substring(0, _maxRegexInputLength)
            : inputStr;
        final flags = def['flags'] as String?;
        final re = RegExp(
          pattern,
          caseSensitive: flags == null || !flags.contains('i'),
          multiLine: flags != null && flags.contains('m'),
          dotAll: flags != null && flags.contains('s'),
          unicode: flags != null && flags.contains('u'),
        );
        final replacement = def['replacement'] as String?;
        // Match-only mode: preserve the same contract the server side has
        // always advertised (match[0] or null).
        if (replacement == null) {
          return re.firstMatch(safeInput)?.group(0);
        }
        final global = flags != null && flags.contains('g');
        final params = def['params'] as Map?;
        String expand(Match m) {
          final matched = m.group(0) ?? '';
          final backreffed = replacement.replaceAllMapped(
            RegExp(r'\$([1-9])'),
            (mm) {
              final idx = int.parse(mm.group(1)!) - 1;
              if (idx >= m.groupCount) return '';
              return m.group(idx + 1) ?? '';
            },
          );
          return _expandPlaceholders(backreffed, matched, params, resolver);
        }
        if (global) return safeInput.replaceAllMapped(re, expand);
        return safeInput.replaceFirstMapped(re, expand);
      } catch (_) {
        return null;
      }
    });
    register('substring', (def, current, _) {
      final s = '$current';
      final start = (def['start'] as num?)?.toInt() ?? 0;
      final length = (def['length'] as num?)?.toInt();
      return length != null ? s.substring(start, start + length) : s.substring(start);
    });
    register('split', (def, current, _) {
      final separator = def['separator'] as String? ?? '';
      return '$current'.split(separator);
    });
    register('join', (def, current, _) {
      final separator = def['separator'] as String? ?? '';
      if (current is List) return current.join(separator);
      return '$current';
    });

    // Boolean transforms
    register('not', (_, current, _) => !(current == true));
    register('toBool', (_, current, _) {
      if (current == null || current == false || current == 0 || current == '') {
        return false;
      }
      return true;
    });
    register('toggle', (_, current, _) => !((current ?? false) as bool));

    // Collection transforms
    register('length', (_, current, _) {
      if (current is List) return current.length;
      if (current is String) return current.length;
      return 0;
    });
    register('at', (def, current, _) {
      final index = (def['index'] as num?)?.toInt() ?? 0;
      if (current is List && index < current.length) return current[index];
      return null;
    });
    register('first', (_, current, _) {
      if (current is List && current.isNotEmpty) return current.first;
      return null;
    });
    register('last', (_, current, _) {
      if (current is List && current.isNotEmpty) return current.last;
      return null;
    });
    register('map', (def, current, resolver) {
      if (current is! List) return current;
      final transform = def['transform'] as Map<String, dynamic>?;
      if (transform == null) return current;
      final opType = transform['type'] as String?;
      if (opType == null) return current;
      final op = _transforms[opType];
      if (op == null) return current;
      return current.map((item) => op(transform, item, resolver)).toList();
    });
    register('filter', (def, current, resolver) {
      if (current is! List) return current;
      final expr = def['expr'] as Map<String, dynamic>?;
      if (expr == null) return current;
      return current.where((item) => resolver.evaluateBoolExpr(expr)).toList();
    });
    register('contains', (def, current, resolver) {
      final value = resolver.resolve(def['value']);
      if (current is List) return current.contains(value);
      if (current is String) return current.contains('$value');
      return false;
    });

    // Format transforms
    register('formatCurrency', (def, current, _) {
      final currency = def['currency'] as String? ?? 'USD';
      final decimals = (def['decimals'] as num?)?.toInt() ?? 2;
      final num value = (current ?? 0) as num;
      return '${_currencySymbol(currency)}${value.toStringAsFixed(decimals)}';
    });
    register('formatNumber', (def, current, _) {
      final decimals = (def['decimals'] as num?)?.toInt();
      final num value = (current ?? 0) as num;
      if (decimals != null) return value.toStringAsFixed(decimals);
      return '$value';
    });
  }

  static String _currencySymbol(String currency) {
    return switch (currency.toUpperCase()) {
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      _ => '$currency ',
    };
  }
}

/// Regex for the `{{name}}` placeholder syntax shared by the `template` and
/// `regex` (replace-mode) transforms. Identifier-only, no dot paths, byte-
/// for-byte with the TS + engine-dart implementations so all three resolve
/// the same template string to the same output.
final RegExp _placeholderRe =
    RegExp(r'\{\{\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\}\}');

/// Expand `{{value}}` (the previous pipeline output) and `{{<name>}}`
/// (resolved from [params]) placeholders in [template]. Unknown names render
/// as the empty string to avoid leaking braces into production UI.
String _expandPlaceholders(
  String template,
  dynamic currentValue,
  Map? params,
  ValueResolver resolver,
) {
  return template.replaceAllMapped(_placeholderRe, (m) {
    final name = m.group(1)!;
    if (name == 'value') return '${currentValue ?? ''}';
    if (params != null && params.containsKey(name)) {
      final resolved = resolver.resolve(params[name]);
      return resolved == null ? '' : '$resolved';
    }
    return '';
  });
}
