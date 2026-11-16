// T3.5: every DevTools event the Flutter SDK sends, built by the same code
// the SDK sends it with, equals its fixture in schema/fixtures/devtools.
// The Swift and Kotlin SDKs build the same events and compare them to the
// same files (sdk-swift/Tests/OrcaGatewayCoreTests/DevToolsEventTests.swift,
// sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/debug/DevToolsEventTest.kt).
// The traces in the -traced fixtures are Flutter's own: ValueResolver
// .resolveWithTrace runs on the value below, as the executor and the
// renderer run it, so the files pin the exact text every SDK must send.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/src/debug/debug_events.dart';
import 'package:orca_gateway/src/debug/dev_tools_client.dart';
import 'package:orca_gateway/src/debug/orca_debug.dart';
import 'package:orca_gateway/src/debug/timing_collector.dart';
import 'package:orca_gateway/src/state/value_resolver.dart';

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

/// The page state `count` as a value, as the engine sends `V.pageState`.
const _countRef = {'type': 'state', 'key': 'count', 'scope': 'page'};

/// A setState of `count + 1`, the value a transform over the state ref.
final Map<String, dynamic> _incrementCount = {
  'type': 'setState',
  'key': 'count',
  'scope': 'page',
  'value': {
    'type': 'transform',
    'input': _countRef,
    'by': [
      {
        'type': 'add',
        'by': {'type': 'static', 'value': 1},
      },
    ],
  },
};

/// A Text's `data` prop: `count` through toString.
final Map<String, dynamic> _countText = {
  'type': 'transform',
  'input': _countRef,
  'by': [
    {'type': 'toString'},
  ],
};

/// Flutter's trace of [value] over [state], as the action executor and the
/// component context put it in an event (TransformTrace.toJson per step).
List<Map<String, dynamic>> _trace(dynamic value, Map<String, dynamic> state) {
  final (_, steps) = ValueResolver(state: state).resolveWithTrace(value);
  return [for (final step in steps) step.toJson()];
}

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
  'action-traced': _event(
    'action',
    DebugActionEvent(
      actionType: 'setState',
      pageId: 'home',
      durationMs: 1.25,
      actionData: _incrementCount,
      transformTrace: _trace(_incrementCount['value'], {'count': 0}),
      // The page's nodes whose watches hold the key, props left out.
      affectedWidgets: [
        {
          'id': '5',
          'type': 'Text',
          'watches': ['count'],
        },
        {
          'id': '8',
          'type': 'Container',
          'watches': ['count', 'theme'],
        },
      ],
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
  // A page fetch with bodies on: the appState it posted, the page it got.
  'network-bodies': _event(
    'network',
    DebugNetworkEvent(
      method: 'POST',
      url: 'http://localhost:8080/api/v1/app/counter/page/home',
      statusCode: 200,
      durationMs: 14.25,
      responseSizeBytes: 316,
      requestHeaders: {
        'accept': 'application/json',
        'authorization': '<redacted>',
        'cookie': '<redacted>',
        'proxy-authorization': '<redacted>',
        'x-api-key': '<redacted>',
      },
      responseHeaders: {
        'content-type': 'application/json',
        'set-cookie': '<redacted>',
      },
      phases: const [NetworkPhase(phase: 'wait', durationMs: 14.25)],
      requestBody: {'theme': 'dark', 'cartCount': 2},
      responseBody: {
        'pageId': 'home',
        'title': 'Home',
        'state': [
          {'key': 'count', 'scope': 'page', 'initial': 0},
        ],
        'components': [
          {
            'id': '5',
            'type': 'Text',
            'kind': 'primitive',
            'childMode': 'none',
            'props': {'data': _countText},
            'children': <String>[],
            'watches': ['count'],
          },
        ],
      },
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
  'widget_rebuild-traced': _event(
    'widget_rebuild',
    DebugWidgetRebuildEvent(
      widgetId: '5',
      widgetType: 'Text',
      watches: ['count'],
      propTraces: {
        'data': _trace(_countText, {'count': 1}),
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
