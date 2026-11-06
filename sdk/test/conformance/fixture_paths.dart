import 'dart:io';

/// Locate `schema/fixtures/<sub>` by walking up from the working directory.
/// `flutter test` runs from `sdk/`, so the first parent hit is the monorepo
/// root; the walk keeps the runner independent of where it is launched.
Directory fixturesDir(String sub) {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = Directory('${dir.path}/schema/fixtures/$sub');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'schema/fixtures/$sub not found above ${Directory.current.path}',
  );
}

List<File> fixtureFiles(String sub) {
  final files =
      fixturesDir(sub)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}
