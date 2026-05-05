import 'package:flutter/material.dart'
    show
        Icons,
        IconData,
        InputBorder,
        InputDecoration,
        OutlineInputBorder,
        UnderlineInputBorder;
import 'package:flutter/widgets.dart';
import '../rendering/component_context.dart';
import '../state/value_resolver.dart';

/// Render all children of a multi-child node.
List<Widget> renderChildren(OrcaComponentContext ctx) {
  return ctx.childIds.map((id) => ctx.renderChild(id) as Widget).toList();
}

/// Render a single child (first child ID), or SizedBox.shrink() if none.
Widget renderChild(OrcaComponentContext ctx) {
  if (ctx.childIds.isEmpty) return const SizedBox.shrink();
  return ctx.renderChild(ctx.childIds.first) as Widget;
}

/// Render a named slot child from props (stored as a child ID string).
Widget? renderSlot(OrcaComponentContext ctx, String slotKey) {
  final childId = ctx.prop<String>(slotKey);
  if (childId == null) return null;
  return ctx.renderChild(childId) as Widget;
}

/// Extract scroll metrics into a V.event-compatible data map.
Map<String, dynamic> _scrollEventData(ScrollMetrics m) {
  return {
    'offset': m.pixels,
    'maxExtent': m.maxScrollExtent,
    'minExtent': m.minScrollExtent,
    'viewportDimension': m.viewportDimension,
    'atStart': m.atEdge && m.pixels <= m.minScrollExtent,
    'atEnd': m.atEdge && m.pixels >= m.maxScrollExtent,
  };
}

/// Wraps a scrollable [child] in a [NotificationListener] that fires
/// `onScrollBegin`, `onScrolling`, and `onScrollEnd` triggers with
/// scroll-position data accessible via `V.event('offset')`, etc.
Widget wrapScrollNotifier(OrcaComponentContext ctx, Widget child) {
  final actions = ctx.node.actions;
  final hasAny =
      actions != null &&
      (actions.containsKey('onScrollBegin') ||
          actions.containsKey('onScrolling') ||
          actions.containsKey('onScrollEnd'));

  if (!hasAny) return child;

  return NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      final data = _scrollEventData(notification.metrics);
      if (notification is ScrollStartNotification) {
        ctx.fireAction('onScrollBegin', eventData: data);
      } else if (notification is ScrollUpdateNotification) {
        data['delta'] = notification.scrollDelta ?? 0;
        ctx.fireAction('onScrolling', eventData: data);
      } else if (notification is ScrollEndNotification) {
        ctx.fireAction('onScrollEnd', eventData: data);
      }
      return false;
    },
    child: child,
  );
}

/// Parse EdgeInsets from a map.
EdgeInsets? parseEdgeInsets(dynamic data) {
  if (data == null) return null;
  if (data is Map) {
    return EdgeInsets.only(
      top: (data['top'] as num?)?.toDouble() ?? 0,
      right: (data['right'] as num?)?.toDouble() ?? 0,
      bottom: (data['bottom'] as num?)?.toDouble() ?? 0,
      left: (data['left'] as num?)?.toDouble() ?? 0,
    );
  }
  return null;
}

// Defensive String? extractor — returns null instead of throwing when a
// caller passes an unresolved Value / nested Map. `ctx.prop` is supposed
// to deep-resolve these, but leaving a hard cast in a render path means
// one missed resolution anywhere crashes the whole subtree. Silent null
// is the right fallback for a style field.
String? _asStringOrNull(dynamic v) => v is String ? v : null;
num? _asNumOrNull(dynamic v) => v is num ? v : null;

/// Parse TextStyle from a map.
TextStyle? parseTextStyle(dynamic data) {
  if (data == null) return null;
  if (data is Map) {
    return TextStyle(
      fontSize: _asNumOrNull(data['fontSize'])?.toDouble(),
      fontWeight: _parseFontWeight(_asStringOrNull(data['fontWeight'])),
      fontFamily: _asStringOrNull(data['fontFamily']),
      fontStyle: data['fontStyle'] == 'italic'
          ? FontStyle.italic
          : FontStyle.normal,
      color: parseColor(data['color']),
      backgroundColor: parseColor(data['backgroundColor']),
      letterSpacing: _asNumOrNull(data['letterSpacing'])?.toDouble(),
      wordSpacing: _asNumOrNull(data['wordSpacing'])?.toDouble(),
      height: _asNumOrNull(data['height'])?.toDouble(),
      decoration: _parseTextDecoration(_asStringOrNull(data['decoration'])),
      decorationColor: parseColor(data['decorationColor']),
      decorationStyle: _parseDecorationStyle(
        _asStringOrNull(data['decorationStyle']),
      ),
      overflow: _parseTextOverflow(_asStringOrNull(data['overflow'])),
    );
  }
  return null;
}

