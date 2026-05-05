import 'package:flutter/material.dart' show ThemeData, ThemeMode;
import 'package:flutter/widgets.dart';

/// Developer-facing passthrough configuration for the [MaterialApp] /
/// [MaterialApp.router] that OrcaApp mounts internally.
///
/// All fields are optional and map 1:1 to their [MaterialApp] counterparts.
/// The SDK deliberately does NOT expose routing-related fields
/// (`routerConfig`, `home`, `routes`, etc.) because OrcaApp owns routing.
///
/// Values set here are forwarded to BOTH the boot-time `MaterialApp`
/// (which hosts splash/force-update/error screens) and the ready-state
/// `MaterialApp.router`, so theming stays consistent across the boot swap.
class OrcaMaterialAppConfig {
  // --- Theme ---
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeData? highContrastTheme;
  final ThemeData? highContrastDarkTheme;
  final ThemeMode? themeMode;
  final Duration? themeAnimationDuration;
  final Curve? themeAnimationCurve;

  // --- Localization ---
  final Locale? locale;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final LocaleListResolutionCallback? localeListResolutionCallback;
  final LocaleResolutionCallback? localeResolutionCallback;
  final Iterable<Locale>? supportedLocales;

  // --- Title / branding ---
  final String? title;
  final GenerateAppTitle? onGenerateTitle;
  final Color? color;

  // --- Behavior ---
  final TransitionBuilder? builder;
  final ScrollBehavior? scrollBehavior;
  final Map<ShortcutActivator, Intent>? shortcuts;
  final Map<Type, Action<Intent>>? actions;
  final String? restorationScopeId;

  // --- Observers (router branch threads these through GoRouter instead) ---
  final List<NavigatorObserver>? navigatorObservers;

  // --- Debug flags ---
  final bool? debugShowCheckedModeBanner;
  final bool? showPerformanceOverlay;
  final bool? showSemanticsDebugger;
  final bool? checkerboardRasterCacheImages;
  final bool? checkerboardOffscreenLayers;

  const OrcaMaterialAppConfig({
    this.theme,
    this.darkTheme,
    this.highContrastTheme,
    this.highContrastDarkTheme,
    this.themeMode,
    this.themeAnimationDuration,
    this.themeAnimationCurve,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales,
    this.title,
    this.onGenerateTitle,
    this.color,
    this.builder,
    this.scrollBehavior,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    this.navigatorObservers,
    this.debugShowCheckedModeBanner,
    this.showPerformanceOverlay,
    this.showSemanticsDebugger,
    this.checkerboardRasterCacheImages,
    this.checkerboardOffscreenLayers,
  });
}
