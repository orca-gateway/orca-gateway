import 'dart:convert' show JsonDecoder;

class ClientTimingCollector {
  final _stopwatch = Stopwatch()..start();
  final _marks = <String, double>{};

  void mark(String name) {
    _marks[name] = _stopwatch.elapsedMicroseconds / 1000.0;
  }

  ClientTimingData toData() {
    final start = _marks['requestStart'] ?? 0;
    return ClientTimingData(
      requestStartMs: 0,
      responseReceivedMs: (_marks['responseReceived'] ?? start) - start,
      parseCompleteMs: (_marks['parseComplete'] ?? start) - start,
      renderStartMs: (_marks['renderStart'] ?? start) - start,
      renderCompleteMs: (_marks['renderComplete'] ?? start) - start,
      firstFrameMs: (_marks['firstFrame'] ?? start) - start,
    );
  }
}

class ClientTimingData {
  final double requestStartMs;
  final double responseReceivedMs;
  final double parseCompleteMs;
  final double renderStartMs;
  final double renderCompleteMs;
  final double firstFrameMs;

  ClientTimingData({
    required this.requestStartMs,
    required this.responseReceivedMs,
    required this.parseCompleteMs,
    required this.renderStartMs,
    required this.renderCompleteMs,
    required this.firstFrameMs,
  });

  Map<String, dynamic> toJson() => {
        'requestStartMs': requestStartMs,
        'responseReceivedMs': responseReceivedMs,
        'parseCompleteMs': parseCompleteMs,
        'renderStartMs': renderStartMs,
        'renderCompleteMs': renderCompleteMs,
        'firstFrameMs': firstFrameMs,
      };
}

class CombinedTimingData {
  final Map<String, dynamic>? serverTiming;
  final ClientTimingData clientTiming;

  CombinedTimingData({this.serverTiming, required this.clientTiming});

  factory CombinedTimingData.merge(
      String? serverHeader, ClientTimingCollector collector) {
    Map<String, dynamic>? server;
    if (serverHeader != null && serverHeader.isNotEmpty) {
      try {
        server = Map<String, dynamic>.from(
          (const JsonDecoder().convert(serverHeader)) as Map,
        );
      } catch (_) {}
    }
    return CombinedTimingData(
        serverTiming: server, clientTiming: collector.toData());
  }

  Map<String, dynamic> toJson() => {
        if (serverTiming != null) 'server': serverTiming,
        'client': clientTiming.toJson(),
      };
}
