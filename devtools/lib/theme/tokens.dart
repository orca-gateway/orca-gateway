import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';

/// Design tokens for the Orca DevTools macOS-native redesign.
/// Ported from the Anthropic Design prototype `components/tokens.jsx`.
///
/// Dark-first. Light variant supported. Accent + density + font scale +
/// sidebar translucency all live here. Every screen and widget reads from
/// [OrcaTheme]; never hard-code a color.

enum OrcaThemeMode { dark, light, system }

enum OrcaAccent { teal, blue, graphite }

enum OrcaDensity { comfy, regular, compact }

class OrcaSurfaces {
  final Color window;
  final Color content;
  final Color raised;
  final Color sunken;
  final Color sidebar;
  final Color zebra;
  final Color hover;
  const OrcaSurfaces({
    required this.window,
    required this.content,
    required this.raised,
    required this.sunken,
    required this.sidebar,
    required this.zebra,
    required this.hover,
  });
}

class OrcaBorders {
  final Color hairline;
  final Color divider;
  final Color strong;
  const OrcaBorders({
    required this.hairline,
    required this.divider,
    required this.strong,
  });
}

class OrcaTextColors {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color onAccent;
  const OrcaTextColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.onAccent,
  });
}

class OrcaAccentColors {
  final Color base;
  final Color muted;
  final Color ring;
  const OrcaAccentColors({
    required this.base,
    required this.muted,
    required this.ring,
  });
}

class OrcaSemantic {
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color scopeApp;
  final Color scopePage;
  const OrcaSemantic({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.scopeApp,
    required this.scopePage,
  });
}

class OrcaStage {
  final Color getInfo;
  final Color getState;
  final Color render;
  final Color flatten;
  final Color postRender;
  final Color network;
  final Color parse;
  final Color widgetBuild;
  const OrcaStage({
    required this.getInfo,
    required this.getState,
    required this.render,
    required this.flatten,
    required this.postRender,
    required this.network,
    required this.parse,
    required this.widgetBuild,
  });

  Color byKey(String key) {
    switch (key) {
      case 'getInfo':
        return getInfo;
      case 'getState':
        return getState;
      case 'render':
        return render;
      case 'flatten':
        return flatten;
      case 'postRender':
        return postRender;
      case 'network':
        return network;
      case 'parse':
        return parse;
      case 'widgetBuild':
        return widgetBuild;
      default:
        return getInfo;
    }
  }
}

class OrcaDensityValues {
  final double row;
  final double tableRow;
  final double sidebarRow;
  final double pad;
  final double chipY;
  const OrcaDensityValues({
    required this.row,
    required this.tableRow,
    required this.sidebarRow,
    required this.pad,
    required this.chipY,
  });
}

const _densityComfy = OrcaDensityValues(
  row: 32,
  tableRow: 30,
  sidebarRow: 30,
  pad: 20,
  chipY: 4,
);
const _densityRegular = OrcaDensityValues(
  row: 28,
  tableRow: 26,
  sidebarRow: 28,
  pad: 16,
  chipY: 3,
);
const _densityCompact = OrcaDensityValues(
  row: 24,
  tableRow: 22,
  sidebarRow: 24,
  pad: 12,
  chipY: 2,
);

const _darkSurfaces = OrcaSurfaces(
  window: Color(0xFF1E1E20),
  content: Color(0xFF28282B),
  raised: Color(0xFF2F2F33),
  sunken: Color(0xB81E1E20),
  sidebar: Color(0xB8242428),
  zebra: Color(0x06FFFFFF),
  hover: Color(0x0DFFFFFF),
);
const _lightSurfaces = OrcaSurfaces(
  window: Color(0xFFECECEC),
  content: Color(0xFFFFFFFF),
  raised: Color(0xFFFBFBFB),
  sunken: Color(0xB8F6F6F6),
  sidebar: Color(0xC7E4E8EE),
  zebra: Color(0x06000000),
  hover: Color(0x0A000000),
);

const _darkBorders = OrcaBorders(
  hairline: Color(0x1AFFFFFF),
  divider: Color(0x0FFFFFFF),
  strong: Color(0x2EFFFFFF),
);
const _lightBorders = OrcaBorders(
  hairline: Color(0x1A000000),
  divider: Color(0x0F000000),
  strong: Color(0x2E000000),
);

const _darkText = OrcaTextColors(
  primary: Color(0xFFF5F5F7),
  secondary: Color(0x9EFFFFFF),
  tertiary: Color(0x61FFFFFF),
  onAccent: Color(0xFFFFFFFF),
);
const _lightText = OrcaTextColors(
  primary: Color(0xFF1D1D1F),
  secondary: Color(0x94000000),
  tertiary: Color(0x61000000),
  onAccent: Color(0xFFFFFFFF),
);

const _darkSemantic = OrcaSemantic(
  success: Color(0xFF3FCB7B),
  warning: Color(0xFFE0A44A),
  danger: Color(0xFFFF6B6B),
  info: Color(0xFF8E9EE8),
  scopeApp: Color(0xFFE0A44A),
  scopePage: Color(0xFF34C8E8),
);
const _lightSemantic = OrcaSemantic(
  success: Color(0xFF1F9D55),
  warning: Color(0xFFB8741A),
  danger: Color(0xFFC63A3A),
  info: Color(0xFF5A6BC0),
  scopeApp: Color(0xFFA86A1F),
  scopePage: Color(0xFF0A84C7),
);