FontWeight? _parseFontWeight(String? value) {
  if (value == null) return null;
  return switch (value) {
    'w100' => FontWeight.w100,
    'w200' => FontWeight.w200,
    'w300' => FontWeight.w300,
    'w400' || 'normal' => FontWeight.w400,
    'w500' => FontWeight.w500,
    'w600' => FontWeight.w600,
    'w700' || 'bold' => FontWeight.bold,
    'w800' => FontWeight.w800,
    'w900' => FontWeight.w900,
    _ => null,
  };
}

TextDecoration? _parseTextDecoration(String? value) {
  if (value == null) return null;
  return switch (value) {
    'none' => TextDecoration.none,
    'underline' => TextDecoration.underline,
    'overline' => TextDecoration.overline,
    'lineThrough' => TextDecoration.lineThrough,
    _ => null,
  };
}

TextDecorationStyle? _parseDecorationStyle(String? value) {
  if (value == null) return null;
  return switch (value) {
    'solid' => TextDecorationStyle.solid,
    'double' => TextDecorationStyle.double,
    'dotted' => TextDecorationStyle.dotted,
    'dashed' => TextDecorationStyle.dashed,
    'wavy' => TextDecorationStyle.wavy,
    _ => null,
  };
}

TextOverflow? _parseTextOverflow(String? value) {
  if (value == null) return null;
  return switch (value) {
    'clip' => TextOverflow.clip,
    'fade' => TextOverflow.fade,
    'ellipsis' => TextOverflow.ellipsis,
    'visible' => TextOverflow.visible,
    _ => null,
  };
}

/// Parse a color string (web/CSS hex format: `#RRGGBB` or `#RRGGBBAA`).
/// Alpha is last (CSS convention); Flutter's `Color` wants AARRGGBB, so the
/// nibbles are rotated internally when an 8-digit hex is provided.
Color? parseColor(dynamic value) {
  if (value == null) return null;
  if (value is String && value.startsWith('#')) {
    final hex = value.substring(1);
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      final rgb = hex.substring(0, 6);
      final alpha = hex.substring(6, 8);
      return Color(int.parse('$alpha$rgb', radix: 16));
    }
  }
  return null;
}

/// Parse MainAxisAlignment from string.
MainAxisAlignment parseMainAxisAlignment(String? value) {
  return switch (value) {
    'start' => MainAxisAlignment.start,
    'end' => MainAxisAlignment.end,
    'center' => MainAxisAlignment.center,
    'spaceBetween' => MainAxisAlignment.spaceBetween,
    'spaceAround' => MainAxisAlignment.spaceAround,
    'spaceEvenly' => MainAxisAlignment.spaceEvenly,
    _ => MainAxisAlignment.start,
  };
}

/// Parse CrossAxisAlignment from string.
CrossAxisAlignment parseCrossAxisAlignment(String? value) {
  return switch (value) {
    'start' => CrossAxisAlignment.start,
    'end' => CrossAxisAlignment.end,
    'center' => CrossAxisAlignment.center,
    'stretch' => CrossAxisAlignment.stretch,
    'baseline' => CrossAxisAlignment.baseline,
    _ => CrossAxisAlignment.center,
  };
}

/// Parse MainAxisSize from string.
MainAxisSize parseMainAxisSize(String? value) {
  return switch (value) {
    'min' => MainAxisSize.min,
    'max' => MainAxisSize.max,
    _ => MainAxisSize.max,
  };
}

/// Parse Alignment from string.
Alignment parseAlignment(String? value) {
  return switch (value) {
    'topLeft' => Alignment.topLeft,
    'topCenter' => Alignment.topCenter,
    'topRight' => Alignment.topRight,
    'centerLeft' => Alignment.centerLeft,
    'center' => Alignment.center,
    'centerRight' => Alignment.centerRight,
    'bottomLeft' => Alignment.bottomLeft,
    'bottomCenter' => Alignment.bottomCenter,
    'bottomRight' => Alignment.bottomRight,
    _ => Alignment.center,
  };
}

