import 'package:flutter_test/flutter_test.dart';
import 'package:orca_google_map/orca_google_map.dart';

void main() {
  group('GoogleMapPlugin web stub (Epic 38.5)', () {
    final plugin = GoogleMapPlugin();

    test('declares GoogleMap unsupported on web with branded metadata', () {
      final meta = plugin.widgetMetadata['GoogleMap'];
      expect(meta, isNotNull);
      expect(meta!.isSupportedOnWeb, isFalse);
      expect(meta.displayName, 'Google Maps');
    });

    test('registers a web stub builder for GoogleMap', () {
      expect(plugin.webStubs.containsKey('GoogleMap'), isTrue);
    });
  });
}
