import 'package:shelf/shelf.dart' as shelf;

import '../types/context.dart';

/// Context available to middleware.
class MiddlewareContext {
  final shelf.Request request;
  final RequestInfo requestInfo;
  final String appId;
  final String path;
  final Map<String, dynamic> configuration;

  const MiddlewareContext({
    required this.request,
    required this.requestInfo,
    required this.appId,
    required this.path,
    this.configuration = const {},
  });
}

/// Response from onRequest middleware to short-circuit.
class MiddlewareResponse {
  final int status;
  final Map<String, String>? headers;
  final dynamic body;

  const MiddlewareResponse({required this.status, this.headers, this.body});
}

/// Middleware contract.
abstract class Middleware {
  String get name;
  Future<MiddlewareResponse?> onRequest(MiddlewareContext ctx) async => null;
  Future<shelf.Response> onResponse(
          MiddlewareContext ctx, shelf.Response response) async =>
      response;
}
