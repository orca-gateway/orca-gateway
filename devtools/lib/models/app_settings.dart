import 'package:flutter/foundation.dart';
import '../theme/tokens.dart';

/// Persistent user settings for the DevTools app.
/// Phase 1 keeps these in-memory only; persistence via `shared_preferences`
/// lands in Phase 4 alongside the redesigned Settings screen.
class AppSettings extends ChangeNotifier {
  // ─── Server / export (pre-existing) ─────────────────────────
  int _port = 6363;
  String _exportDirectory = '';

  // ─── Theme (new — Phase 1) ──────────────────────────────────
  OrcaThemeMode _themeMode = OrcaThemeMode.dark;
  OrcaAccent _accent = OrcaAccent.teal;
  OrcaDensity _density = OrcaDensity.regular;
  double _fontScale = 1.0;
  bool _translucent = true;

  int get port => _port;
  String get exportDirectory => _exportDirectory;

  OrcaThemeMode get themeMode => _themeMode;
  OrcaAccent get accent => _accent;
  OrcaDensity get density => _density;
  double get fontScale => _fontScale;
  bool get translucent => _translucent;

  void setPort(int port) {
    if (port == _port) return;
    _port = port;
    notifyListeners();
  }

  void setExportDirectory(String dir) {
    if (dir == _exportDirectory) return;
    _exportDirectory = dir;
    notifyListeners();
  }

  void setThemeMode(OrcaThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setAccent(OrcaAccent accent) {
    if (accent == _accent) return;
    _accent = accent;
    notifyListeners();
  }

  void setDensity(OrcaDensity density) {
    if (density == _density) return;
    _density = density;
    notifyListeners();
  }

  void setFontScale(double scale) {
    final clamped = scale.clamp(0.85, 1.2);
    if (clamped == _fontScale) return;
    _fontScale = clamped;
    notifyListeners();
  }

  void setTranslucent(bool on) {
    if (on == _translucent) return;
    _translucent = on;
    notifyListeners();
  }
}
