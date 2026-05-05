/// Style & value helpers — Dart mirror of
/// `open-source/engine/src/components/helpers/*`.
///
/// The TS engine exposes these as typed interfaces (`TextStyleData`,
/// `BoxDecorationData`, …) plus convenience builders (`TextStyle(...)`,
/// `BoxDecoration(...)`, `EdgeInsets.all(...)`, `Color("#...")`). Dart
/// authors need the same ergonomics when building server-side widgets, so
/// every helper here produces the same wire-level JSON shape as the TS
/// version.
///
/// The generated widget constructors take `dynamic` for value props so they
/// can accept either a literal, a `V.*` map, or one of the `Map<String,
/// dynamic>` payloads built by the helpers below.
library;

// ── Enum-like string constants ──────────────────────────────
//
// The TS engine uses string-literal unions (e.g.
// `"start" | "end" | "center" | ...`). Dart has no structural type for
// that, so we expose each literal as a `static const String` on a holder
// class. Authors still get autocomplete and a central place to find the
// allowed values; misspellings fail loudly on the client.

abstract final class Alignment {
  static const String topLeft = 'topLeft';
  static const String topCenter = 'topCenter';
  static const String topRight = 'topRight';
  static const String centerLeft = 'centerLeft';
  static const String center = 'center';
  static const String centerRight = 'centerRight';
  static const String bottomLeft = 'bottomLeft';
  static const String bottomCenter = 'bottomCenter';
  static const String bottomRight = 'bottomRight';
}

abstract final class Axis {
  static const String horizontal = 'horizontal';
  static const String vertical = 'vertical';
}

abstract final class MainAxisAlignment {
  static const String start = 'start';
  static const String end = 'end';
  static const String center = 'center';
  static const String spaceBetween = 'spaceBetween';
  static const String spaceAround = 'spaceAround';
  static const String spaceEvenly = 'spaceEvenly';
}

abstract final class CrossAxisAlignment {
  static const String start = 'start';
  static const String end = 'end';
  static const String center = 'center';
  static const String stretch = 'stretch';
  static const String baseline = 'baseline';
}

abstract final class MainAxisSize {
  static const String min = 'min';
  static const String max = 'max';
}

abstract final class StackFit {
  static const String loose = 'loose';
  static const String expand = 'expand';
  static const String passthrough = 'passthrough';
}

abstract final class ImageFit {
  static const String fill = 'fill';
  static const String contain = 'contain';
  static const String cover = 'cover';
  static const String fitWidth = 'fitWidth';
  static const String fitHeight = 'fitHeight';
  static const String none = 'none';
  static const String scaleDown = 'scaleDown';
}

abstract final class InputType {
  static const String text = 'text';
  static const String number = 'number';
  static const String email = 'email';
  static const String password = 'password';
  static const String phone = 'phone';
  static const String url = 'url';
  static const String multiline = 'multiline';
}

abstract final class FontWeight {
  static const String w100 = 'w100';
  static const String w200 = 'w200';
  static const String w300 = 'w300';
  static const String w400 = 'w400';
  static const String w500 = 'w500';
  static const String w600 = 'w600';
  static const String w700 = 'w700';
  static const String w800 = 'w800';
  static const String w900 = 'w900';
  static const String bold = 'bold';
  static const String normal = 'normal';
}

abstract final class TextDecoration {
  static const String none = 'none';
  static const String underline = 'underline';
  static const String overline = 'overline';
  static const String lineThrough = 'lineThrough';
}

// ── EdgeInsets ──────────────────────────────────────────────

abstract final class EdgeInsets {
  static Map<String, dynamic> all(num value) =>
      {'top': value, 'right': value, 'bottom': value, 'left': value};

  static Map<String, dynamic> symmetric(
          {num horizontal = 0, num vertical = 0}) =>
      {
        'top': vertical,
        'right': horizontal,
        'bottom': vertical,
        'left': horizontal,
      };

