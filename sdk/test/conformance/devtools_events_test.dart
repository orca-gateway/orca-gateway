// T3.5: every DevTools event the Flutter SDK sends, built by the same code
// the SDK sends it with, equals its fixture in schema/fixtures/devtools.
// The Swift SDK builds the same events and compares them to the same files
// (sdk-swift/Tests/OrcaGatewayCoreTests/DevToolsEventTests.swift).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/src/debug/debug_events.dart';
import 'package:orca_gateway/src/debug/dev_tools_client.dart';
import 'package:orca_gateway/src/debug/orca_debug.dart';
import 'package:orca_gateway/src/debug/timing_collector.dart';

import 'fixture_paths.dart';

const _deviceId = 'fixture-device';
const _timestamp = 1793980800000;

Map<String, dynamic> _event(String type, Map<String, dynamic> payload) =>
    OrcaDebug.envelope(
      type: type,
      deviceId: _deviceId,
      timestamp: _timestamp,
      payload: payload,
    );

/// Fixture file name (without .json) to the event the SDK builds for it.
final Map<String, Map<String, dynamic>> _built = {
  'device_info': _event(
    'device_info',
    DevToolsClient.deviceInfoPayload(
      platform: 'iOS',
      deviceModel: 'iPhone17,1',
      appName: 'Orca Counter',
    ),
  ),
  'timing': _event(
    'timing',
    DebugTimingEvent(
      pageId: 'home',
      path: 'home',
      timing: CombinedTimingData.merge(
        jsonEncode({
          'path': '/api/v1/app/counter/page/home',
          'method': 'GET',
          'stages': {'getInfo': 0.12, 'getState': 0.05, 'render': 0.41, 'flatten': 0.2},
          'componentCount': 16,
          'responseSizeBytes': 2048,
          'cacheStatus': 'miss',
          'totalMs': 1.5,
          'timestamp': 1793980799990,
        }),
        _FixedMarks(),
      ),
    ).toJson(),
  ),
  'state_change': _event(
    'state_change',
    DebugStateEvent(
      scope: 'page',
      pageId: 'home',
      key: 'count',
      oldValue: 0,
      newValue: 1,
    ).toJson(),
  ),
  'action': _event(
    'action',
    DebugActionEvent(
      actionType: 'setState',
      pageId: 'home',
      durationMs: 0.75,
      actionData: {'type': 'setState', 'key': 'count', 'scope': 'page', 'value': 1},
    ).toJson(),
  ),
  'network': _event(
    'network',
    DebugNetworkEvent(
      method: 'GET',
      url: 'http://localhost:8080/api/v1/app/counter/page/home',
      statusCode: 200,
      durationMs: 12.5,
      responseSizeBytes: 2048,
      requestHeaders: {'accept': 'application/json', 'x-api-key': '<redacted>'},
      responseHeaders: {'content-type': 'application/json'},
      phases: const [NetworkPhase(phase: 'wait', durationMs: 12.5)],
    ).toJson(),
  ),
  'widget_rebuild': _event(
    'widget_rebuild',
    DebugWidgetRebuildEvent(
      widgetId: '5',
      widgetType: 'Text',
      watches: ['count'],
      propTraces: {
        'data': [
          {'op': 'toString', 'in': '1', 'out': '1'},
        ],
      },
    ).toJson(),
  ),
  'error': _event(
    'error',
    DebugErrorEvent(
      message: 'HTTP 500 /api/v1/app/counter/page/home',
      context: 'GET http://localhost:8080/api/v1/app/counter/page/home',
      stackTrace: '{"error":"boom"}',
    ).toJson(),
  ),
  'error-fallback-prompt': _event(
    'error',
    DebugErrorEvent.fallbackPrompt('Checkbox').toJson(),
  ),
};

/// The client marks of the timing fixture, as a collector would hold them.
class _FixedMarks extends ClientTimingCollector {
  @override
  ClientTimingData toData() => ClientTimingData(
        requestStartMs: 0,
        responseReceivedMs: 12.5,
        parseCompleteMs: 13.25,
        renderStartMs: 13.5,
        renderCompleteMs: 20.75,
        firstFrameMs: 21.5,
      );
}

String _name(File f) => f.uri.pathSegments.last.replaceAll('.json', '');

void main() {
  final files = fixtureFiles('devtools');

  test('every fixture has a builder and every builder a fixture', () {
    expect(files.map(_name).toSet(), _built.keys.toSet());
  });

  test('the fixtures cover all seven event types', () {
    final types = {
      for (final f in files) (jsonDecode(f.readAsStringSync()) as Map)['type'],
    };
    expect(types, {
      'device_info',
      'timing',
      'state_change',
      'action',
      'network',
      'widget_rebuild',
      'error',
    });
  });

  for (final file in files) {
    final name = _name(file);
    test('$name equals what the SDK builds', () {
      final expected = jsonDecode(file.readAsStringSync());
      // Through JSON, as the WebSocket sends it.
      final actual = jsonDecode(jsonEncode(_built[name]));
      expect(actual, equals(expected));
    });
  }
}
