import 'dart:io';
import '../models/app_settings.dart';
import '../models/device_session.dart';

/// Centralised session-export helper used by the toolbar button and the
/// Settings → Export panel. Writes `orca-debug-<deviceId>-<ts>.json` into
/// the configured export directory (falls back to the working dir if unset).
class SessionExporter {
  static Future<File> export({
    required DeviceSession session,
    required AppSettings settings,
  }) async {
    final json = session.toExportJson();
    final dir = settings.exportDirectory.isNotEmpty
        ? settings.exportDirectory
        : Directory.current.path;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('$dir/orca-debug-${session.deviceId}-$stamp.json');
    await file.writeAsString(json);
    return file;
  }
}