  static Map<String, dynamic> only(
          {num top = 0, num right = 0, num bottom = 0, num left = 0}) =>
      {'top': top, 'right': right, 'bottom': bottom, 'left': left};
}

// ── BorderRadius ────────────────────────────────────────────

abstract final class BorderRadius {
  static Map<String, dynamic> all(num value) => {
        'topLeft': value,
        'topRight': value,
        'bottomLeft': value,
        'bottomRight': value,
      };

  static Map<String, dynamic> circular(num radius) => all(radius);

  static Map<String, dynamic> only({
    num? topLeft,
    num? topRight,
    num? bottomLeft,
    num? bottomRight,
  }) =>
      {
        if (topLeft != null) 'topLeft': topLeft,
        if (topRight != null) 'topRight': topRight,
        if (bottomLeft != null) 'bottomLeft': bottomLeft,
        if (bottomRight != null) 'bottomRight': bottomRight,
      };
}

// ── TextStyle ───────────────────────────────────────────────

/// Mirror of the TS `TextStyle({...})` builder. Returns a plain map shaped
/// exactly like `TextStyleData` on the wire — the SDK decodes it into
/// Flutter's `TextStyle`.
Map<String, dynamic> TextStyle({
  dynamic fontSize,
  dynamic fontWeight,
  dynamic fontFamily,
  dynamic fontStyle,
  dynamic color,
  dynamic backgroundColor,
  dynamic letterSpacing,
  dynamic wordSpacing,
  dynamic height,
  dynamic decoration,
  dynamic decorationColor,
  dynamic decorationStyle,
  String? overflow,
}) =>
    {
      if (fontSize != null) 'fontSize': fontSize,
      if (fontWeight != null) 'fontWeight': fontWeight,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (fontStyle != null) 'fontStyle': fontStyle,
      if (color != null) 'color': color,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      if (letterSpacing != null) 'letterSpacing': letterSpacing,
      if (wordSpacing != null) 'wordSpacing': wordSpacing,
      if (height != null) 'height': height,
      if (decoration != null) 'decoration': decoration,
      if (decorationColor != null) 'decorationColor': decorationColor,
      if (decorationStyle != null) 'decorationStyle': decorationStyle,
      if (overflow != null) 'overflow': overflow,
    };

// ── BoxDecoration ───────────────────────────────────────────

/// Border spec used by [BoxDecoration]. All fields optional to match the
/// TS `BorderData` interface.
Map<String, dynamic> Border({
  dynamic width,
  dynamic color,
  String? style,
}) =>
    {
      if (width != null) 'width': width,
      if (color != null) 'color': color,
      if (style != null) 'style': style,
    };

/// Box shadow spec used by [BoxDecoration]. `offset` takes a `{dx, dy}`
/// map because both dx and dy are independently Valueable on the wire.
Map<String, dynamic> BoxShadow({
  dynamic color,
  dynamic blurRadius,
  dynamic spreadRadius,
  Map<String, dynamic>? offset,
}) =>
    {
      if (color != null) 'color': color,
      if (blurRadius != null) 'blurRadius': blurRadius,
      if (spreadRadius != null) 'spreadRadius': spreadRadius,
      if (offset != null) 'offset': offset,
    };

/// Gradient spec used by [BoxDecoration]. `type` is the one required key —
/// either `'linear'` or `'radial'`.
Map<String, dynamic> Gradient({
  required String type,
  required List<dynamic> colors,
  String? begin,
  String? end,
  List<num>? stops,
}) =>
    {
      'type': type,
      'colors': colors,
      if (begin != null) 'begin': begin,
      if (end != null) 'end': end,
      if (stops != null) 'stops': stops,
    };

Map<String, dynamic> BoxDecoration({
  dynamic color,
  dynamic borderRadius,
  Map<String, dynamic>? border,
  List<Map<String, dynamic>>? boxShadow,
  Map<String, dynamic>? gradient,
}) =>
    {
      if (color != null) 'color': color,
      if (borderRadius != null) 'borderRadius': borderRadius,
      if (border != null) 'border': border,
      if (boxShadow != null) 'boxShadow': boxShadow,
      if (gradient != null) 'gradient': gradient,
    };

