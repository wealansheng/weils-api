import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/features/mock/data/io_mock_server.dart';
import 'package:weils_api/features/mock/domain/entities/mock_definition.dart';
import 'package:weils_api/features/mock/domain/use_cases/generate_mock.dart';
import 'package:weils_api/features/mock/domain/use_cases/match_mock.dart';
import 'package:weils_api/features/mock/domain/use_cases/render_path_values.dart';

void main() {
  test(
    'terminal wildcard matches any prefix and captures all remaining segments',
    () {
      for (final prefix in ['user', 'xxx', 'a/b', '中文/路径']) {
        final definition = MockDefinition(path: '/$prefix/*');
        validateMockDefinition(definition, []);
        final result = resolveMockRoute(
          [definition],
          'GET',
          [...prefix.split('/'), 'one', 'two'],
        );
        expect(result?.definition, definition);
        expect(result?.pathParameters['*'], 'one/two');
        expect(
          resolveMockRoute([definition], 'POST', [...prefix.split('/'), 'one']),
          isNull,
        );
        expect(resolveMockRoute([definition], 'GET', ['other', 'one']), isNull);
        expect(
          resolveMockRoute(
            [definition.copyWith(enabled: false)],
            'GET',
            [...prefix.split('/'), 'one'],
          ),
          isNull,
        );
      }
      final wildcard = MockDefinition(path: '/user/*');
      expect(
        resolveMockRoute([wildcard], 'GET', ['user', ''])?.pathParameters['*'],
        '',
      );
      expect(resolveMockRoute([wildcard], 'GET', ['user']), isNull);
      expect(
        resolveMockRoute(
          [MockDefinition(path: '/*')],
          'GET',
          [],
        )?.pathParameters['*'],
        '',
      );
    },
  );

  test('captures named parameters together with the wildcard and preserves precedence', () {
    final catchAll = MockDefinition(path: '/*');
    final wildcard = MockDefinition(path: '/user/*');
    final named = MockDefinition(path: '/user/:id');
    final fixed = MockDefinition(path: '/user/me');
    final routes = [catchAll, wildcard, named, fixed];
    expect(resolveMockRoute(routes, 'GET', ['user', 'me'])?.definition, fixed);
    expect(resolveMockRoute(routes, 'GET', ['user', '42'])?.definition, named);
    expect(
      resolveMockRoute(routes, 'GET', ['user', '42', 'files'])?.definition,
      wildcard,
    );
    expect(
      resolveMockRoute(routes, 'GET', ['other', 'files'])?.definition,
      catchAll,
    );
    final mixed = MockDefinition(path: '/teams/:team/*');
    final result = resolveMockRoute(
      [mixed],
      'GET',
      ['teams', 'red', 'users', '42'],
    )!;
    expect(result.pathParameters, {'team': 'red', '*': 'users/42'});
    expect(() => result.pathParameters.clear(), throwsUnsupportedError);
    expect(
      resolveMockRoute(
        [catchAll, MockDefinition(path: '/')],
        'GET',
        [],
      )?.definition.path,
      '/',
    );
  });

  test('invalid wildcard placement and undefined response path references fail before save', () {
    for (final path in ['/user/p*', '/user/*/next', '/user/**', '/user/:id*']) {
      expect(
        () => validateMockDefinition(MockDefinition(path: path), []),
        throwsA(isA<MockValidationException>()),
      );
    }
    final wildcard = MockDefinition(
      path: '/user/*',
      scenarios: [MockScenario(body: '{"value":"{{path.*}}"}')],
    );
    validateMockDefinition(wildcard, []);
    expect(
      () => validateMockDefinition(wildcard.copyWith(name: 'duplicate'), [
        MockDefinition(path: '/user/*'),
      ]),
      throwsA(isA<MockValidationException>()),
    );
    expect(
      () => validateMockDefinition(wildcard.copyWith(path: '/user/:id'), []),
      throwsA(isA<MockValidationException>()),
    );
    validateMockDefinition(
      MockDefinition(
        path: '/user/:id',
        scenarios: [MockScenario(body: '{"id":"{{path.id}}"}')],
      ),
      [],
    );
  });

  test(
    'JSON substitution safely escapes captured data without evaluating it',
    () {
      final generator = MockGenerator();
      const captured = 'a"b\nc\\d/@unknown/{{path.id}}';
      final template = jsonEncode({
        'value': '{{path.*}}',
        'message': 'value={{path.*}}; number=@integer(1,1)',
        'rows|2-2': [
          {'tail': '{{path.*}}'},
        ],
      });
      final result = jsonDecode(
        generator.generate(template, pathParameters: {'*': captured}),
      );
      expect(result['value'], captured);
      expect(result['message'], 'value=$captured; number=1');
      expect((result['rows'] as List).map((r) => r['tail']), [
        captured,
        captured,
      ]);
      expect(
        jsonDecode(generator.generate('{"value":"{{path.*}}"}'))['value'],
        '{{path.*}}',
      );
      expect(
        () => generator.generate(template, pathParameters: {}),
        throwsA(isA<MockValidationException>()),
      );
      expect(
        renderMockPathValues('path={{path.*}}', {
          '*': captured,
        }, maximumBytes: mockMaxBytes),
        'path=$captured',
      );
    },
  );

  test('path expansion obeys the response size bound in text and mixed JSON templates', () {
    final source = '{{path.*}}' * 1000;
    final parameters = {'*': 'x' * 3000};
    expect(
      () =>
          renderMockPathValues(source, parameters, maximumBytes: mockMaxBytes),
      throwsA(isA<MockValidationException>()),
    );
    final mixed = '{{path.*}}@integer(1,1)' * 1000;
    expect(
      () => MockGenerator().generate(
        jsonEncode(mixed),
        pathParameters: parameters,
      ),
      throwsA(isA<MockValidationException>()),
    );
  });

  test('real HTTP requests echo generic wildcards and named parameters in JSON and text', () async {
    final server = IoMockServer();
    final client = HttpClient();
    final definitions = [
      MockDefinition(
        path: '/user/*',
        scenarios: [
          MockScenario(body: '{"value":"{{path.*}}","number":"@integer(1,1)"}'),
        ],
      ),
      MockDefinition(
        path: '/xxx/*',
        scenarios: [
          MockScenario(bodyType: 'text', body: 'captured={{path.*}}'),
        ],
      ),
      MockDefinition(
        path: '/a/b/*',
        scenarios: [MockScenario(body: '{"value":"{{path.*}}"}')],
      ),
      MockDefinition(
        path: '/teams/:id/*',
        scenarios: [
          MockScenario(body: '{"id":"{{path.id}}","tail":"{{path.*}}"}'),
        ],
      ),
      MockDefinition(
        path: '/user/me',
        scenarios: [MockScenario(bodyType: 'text', body: 'fixed')],
      ),
    ];
    await server.start(0, () => definitions);
    Future<String> get(String path) async {
      final request = await client.getUrl(
        Uri.http('127.0.0.1:${server.port}', path),
      );
      final response = await request.close();
      expect(response.statusCode, 200);
      return utf8.decoder.bind(response).join();
    }

    try {
      expect(jsonDecode(await get('/user/abc/123')), {
        'value': 'abc/123',
        'number': 1,
      });
      expect(await get('/xxx/中文/详情'), 'captured=中文/详情');
      expect(jsonDecode(await get('/a/b/x'))['value'], 'x');
      expect(jsonDecode(await get('/teams/red/users/42')), {
        'id': 'red',
        'tail': 'users/42',
      });
      expect(await get('/user/me'), 'fixed');
      expect(jsonDecode(await get('/user/'))['value'], '');
      expect(
        jsonDecode(await get('/user/a"b\\c/@unknown'))['value'],
        'a"b\\c/@unknown',
      );
      final parallel = await Future.wait([
        get('/user/first'),
        get('/user/second'),
      ]);
      expect(parallel.map((body) => jsonDecode(body)['value']), [
        'first',
        'second',
      ]);
    } finally {
      client.close(force: true);
      await server.stop();
      server.dispose();
    }
  });
}
