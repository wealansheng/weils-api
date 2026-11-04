import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/core/errors/app_failure.dart';
import 'package:weils_api/core/network/http_transport.dart';
import 'package:weils_api/features/workspace/data/data_sources/local_workspace_source.dart';
import 'package:weils_api/features/workspace/data/models/workspace_json.dart';
import 'package:weils_api/features/workspace/data/repositories/http_request_gateway.dart';
import 'package:weils_api/features/workspace/domain/entities/sse_event.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/use_cases/request_headers.dart';

import '../../support/workspace_fixture.dart';

void main() {
  for (final newline in ['\n', '\r', '\r\n']) {
    test('SSE frames split at every character with ${jsonEncode(newline)}', () {
      final events = <SseEvent>[];
      final parser = SseParser(events.add);
      final input =
          '\ufeff: ping${newline}id: 7${newline}event: update$newline'
          'data: 中文${newline}data:  second$newline$newline'
          'unknown: ignored${newline}retry: 100${newline}data:$newline$newline'
          'id: bad\u0000id${newline}data: inherited$newline$newline'
          'id:$newline${newline}data: [DONE]$newline$newline'
          'data: unfinished$newline';
      for (final unit in input.codeUnits) {
        parser.add(String.fromCharCode(unit));
      }
      expect(events.map((e) => e.data), [
        '中文\n second',
        '',
        'inherited',
        '[DONE]',
      ]);
      expect(events.map((e) => e.type), [
        'update',
        'message',
        'message',
        'message',
      ]);
      expect(events.map((e) => e.id), ['7', '7', '7', '']);
    });
  }

  test('comments and id-only blocks do not dispatch; event type resets', () {
    final events = SseParser.parse(
      ': heartbeat\n\nevent: ignored\n\nid: 42\n\ndata: yes\n\n',
    );
    expect(events, hasLength(1));
    expect(events.single.type, 'message');
    expect(events.single.id, '42');
  });

  test('default Accept is visible, overridable and mode-specific', () {
    List<DefaultHeader> headers(RequestSpec request) =>
        defaultRequestHeaders(request, userAgent: 'test');
    expect(headers(RequestSpec()).where((h) => h.name == 'Accept'), isEmpty);
    expect(
      headers(RequestSpec(protocol: 'sse'))
          .singleWhere((h) => h.name == 'Accept')
          .value,
      'text/event-stream',
    );
    expect(
      headers(
        RequestSpec(
          protocol: 'sse',
          headers: [Entry(name: 'aCcEpT', value: 'custom')],
        ),
      ).where((h) => h.name == 'Accept'),
      isEmpty,
    );
  });

  test(
    'byte updates decode split UTF-8 and coalesce progress until 100 ms',
    () async {
      final transport = _ChunkedTransport();
      final task = HttpRequestGateway(transport).start(
        RequestSpec(protocol: 'sse', url: 'http://localhost'),
        timeout: const Duration(seconds: 2),
      );
      final updates = <ResponseRecord>[];
      final subscription = task.updates.listen(updates.add);
      transport.chunks.add(
        const TransportUpdate(
          statusCode: 200,
          reason: 'OK',
          headers: {'content-type': 'text/event-stream'},
          streaming: true,
        ),
      );
      final bytes = utf8.encode('data: 中文🌟\n\n');
      for (final byte in bytes) {
        transport.chunks.add(
          TransportUpdate(
            statusCode: 200,
            reason: 'OK',
            headers: const {'content-type': 'text/event-stream'},
            streaming: true,
            bytes: [byte],
          ),
        );
      }
      expect(updates, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 130));
      expect(updates, hasLength(1));
      expect(updates.single.sseData, '中文🌟');
      transport.result.complete(
        TransportResponse(statusCode: 200, body: utf8.decode(bytes)),
      );
      final finalRecord = await task.result;
      await Future<void>.delayed(Duration.zero);
      expect(finalRecord.sseData, '中文🌟');
      expect(updates, hasLength(2));
      await subscription.cancel();
      await transport.chunks.close();
    },
  );

  late HttpServer server;
  late String url;
  Future<void> serve(Future<void> Function(HttpRequest) handler) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'http://127.0.0.1:${server.port}/events';
    server.listen((request) async {
      try {
        request.response.bufferOutput = false;
        await handler(request);
      } on HttpException {
        /* The client can stop a streaming response. */
      } on SocketException {
        /* The client can stop a streaming response. */
      }
    });
    addTearDown(() => server.close(force: true));
  }

  test('POST stream sends JSON, query and bearer; first event arrives before close', () async {
    final hold = Completer<void>();
    addTearDown(() {
      if (!hold.isCompleted) hold.complete();
    });
    String? wireBody, method, auth, accept, query;
    await serve((request) async {
      method = request.method;
      auth = request.headers.value('authorization');
      accept = request.headers.value('accept');
      query = request.uri.queryParameters['q'];
      wireBody = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      final bytes = utf8.encode('id: 1\nevent: delta\ndata: 中文🌟\n\n');
      for (final byte in bytes) {
        request.response.add([byte]);
        await request.response.flush();
      }
      await hold.future;
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });
    final task = HttpRequestGateway(IoHttpTransport()).start(
      RequestSpec(
        protocol: 'sse',
        method: 'POST',
        url: url,
        params: [Entry(name: 'q', value: '中文')],
        bodyType: 'json',
        body: '{"stream":true}',
        authType: 'bearer',
        token: 'secret',
      ),
      timeout: const Duration(seconds: 2),
    );
    var finished = false;
    unawaited(task.result.then((_) => finished = true));
    final update = await task.updates
        .firstWhere((r) => r.sseEvents.isNotEmpty)
        .timeout(const Duration(seconds: 5));
    expect(finished, isFalse);
    expect(update.sseEvents.single.data, '中文🌟');
    expect(update.statusCode, 200);
    expect(
      [method, auth, accept, query, wireBody],
      ['POST', 'Bearer secret', 'text/event-stream', '中文', '{"stream":true}'],
    );
    hold.complete();
    final finalRecord = await task.result;
    expect(finalRecord.sseData, '中文🌟[DONE]');
    expect(finalRecord.sseEvents.last.type, 'message');
    expect(finalRecord.failure, isNull);
  });

  test('connected stream outlives timeout without events; cancel retains heartbeat', () async {
    final hold = Completer<void>();
    addTearDown(() {
      if (!hold.isCompleted) hold.complete();
    });
    await serve((request) async {
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(': heartbeat\n\n');
      await request.response.flush();
      await hold.future;
      await request.response.close();
    });
    final task = HttpRequestGateway(IoHttpTransport()).start(
      RequestSpec(protocol: 'sse', url: url),
      timeout: const Duration(milliseconds: 250),
    );
    await task.updates
        .firstWhere((r) => r.isSse)
        .timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    task.cancel();
    task.cancel();
    final result = await task.result;
    expect(result.cancelled, true);
    expect(result.failure, isNull);
    expect(result.body, ': heartbeat\n\n');
    expect(result.sseEvents, isEmpty);
    expect(result.headers['content-type'], contains('text/event-stream'));
  });

  test('waiting for response headers times out', () async {
    final hold = Completer<void>();
    addTearDown(() {
      if (!hold.isCompleted) hold.complete();
    });
    await serve((request) async {
      await hold.future;
      await request.response.close();
    });
    final result = await HttpRequestGateway(IoHttpTransport())
        .start(
          RequestSpec(protocol: 'sse', url: url),
          timeout: const Duration(milliseconds: 100),
        )
        .result;
    expect(result.failure!.code, FailureCode.timeout);
    expect(result.isSse, false);
    expect(result.sseRequested, true);
  });

  for (final item in [
    (200, 'application/json'),
    (401, 'text/event-stream'),
    (204, 'text/event-stream'),
  ]) {
    test('non-SSE fallback preserves ${item.$1} ${item.$2}', () async {
      await serve((request) async {
        request.response.statusCode = item.$1;
        request.response.headers.set('content-type', item.$2);
        if (item.$1 != 204) {
          request.response.write('{"error":"details"}');
        }
        await request.response.close();
      });
      final result = await HttpRequestGateway(IoHttpTransport())
          .start(
            RequestSpec(protocol: 'sse', url: url),
            timeout: const Duration(seconds: 2),
          )
          .result;
      expect(result.statusCode, item.$1);
      expect(result.isSse, false);
      expect(result.sseRequested, true);
      expect(result.body, item.$1 == 204 ? '' : '{"error":"details"}');
    });
  }

  test('non-SSE fallback cannot wait indefinitely for body', () async {
    final hold = Completer<void>();
    addTearDown(() {
      if (!hold.isCompleted) hold.complete();
    });
    await serve((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write('{');
      await request.response.flush();
      await hold.future;
      await request.response.close();
    });
    final result = await HttpRequestGateway(IoHttpTransport())
        .start(
          RequestSpec(protocol: 'sse', url: url),
          timeout: const Duration(milliseconds: 150),
        )
        .result;
    expect(result.failure!.code, FailureCode.timeout);
    expect(result.body, '{');
  });

  test(
    'ordinary HTTP charset handling is unchanged by streaming support',
    () async {
      await serve((request) async {
        if (request.uri.path == '/latin1') {
          request.response.headers.set(
            'content-type',
            'text/plain; charset=iso-8859-1',
          );
          request.response.add(latin1.encode('é'));
        } else {
          request.response.headers.set(
            'content-type',
            'text/plain; charset=utf-8; profile=latin1',
          );
          request.response.add(utf8.encode('é'));
        }
        await request.response.close();
      });
      for (final path in ['latin1', 'utf8']) {
        final result = await HttpRequestGateway(IoHttpTransport())
            .start(
              RequestSpec(
                url: '${url.substring(0, url.lastIndexOf('/'))}/$path',
              ),
              timeout: const Duration(seconds: 2),
            )
            .result;
        expect(result.body, 'é');
        expect(result.sseRequested, false);
      }
    },
  );

  test('SSE configurable cap closes with partial raw data preserved', () async {
    await serve((request) async {
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: first\n\ndata: ${'a' * (1024 * 1024 + 100)}\n\n',
      );
      await request.response.close();
    });
    final result = await HttpRequestGateway(IoHttpTransport())
        .start(
          RequestSpec(protocol: 'sse', url: url),
          sseMaxResponseMb: 1,
          timeout: const Duration(seconds: 5),
        )
        .result;
    expect(result.truncated, true);
    expect(utf8.encode(result.body), hasLength(1024 * 1024));
    expect(result.captureLimitBytes, 1024 * 1024);
    expect(result.sseEvents.single.data, 'first');
  });

  test(
    'disconnect retains events and response metadata without reconnecting',
    () async {
      var calls = 0;
      await serve((request) async {
        calls++;
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.write(
          'HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nContent-Length: 10000\r\nConnection: close\r\n\r\ndata: retained\n\n',
        );
        await socket.flush();
        socket.destroy();
      });
      final result = await HttpRequestGateway(IoHttpTransport())
          .start(
            RequestSpec(protocol: 'sse', url: url),
            timeout: const Duration(seconds: 2),
          )
          .result;
      expect(result.sseData, 'retained');
      expect(result.statusCode, 200);
      expect(
        result.failure?.code,
        isIn([FailureCode.interrupted, FailureCode.connection]),
      );
      expect(calls, 1);
    },
  );

  test(
    'execution survives tab switch, stops and appends exactly one history',
    () async {
      final hold = Completer<void>();
      addTearDown(() {
        if (!hold.isCompleted) hold.complete();
      });
      await serve((request) async {
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write('data: live\n\n');
        await request.response.flush();
        await hold.future;
        await request.response.close();
      });
      final storage = MemoryStorage();
      final fixture = WorkspaceFixture(storage: storage);
      addTearDown(fixture.dispose);
      await fixture.initialize();
      final request = fixture.create(RequestSpec(protocol: 'sse', url: url));
      final execution = fixture.dependencies.execution;
      final ready = Completer<void>();
      execution.addListener(() {
        if (!ready.isCompleted &&
            execution.responseFor(request.id)?.sseData == 'live') {
          ready.complete();
        }
      });
      final sending = execution.send(request);
      await ready.future.timeout(const Duration(seconds: 5));
      expect(fixture.history, isEmpty);
      fixture.newRequest();
      expect(execution.runningId, request.id);
      expect(
        (await fixture.repository.updateSettings(
          timeout: 30,
          sseMaxResponseMb: 1,
        )).succeeded,
        true,
      );
      await execution.stop();
      await sending;
      expect(execution.running, false);
      expect(fixture.history, hasLength(1));
      expect(fixture.history.single.response.sseData, 'live');
      expect(
        fixture.history.single.response.captureLimitBytes,
        2 * 1024 * 1024,
      );
      expect(fixture.history.single.response.cancelled, true);
      final replayed = fixture.replay(fixture.history.single);
      expect(replayed.protocol, 'sse');
      expect(replayed.id, isNot(request.id));
      final restored = WorkspaceJson.decode(storage.data!);
      expect(restored.history.single.response.sseData, 'live');
    },
  );

  test('settings and SSE history survive actual storage restart, defaults stay v1 compatible', () async {
    final directory = await Directory.systemTemp.createTemp('weils-sse-');
    addTearDown(() => directory.delete(recursive: true));
    final source = LocalWorkspaceSource(directory: directory);
    final fixture = WorkspaceFixture(storage: source);
    addTearDown(fixture.dispose);
    await fixture.initialize();
    final request = fixture.create(
      RequestSpec(
        protocol: 'sse',
        method: 'POST',
        url: 'http://localhost/events',
      ),
    );
    await fixture.save(request);
    final response = ResponseRecord(
      statusCode: 200,
      body: 'id: x\ndata: saved\n\n',
      isSse: true,
      sseRequested: true,
      captureLimitBytes: 8 * 1024 * 1024,
      cancelled: true,
    );
    fixture.appendHistory(HistoryRecord(request: request, response: response));
    expect(
      (await fixture.repository.updateSettings(
        timeout: 12,
        sseMaxResponseMb: 8,
      )).succeeded,
      true,
    );
    final encoded =
        jsonDecode(await source.file.readAsString()) as Map<String, dynamic>;
    expect(encoded['version'], 1);
    expect(encoded['history'][0]['response'].containsKey('sseEvents'), false);
    final restored = WorkspaceJson.decode(
      (await LocalWorkspaceSource(directory: directory).read())!,
    );
    expect(restored.requests.single.protocol, 'sse');
    expect(restored.sseMaxResponseMb, 8);
    expect(restored.history.single.response.sseEvents.single.id, 'x');
    expect(restored.history.single.response.cancelled, true);
    for (final invalid in [0, 51]) {
      expect(
        (await fixture.repository.updateSettings(
          timeout: 30,
          sseMaxResponseMb: invalid,
        )).succeeded,
        false,
      );
      expect(fixture.snapshot.sseMaxResponseMb, 8);
    }
    final defaults = WorkspaceJson.encode(WorkspaceSnapshot());
    expect(defaults.containsKey('sseMaxResponseMb'), false);
    expect(
      WorkspaceJson.requestJson(RequestSpec()).containsKey('protocol'),
      false,
    );
    expect(
      WorkspaceJson.responseJson(ResponseRecord()).containsKey('isSse'),
      false,
    );
  });
}

class _ChunkedTransport implements HttpTransport {
  final chunks = StreamController<TransportUpdate>(sync: true);
  final result = Completer<TransportResponse>();
  @override
  TransportTask start(TransportRequest request, {required Duration timeout}) =>
      TransportTask(() {}, result.future, updates: chunks.stream);
}