const _darkStage = OrcaStage(
  getInfo: Color(0xFF7FB3E8),
  getState: Color(0xFF7FD3C9),
  render: Color(0xFF7BCBA2),
  flatten: Color(0xFFE0C26F),
  postRender: Color(0xFFE3A56F),
  network: Color(0xFFB99BE8),
  parse: Color(0xFFD49BE0),
  widgetBuild: Color(0xFFE89BB6),
);
const _lightStage = OrcaStage(
  getInfo: Color(0xFF3578B5),
  getState: Color(0xFF2F9E91),
  render: Color(0xFF2E9260),
  flatten: Color(0xFFB0871E),
  postRender: Color(0xFFB46A28),
  network: Color(0xFF7B5CB8),
  parse: Color(0xFF9A5CAE),
  widgetBuild: Color(0xFFB65A7D),
);

OrcaAccentColors _accentFor(OrcaAccent a, bool dark) {
  switch (a) {
    case OrcaAccent.teal:
      return dark
          ? const OrcaAccentColors(
              base: Color(0xFF34C8E8),
              muted: Color(0x2E34C8E8),
              ring: Color(0x5934C8E8),
            )
          : const OrcaAccentColors(
              base: Color(0xFF0A84C7),
              muted: Color(0x1F0A84C7),
              ring: Color(0x470A84C7),
            );
    case OrcaAccent.blue:
      return dark
          ? const OrcaAccentColors(
              base: Color(0xFF5E9BF5),
              muted: Color(0x335E9BF5),
              ring: Color(0x615E9BF5),
            )
          : const OrcaAccentColors(
              base: Color(0xFF0A6DD6),
              muted: Color(0x1F0A6DD6),
              ring: Color(0x470A6DD6),
            );
    case OrcaAccent.graphite:
      return dark
          ? const OrcaAccentColors(
              base: Color(0xFFCFD2D8),
              muted: Color(0x29CFD2D8),
              ring: Color(0x52CFD2D8),
            )
          : const OrcaAccentColors(
              base: Color(0xFF3A3A3F),
              muted: Color(0x1A3A3A3F),
              ring: Color(0x383A3A3F),
            );
  }
}

OrcaDensityValues _densityFor(OrcaDensity d) {
  switch (d) {
    case OrcaDensity.comfy:
      return _densityComfy;
    case OrcaDensity.regular:
      return _densityRegular;
    case OrcaDensity.compact:
      return _densityCompact;
  }
}

class OrcaTheme {
  final bool isDark;
  final OrcaSurfaces surface;
  final OrcaBorders border;
  final OrcaTextColors text;
  final OrcaAccentColors accent;
  final OrcaSemantic semantic;
  final OrcaStage stage;
  final OrcaDensityValues density;
  final double fontScale;
  final bool translucent;
  final List<BoxShadow> floatShadow;

  const OrcaTheme._({
    required this.isDark,
    required this.surface,
    required this.border,
    required this.text,
    required this.accent,
    required this.semantic,
    required this.stage,
    required this.density,
    required this.fontScale,
    required this.translucent,
    required this.floatShadow,
  });

  factory OrcaTheme.build({
    required OrcaThemeMode mode,
    required OrcaAccent accent,
    required OrcaDensity density,
    required double fontScale,
    required bool translucent,
  }) {
    final bool dark = mode == OrcaThemeMode.system
        ? PlatformDispatcher.instance.platformBrightness == Brightness.dark
        : mode == OrcaThemeMode.dark;
    return OrcaTheme._(
      isDark: dark,
      surface: dark ? _darkSurfaces : _lightSurfaces,
      border: dark ? _darkBorders : _lightBorders,
      text: dark ? _darkText : _lightText,
      accent: _accentFor(accent, dark),
      semantic: dark ? _darkSemantic : _lightSemantic,
      stage: dark ? _darkStage : _lightStage,
      density: _densityFor(density),
      fontScale: fontScale,
      translucent: translucent,
      floatShadow: [
        BoxShadow(
          color: Color(dark ? 0x73000000 : 0x1F000000),
          offset: const Offset(0, 8),
          blurRadius: 24,
        ),
      ],
    );
  }

  /// Produce a [ThemeData] compatible with [MaterialApp]. Kept minimal — the
  /// whole UI is styled via [OrcaTheme] directly, not Material widgets.
  ThemeData toFlutterThemeData() {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: surface.content,
      canvasColor: surface.content,
      colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: accent.base,
        surface: surface.content,
        onSurface: text.primary,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: text.primary),
        bodySmall: TextStyle(color: text.secondary),
      ),
      useMaterial3: true,
    );
  }

  /// Semantic color lookup by string tone name — matches the prototype's
  /// `Chip` component, which accepts tones from semantic/stage/accent tables.
  Color toneColor(String tone) {
    switch (tone) {
      case 'success':
        return semantic.success;
      case 'warning':
        return semantic.warning;
      case 'danger':
        return semantic.danger;
      case 'info':
        return semantic.info;
      case 'scopeApp':
        return semantic.scopeApp;
      case 'scopePage':
        return semantic.scopePage;
      case 'accent':
        return accent.base;
      default:
        return stage.byKey(tone);
    }
  }
}