// ── BoxConstraints / Positioned ─────────────────────────────

Map<String, dynamic> BoxConstraints({
  num? minWidth,
  num? maxWidth,
  num? minHeight,
  num? maxHeight,
}) =>
    {
      if (minWidth != null) 'minWidth': minWidth,
      if (maxWidth != null) 'maxWidth': maxWidth,
      if (minHeight != null) 'minHeight': minHeight,
      if (maxHeight != null) 'maxHeight': maxHeight,
    };

// ── Color ───────────────────────────────────────────────────

/// Convert an HTML-style hex color to Flutter's ARGB format
/// `"0xAARRGGBB"`. Matches the TS `Color()` helper byte-for-byte so
/// snapshots taken against the TS engine stay valid.
///
/// Accepted inputs:
///   `"#RGB"`, `"#RGBA"`, `"#RRGGBB"`, `"#RRGGBBAA"`, and the already-
///   Flutter-shaped `"0xAARRGGBB"` (returned verbatim).
///
/// Any other shape is returned unchanged — callers that need strict
/// validation should do it upstream rather than relying on this helper.
String Color(String hex) {
  if (hex.startsWith('0x') || hex.startsWith('0X')) return hex;
  var raw = hex.startsWith('#') ? hex.substring(1) : hex;
  raw = raw.toUpperCase();
  switch (raw.length) {
    case 3:
      final r = raw[0], g = raw[1], b = raw[2];
      return '0xFF$r$r$g$g$b$b';
    case 4:
      final r = raw[0], g = raw[1], b = raw[2], a = raw[3];
      return '0x$a$a$r$r$g$g$b$b';
    case 6:
      return '0xFF$raw';
    case 8:
      final rr = raw.substring(0, 2);
      final gg = raw.substring(2, 4);
      final bb = raw.substring(4, 6);
      final aa = raw.substring(6, 8);
      return '0x$aa$rr$gg$bb';
    default:
      return hex;
  }
}

/// Material palette — same set and same ARGB values as the TS `Colors`
/// constant. Kept eagerly computed since `Color()` is pure.
abstract final class Colors {
  static final String black = Color('#000000');
  static final String white = Color('#FFFFFF');
  static final String red = Color('#F44336');
  static final String pink = Color('#E91E63');
  static final String purple = Color('#9C27B0');
  static final String deepPurple = Color('#673AB7');
  static final String indigo = Color('#3F51B5');
  static final String blue = Color('#2196F3');
  static final String lightBlue = Color('#03A9F4');
  static final String cyan = Color('#00BCD4');
  static final String teal = Color('#009688');
  static final String green = Color('#4CAF50');
  static final String lightGreen = Color('#8BC34A');
  static final String lime = Color('#CDDC39');
  static final String yellow = Color('#FFEB3B');
  static final String amber = Color('#FFC107');
  static final String orange = Color('#FF9800');
  static final String deepOrange = Color('#FF5722');
  static final String brown = Color('#795548');
  static final String grey = Color('#9E9E9E');
  static final String blueGrey = Color('#607D8B');
  static final String transparent = Color('#00000000');
}

// ── Curves ──────────────────────────────────────────────────
//
// TS uses a `Curves` enum — Dart mirrors it as string constants so the
// wire format matches without a runtime enum lookup.

abstract final class Curves {
  static const String linear = 'linear';
  static const String ease = 'ease';
  static const String easeIn = 'easeIn';
  static const String easeOut = 'easeOut';
  static const String easeInOut = 'easeInOut';
  static const String decelerate = 'decelerate';
  static const String bounceIn = 'bounceIn';
  static const String bounceOut = 'bounceOut';
  static const String bounceInOut = 'bounceInOut';
  static const String elasticIn = 'elasticIn';
  static const String elasticOut = 'elasticOut';
  static const String elasticInOut = 'elasticInOut';
  static const String fastOutSlowIn = 'fastOutSlowIn';
}
