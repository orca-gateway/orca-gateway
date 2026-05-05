import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/src/debug/debug_events.dart';

void main() {
  group('inferActionFamily', () {
    test('returns exact-match families for known action types', () {
      expect(inferActionFamily('setState'), 'state');
      expect(inferActionFamily('navigate'), 'navigation');
      expect(inferActionFamily('showToast'), 'ui-feedback');
      expect(inferActionFamily('serverAction'), 'data');
    });

    test('infers family by prefix/keyword for custom types', () {
      expect(inferActionFamily('NAVIGATE_TO'), 'navigation');
      expect(inferActionFamily('SET_VARIANT'), 'state');
      expect(inferActionFamily('TOAST_SHOW'), 'ui-feedback');
      expect(inferActionFamily('APP_FOREGROUND'), 'lifecycle');
      expect(inferActionFamily('CART_ADD_ITEM'), 'data');
    });

    test('falls back to custom when nothing else matches', () {
      expect(inferActionFamily('TRACK_EVENT'), 'custom');
      expect(inferActionFamily('frobnicate'), 'custom');
    });
  });

  group('DebugActionEvent', () {
    test('serialises the family field on the wire', () {
      final e = DebugActionEvent(
        actionType: 'CART_ADD_ITEM',
        pageId: 'page_product',
        durationMs: 142,
      );
      final json = e.toJson();
      expect(json['actionType'], 'CART_ADD_ITEM');
      expect(json['family'], 'data');
      expect(json['durationMs'], 142);
    });

    test('accepts an explicit family override', () {
      final e = DebugActionEvent(
        actionType: 'MY_CUSTOM_TYPE',
        pageId: 'p',
        durationMs: 1,
        family: 'lifecycle',
      );
      expect(e.family, 'lifecycle');
      expect(e.toJson()['family'], 'lifecycle');
    });
  });

  group('DebugNetworkEvent', () {
    test('omits phases / bodies when not provided', () {
      final e = DebugNetworkEvent(
        method: 'GET',
        url: 'https://api.example.com/home',
        statusCode: 200,
        durationMs: 88,
      );
      final json = e.toJson();
      expect(json['method'], 'GET');
      expect(json.containsKey('phases'), isFalse);
      expect(json.containsKey('requestBody'), isFalse);
      expect(json.containsKey('responseBody'), isFalse);
    });

    test('serialises phases as an array of {phase, durationMs}', () {
      final e = DebugNetworkEvent(
        method: 'POST',
        url: 'https://api.example.com/cart/items',
        statusCode: 200,
        durationMs: 142,
        phases: const [
          NetworkPhase(phase: 'wait', durationMs: 142),
        ],
      );
      final json = e.toJson();
      final phases = json['phases'] as List;
      expect(phases.length, 1);
      expect(phases.first, {'phase': 'wait', 'durationMs': 142.0});
    });

    test('serialises request and response bodies when provided', () {
      final e = DebugNetworkEvent(
        method: 'POST',
        url: 'https://api.example.com/cart/items',
        statusCode: 200,
        durationMs: 142,
        requestBody: {'sku': 'SKU-84213', 'qty': 1},
        responseBody: {'ok': true},
      );
      final json = e.toJson();
      expect(json['requestBody'], {'sku': 'SKU-84213', 'qty': 1});
      expect(json['responseBody'], {'ok': true});
    });
  });
}
