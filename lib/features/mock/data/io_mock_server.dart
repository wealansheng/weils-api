import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/entities/mock_definition.dart';
import '../domain/repositories/mock_server.dart';
import '../domain/use_cases/generate_mock.dart';
import '../domain/use_cases/match_mock.dart';

class IoMockServer implements MockServer {
  HttpServer? _server;
  final _pending = <HttpResponse>{};
  final _delays = <Timer, Completer<void>>{};
  int _generation = 0;
  bool _disposed = false, _starting = false;
  @override
  bool get running => _server != null;
  @override
  int? get port => _server?.port;
  @override
  Future<void> start(
    int port,
    List<MockDefinition> Function() definitions,
  ) async {
    if (_disposed || running || _starting) {
      throw StateError('Mock server unavailable');
    }
    _starting = true;
    final generation = ++_generation;
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      if (_disposed || generation != _generation) {
        await server.close(force: true);
        return;
      }
      _server = server;
      server.listen((request) {
        // Capture the immutable saved definitions before any asynchronous work.
        final snapshot = List<MockDefinition>.of(definitions());
        unawaited(_handle(request, snapshot, generation));
      });
    } finally {
      _starting = false;
    }
  }

  Future<void> _handle(
    HttpRequest request,
    List<MockDefinition> definitions,
    int generation,
  ) async {
    final response = request.response;
    _pending.add(response);
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, DELETE, OPTIONS',
    );
    final requestedHeaders = request.headers.value(
      'access-control-request-headers',
    );
    response.headers.set(
      'Access-Control-Allow-Headers',
      requestedHeaders ?? '*',
    );
    response.headers.set('Access-Control-Expose-Headers', '*');
    void error(int status, String message) {
      if (generation != _generation) return;
      try {
        response.statusCode = status;
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({'message': message}));
      } on Object {
        /* The client may already have disconnected. */
      }
    }

    try {
      if (request.method == 'OPTIONS') {
        response.statusCode = 204;
        return;
      }
      var tooLarge = request.contentLength > mockMaxBytes;
      final bytes = <int>[];
      await for (final chunk in request.timeout(const Duration(seconds: 30))) {
        if (bytes.length + chunk.length > mockMaxBytes) {
          tooLarge = true;
          bytes.clear();
        }
        if (!tooLarge) bytes.addAll(chunk);
      }
      if (generation != _generation) return;
      if (tooLarge) {
        error(413, '请求正文超过 2 MB');
        return;
      }
      final segments = request.uri.path == '/'
          ? <String>[]
          : request.uri.pathSegments;
      final route = matchMockRoute(definitions, request.method, segments);
      if (route == null) {
        error(404, '未找到匹配的 Mock 路由');
        return;
      }
      final headers = <String, String>{};
      request.headers.forEach(
        (name, values) => headers[name] = values.join(', '),
      );
      final scenario = matchMockScenario(
        route,
        headers,
        utf8.decode(bytes, allowMalformed: true),
      );
      if (scenario == null) {
        error(404, '路由已匹配，但没有满足条件的响应场景');
        return;
      }
      final body = scenario.bodyType == 'json'
          ? MockGenerator().generate(scenario.body)
          : scenario.body;
      final payload = utf8.encode(body);
      if (payload.length > mockMaxBytes) {
        error(500, '生成正文超过 2 MB');
        return;
      }
      if (scenario.delayMs > 0) {
        final completer = Completer<void>();
        late final Timer timer;
        timer = Timer(Duration(milliseconds: scenario.delayMs), () {
          _delays.remove(timer);
          completer.complete();
        });
        _delays[timer] = completer;
        await completer.future;
      }
      if (generation != _generation) return;
      response.statusCode = scenario.statusCode;
      response.headers.contentType = scenario.bodyType == 'json'
          ? ContentType.json
          : ContentType('text', 'plain', charset: 'utf-8');
      for (final entry in scenario.headers.entries) {
        response.headers.set(entry.key, entry.value);
      }
      if (scenario.statusCode != 204 && scenario.statusCode != 304) {
        response.add(payload);
      }
    } on TimeoutException {
      error(408, '读取请求正文超时');
    } on MockValidationException catch (e) {
      error(500, e.message);
    } on Object catch (_) {
      // A disconnected caller must never escape into Flutter's error zone.
      try {
        error(500, 'Mock 请求处理失败');
      } on Object catch (_) {
        /* closed response */
      }
    } finally {
      try {
        await response.close();
      } on Object catch (_) {
        /* client disconnected */
      }
      _pending.remove(response);
    }
  }

  @override
  Future<void> stop() async {
    ++_generation;
    final server = _server;
    _server = null;
    for (final entry in _delays.entries) {
      entry.key.cancel();
      entry.value.complete();
    }
    _delays.clear();
    await server?.close(force: true);
    _pending.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
  }
}