/// Parse TextDirection from string. Defaults to ltr when null or unknown.
TextDirection? parseTextDirection(String? value) {
  return switch (value) {
    'ltr' => TextDirection.ltr,
    'rtl' => TextDirection.rtl,
    _ => null,
  };
}

/// Parse VerticalDirection from string. Defaults to down when null or unknown.
VerticalDirection parseVerticalDirection(String? value) {
  return switch (value) {
    'up' => VerticalDirection.up,
    'down' => VerticalDirection.down,
    _ => VerticalDirection.down,
  };
}

/// Parse TextBaseline from string. Returns null when unset — Flutter only
/// reads this when crossAxisAlignment is baseline, so null is safe.
TextBaseline? parseTextBaseline(String? value) {
  return switch (value) {
    'alphabetic' => TextBaseline.alphabetic,
    'ideographic' => TextBaseline.ideographic,
    _ => null,
  };
}

/// Parse InputDecoration from the TextInputDecorationData map. Null input
/// returns null so callers can skip the decoration when unset.
InputDecoration? parseInputDecoration(dynamic data) {
  if (data == null) return null;
  if (data is! Map) return null;

  final border = switch (data['border'] as String?) {
    'outline' => const OutlineInputBorder(),
    'underline' => const UnderlineInputBorder(),
    'none' => InputBorder.none,
    _ => null,
  };

  return InputDecoration(
    labelText: data['labelText'] as String?,
    hintText: data['hintText'] as String?,
    helperText: data['helperText'] as String?,
    errorText: data['errorText'] as String?,
    prefixText: data['prefixText'] as String?,
    suffixText: data['suffixText'] as String?,
    filled: data['filled'] as bool?,
    fillColor: parseColor(data['fillColor']),
    contentPadding: parseEdgeInsets(data['contentPadding']),
    labelStyle: parseTextStyle(data['labelStyle']),
    hintStyle: parseTextStyle(data['hintStyle']),
    helperStyle: parseTextStyle(data['helperStyle']),
    errorStyle: parseTextStyle(data['errorStyle']),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    isDense: data['isDense'] as bool?,
    semanticCounterText: data['semanticCounterText'] as String?,
  );
}

/// Parse Clip from string. Defaults to Clip.none when null/unknown — matches
/// Flutter's "don't clip unless asked" default for most widgets.
Clip parseClip(String? value) {
  return switch (value) {
    'none' => Clip.none,
    'hardEdge' => Clip.hardEdge,
    'antiAlias' => Clip.antiAlias,
    'antiAliasWithSaveLayer' => Clip.antiAliasWithSaveLayer,
    _ => Clip.none,
  };
}

/// Parse BoxConstraints from a map with optional min/max width/height keys.
/// Returns null when the input is null or not a map — callers can supply
/// their own default constraints.
BoxConstraints? parseBoxConstraints(dynamic data) {
  if (data == null) return null;
  if (data is Map) {
    return BoxConstraints(
      minWidth: (data['minWidth'] as num?)?.toDouble() ?? 0.0,
      maxWidth: (data['maxWidth'] as num?)?.toDouble() ?? double.infinity,
      minHeight: (data['minHeight'] as num?)?.toDouble() ?? 0.0,
      maxHeight: (data['maxHeight'] as num?)?.toDouble() ?? double.infinity,
    );
  }
  return null;
}

/// Parse StackFit from string.
StackFit parseStackFit(String? value) {
  return switch (value) {
    'loose' => StackFit.loose,
    'expand' => StackFit.expand,
    'passthrough' => StackFit.passthrough,
    _ => StackFit.loose,
  };
}

/// Parse BoxDecoration from a map.
BoxDecoration? parseBoxDecoration(dynamic data) {
  if (data == null) return null;
  if (data is Map) {
    return BoxDecoration(
      color: parseColor(data['color']),
      borderRadius: _parseBorderRadius(data['borderRadius']),
      border: _parseBorder(data['border']),
      boxShadow: _parseBoxShadows(data['boxShadow']),
      gradient: _parseGradient(data['gradient']),
    );
  }
  return null;
}

BorderRadius? _parseBorderRadius(dynamic value) {
  if (value == null) return null;
  if (value is num) return BorderRadius.circular(value.toDouble());
  if (value is Map) {
    return BorderRadius.only(
      topLeft: Radius.circular((value['topLeft'] as num?)?.toDouble() ?? 0),
      topRight: Radius.circular((value['topRight'] as num?)?.toDouble() ?? 0),
      bottomLeft: Radius.circular(
        (value['bottomLeft'] as num?)?.toDouble() ?? 0,
      ),
      bottomRight: Radius.circular(
        (value['bottomRight'] as num?)?.toDouble() ?? 0,
      ),
    );
  }
  return null;
}

