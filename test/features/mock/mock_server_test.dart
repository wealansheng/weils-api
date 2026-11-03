import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/features/mock/data/io_mock_server.dart';
import 'package:weils_api/features/mock/domain/entities/mock_definition.dart';
import 'package:weils_api/features/mock/domain/use_cases/generate_mock.dart';

void main() {
  late IoMockServer server;
  late HttpClient client;
  late List<MockDefinition> definitions;
  setUp(() async {
    server = IoMockServer();
    client = HttpClient();
    definitions = [];
    await server.start(0, () => definitions);
  });
  tearDown(() async {
    client.close(force: true);
    await server.stop();
    server.dispose();
  });
  Future<({int status, String body, HttpHeaders headers})> call(
    String method,
    String path, {
    String? body,
    Map<String, String> headers = const {},
  }) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.port}$path'),
    );
    headers.forEach(request.headers.set);
    if (body != null) {
      request.contentLength = utf8.encode(body).length;
      request.write(body);
    }
    final response = await request.close();
    return (
      status: response.statusCode,
      body: await utf8.decoder.bind(response).join(),
      headers: response.headers,
    );
  }

  test(
    'real HTTP CRUD, parameters, conditions, headers, status and CORS',
    () async {
      definitions = [
        for (final method in ['GET', 'POST', 'PUT', 'DELETE'])
          MockDefinition(
            method: method,
            path: '/users/:id',
            scenarios: [
              MockScenario(name: 'default', body: '{"result":"fallback"}'),
              MockScenario(
                name: 'admin',
                statusCode: 201,
                headers: {'X-Mock': 'yes'},
                body: '{"id":"@integer(7,7)"}',
                conditions: [
                  const MockCondition(key: 'X-Role', expected: 'admin'),
                  const MockCondition(
                    source: MockConditionSource.body,
                    key: '/id',
                    expected: '7',
                  ),
                ],
              ),
            ],
          ),
      ];
      for (final method in ['GET', 'POST', 'PUT', 'DELETE']) {
        final response = await call(
          method,
          '/users/42?ignore=true',
          body: '{"id":7}',
          headers: {'X-ROLE': 'admin'},
        );
        expect(response.status, 201);
        expect(jsonDecode(response.body)['id'], 7);
        expect(response.headers.value('x-mock'), 'yes');
        expect(response.headers.value('access-control-allow-origin'), '*');
      }
      final fallback = await call(
        'POST',
        '/users/42',
        body: '{"id":"7"}',
        headers: {'X-Role': 'admin'},
      );
      expect(jsonDecode(fallback.body)['result'], 'fallback');
      final options = await call(
        'OPTIONS',
        '/users/42',
        headers: {'Access-Control-Request-Headers': 'x-role, content-type'},
      );
      expect(options.status, 204);
      expect(options.body, isEmpty);
      expect(
        options.headers.value('access-control-allow-headers'),
        'x-role, content-type',
      );
      expect((await call('GET', '/unknown')).status, 404);
      definitions = [
        MockDefinition(
          path: '/no-match',
          scenarios: [
            MockScenario(
              conditions: [const MockCondition(key: 'x', expected: 'y')],
            ),
          ],
        ),
      ];
      expect((await call('GET', '/no-match')).body, contains('场景'));
    },
  );
  test(
    'plain text, fixed routes, empty statuses and template failures',
    () async {
      definitions = [
        MockDefinition(path: '/users/:id'),
        MockDefinition(
          path: '/users/me',
          scenarios: [
            MockScenario(bodyType: 'text', body: 'hello', statusCode: 202),
          ],
        ),
        MockDefinition(
          path: '/empty',
          scenarios: [MockScenario(statusCode: 204)],
        ),
        MockDefinition(
          path: '/invalid',
          scenarios: [MockScenario(body: '{"x":"@unknown"}')],
        ),
      ];
      final fixed = await call('GET', '/users/me');
      expect(fixed.status, 202);
      expect(fixed.body, 'hello');
      expect((await call('GET', '/empty')).body, isEmpty);
      expect((await call('GET', '/invalid')).status, 500);
      definitions = [
        MockDefinition(
          path: '/',
          scenarios: [MockScenario(body: '{"ok":true}')],
        ),
      ];
      expect((await call('GET', '/')).status, 200);
    },
  );
  test('oversized payloads return 413 and generated text is bounded', () async {
    definitions = [MockDefinition()];
    expect(
      (await call('POST', '/users', body: 'x' * (mockMaxBytes + 1))).status,
      413,
    );
    definitions = [
      MockDefinition(
        scenarios: [
          MockScenario(bodyType: 'text', body: 'x' * (mockMaxBytes + 1)),
        ],
      ),
    ];
    expect((await call('GET', '/users')).status, 500);
  });
  test(
    'in-flight requests capture saved configuration before receiving body',
    () async {
      definitions = [
        MockDefinition(
          method: 'POST',
          path: '/snapshot',
          scenarios: [MockScenario(body: '{"value":"old"}')],
        ),
      ];
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port!,
      );
      socket.write(
        'POST /snapshot HTTP/1.1\r\nHost: localhost\r\nContent-Length: 2\r\nConnection: close\r\n\r\n',
      );
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      definitions = [
        definitions.single.copyWith(
          scenarios: [MockScenario(body: '{"value":"new"}')],
        ),
      ];
      socket.write('{}');
      await socket.flush();
      final response = await utf8.decoder.bind(socket).join();
      expect(response, contains('old'));
      expect(response, isNot(contains('new')));
      socket.destroy();
      expect(
        (await call('POST', '/snapshot', body: '{}')).body,
        contains('new'),
      );
    },
  );
  test(
    'port occupation, delay cancellation, repeated stop and release',
    () async {
      final other = IoMockServer();
      await expectLater(
        other.start(server.port!, () => []),
        throwsA(isA<SocketException>()),
      );
      other.dispose();
      definitions = [
        MockDefinition(scenarios: [MockScenario(delayMs: 300000)]),
      ];
      final port = server.port!;
      final pending = call(
        'GET',
        '/users',
      ).then<Object?>((v) => v, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await server.stop().timeout(const Duration(seconds: 2));
      await pending.timeout(const Duration(seconds: 2));
      await server.stop();
      final replacement = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await replacement.close(force: true);
      expect(server.running, false);
    },
  );
}