Border? _parseBorder(dynamic data) {
  if (data == null) return null;
  if (data is Map) {
    final style = data['style'] == 'none'
        ? BorderStyle.none
        : BorderStyle.solid;
    return Border.all(
      color: parseColor(data['color']) ?? const Color(0xFF000000),
      width: (data['width'] as num?)?.toDouble() ?? 1,
      style: style,
    );
  }
  return null;
}

List<BoxShadow>? _parseBoxShadows(dynamic data) {
  if (data == null) return null;
  if (data is List) {
    return data.map((s) {
      final m = s as Map;
      final offset = m['offset'] as Map?;
      return BoxShadow(
        color: parseColor(m['color']) ?? const Color(0x33000000),
        blurRadius: (m['blurRadius'] as num?)?.toDouble() ?? 0,
        spreadRadius: (m['spreadRadius'] as num?)?.toDouble() ?? 0,
        offset: offset != null
            ? Offset(
                (offset['dx'] as num?)?.toDouble() ?? 0,
                (offset['dy'] as num?)?.toDouble() ?? 0,
              )
            : Offset.zero,
      );
    }).toList();
  }
  return null;
}

Gradient? _parseGradient(dynamic data) {
  if (data == null) return null;
  if (data is Map) {
    final colors = (data['colors'] as List).map((c) => parseColor(c)!).toList();
    final stops = (data['stops'] as List?)
        ?.map((s) => (s as num).toDouble())
        .toList();
    final type = data['type'] as String?;
    if (type == 'radial') {
      return RadialGradient(colors: colors, stops: stops);
    }
    return LinearGradient(
      colors: colors,
      stops: stops,
      begin: parseAlignment(data['begin'] as String?),
      end: parseAlignment(data['end'] as String?) == Alignment.center
          ? Alignment.centerRight
          : parseAlignment(data['end'] as String?),
    );
  }
  return null;
}

/// Resolve a Value expression to a display string.
/// Supports static values, state-bound values, and transform pipelines.
String resolveStringValue(
  dynamic value, [
  Map<String, dynamic> state = const {},
]) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  if (value is Map) {
    return ValueResolver(state: state).resolveToString(value);
  }
  return '$value';
}

/// Resolve a Material icon name string to an [IconData].
IconData resolveIconData(String? name) {
  if (name == null) return Icons.circle;
  return _materialIconMap[name] ?? Icons.circle;
}

const _materialIconMap = <String, IconData>{
  'home': Icons.home,
  'home_outlined': Icons.home_outlined,
  'search': Icons.search,
  'shopping_cart': Icons.shopping_cart,
  'shopping_cart_outlined': Icons.shopping_cart_outlined,
  'shopping_bag': Icons.shopping_bag,
  'shopping_bag_outlined': Icons.shopping_bag_outlined,
  'cart': Icons.shopping_cart,
  'person': Icons.person,
  'person_outlined': Icons.person_outlined,
  'profile': Icons.person,
  'settings': Icons.settings,
  'settings_outlined': Icons.settings_outlined,
  'favorite': Icons.favorite,
  'favorite_border': Icons.favorite_border,
  'star': Icons.star,
  'star_border': Icons.star_border,
  'list': Icons.list,
  'menu': Icons.menu,
  'notifications': Icons.notifications,
  'notifications_outlined': Icons.notifications_outlined,
  'mail': Icons.mail,
  'mail_outlined': Icons.mail_outlined,
  'chat': Icons.chat,
  'chat_outlined': Icons.chat_outlined,
  'add': Icons.add,
  'add_circle': Icons.add_circle,
  'add_circle_outline': Icons.add_circle_outline,
  'edit': Icons.edit,
  'delete': Icons.delete,
  'delete_outlined': Icons.delete_outlined,
  'info': Icons.info,
  'info_outlined': Icons.info_outlined,
  'help': Icons.help,
  'help_outlined': Icons.help_outlined,
  'logout': Icons.logout,
  'login': Icons.login,
  'dashboard': Icons.dashboard,
  'category': Icons.category,
  'explore': Icons.explore,
  'history': Icons.history,
  'bookmark': Icons.bookmark,
  'bookmark_border': Icons.bookmark_border,
  'account_circle': Icons.account_circle,
  'circle': Icons.circle,
  'close': Icons.close,
  'check': Icons.check,
  'check_circle': Icons.check_circle,
  'arrow_back': Icons.arrow_back,
  'arrow_forward': Icons.arrow_forward,
  'arrow_upward': Icons.arrow_upward,
  'arrow_downward': Icons.arrow_downward,
  'chevron_left': Icons.chevron_left,
  'chevron_right': Icons.chevron_right,
  'expand_more': Icons.expand_more,
  'expand_less': Icons.expand_less,
  'more_vert': Icons.more_vert,
  'more_horiz': Icons.more_horiz,
  'refresh': Icons.refresh,
  'share': Icons.share,
  'copy': Icons.copy,
  'visibility': Icons.visibility,
  'visibility_off': Icons.visibility_off,
  'lock': Icons.lock,
  'lock_open': Icons.lock_open,
  'phone': Icons.phone,
  'email': Icons.email,
  'location_on': Icons.location_on,
  'map': Icons.map,
  'camera': Icons.camera_alt,
  'camera_alt': Icons.camera_alt,
  'image': Icons.image,
  'photo': Icons.photo,
  'play_arrow': Icons.play_arrow,
  'pause': Icons.pause,
  'stop': Icons.stop,
  'skip_next': Icons.skip_next,
  'skip_previous': Icons.skip_previous,
  'volume_up': Icons.volume_up,
  'volume_off': Icons.volume_off,
  'wifi': Icons.wifi,
  'bluetooth': Icons.bluetooth,
  'dark_mode': Icons.dark_mode,
  'light_mode': Icons.light_mode,
  'language': Icons.language,
  'calendar_today': Icons.calendar_today,
  'access_time': Icons.access_time,
  'attach_file': Icons.attach_file,
  'link': Icons.link,
  'cloud': Icons.cloud,
  'cloud_upload': Icons.cloud_upload,
  'cloud_download': Icons.cloud_download,
  'file_download': Icons.file_download,
  'file_upload': Icons.file_upload,
  'folder': Icons.folder,
  'description': Icons.description,
  'receipt': Icons.receipt,
  'payment': Icons.payment,
  'credit_card': Icons.credit_card,
  'local_shipping': Icons.local_shipping,
  'store': Icons.store,
  'inventory': Icons.inventory,
  'thumb_up': Icons.thumb_up,
  'thumb_down': Icons.thumb_down,
  'grade': Icons.grade,
  'warning': Icons.warning,
  'error': Icons.error,
  'error_outline': Icons.error_outline,
  'task_alt': Icons.task_alt,
  'pending': Icons.pending,
  'hourglass_empty': Icons.hourglass_empty,
  'filter_list': Icons.filter_list,
  'sort': Icons.sort,
  'tune': Icons.tune,
  'palette': Icons.palette,
  'format_bold': Icons.format_bold,
  'format_italic': Icons.format_italic,
  'code': Icons.code,
  'terminal': Icons.terminal,
  'bug_report': Icons.bug_report,
  'build': Icons.build,
  'construction': Icons.construction,
  'analytics': Icons.analytics,
  'bar_chart': Icons.bar_chart,
  'pie_chart': Icons.pie_chart,
  'trending_up': Icons.trending_up,
  'trending_down': Icons.trending_down,
  'speed': Icons.speed,
  'grid_view': Icons.grid_view,
  'send': Icons.send,
  'shuffle': Icons.shuffle,
  'menu_book': Icons.menu_book,
  'key': Icons.key,
  'security': Icons.security,
  'badge': Icons.badge,
  'science': Icons.science,
  'save': Icons.save,
  'cloud_off': Icons.cloud_off,
  'tour': Icons.tour,
  'landscape': Icons.landscape,
  'architecture': Icons.architecture,
  'masjid': Icons.mosque,
  'museum': Icons.museum,
  'zoom_out': Icons.zoom_out,
  'zoom_in': Icons.zoom_in,
  'place': Icons.place,
  'filter_center_focus': Icons.filter_center_focus,
  'touch_app': Icons.touch_app,
  'schedule': Icons.schedule,
  'stop_circle': Icons.stop_circle,
  'replay_10': Icons.replay_10,
  'forward_10': Icons.forward_10,
  'mic': Icons.mic,
  'mic_none': Icons.mic_none,
  'balance': Icons.balance,
  'open_in_new': Icons.open_in_new,
};
