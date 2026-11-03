import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/features/mock/domain/entities/mock_definition.dart';
import 'package:weils_api/features/mock/domain/use_cases/generate_mock.dart';
import 'package:weils_api/features/mock/domain/use_cases/match_mock.dart';

void main() {
  test(
    'fixed segments take priority and route shapes cannot be duplicated',
    () {
      final parameter = MockDefinition(path: '/users/:id');
      final fixed = MockDefinition(path: '/users/me');
      expect(matchMockRoute([parameter, fixed], 'GET', ['users', 'me']), fixed);
      expect(
        matchMockRoute([fixed, parameter], 'GET', ['users', '123']),
        parameter,
      );
      expect(
        matchMockRoute([fixed, parameter], 'POST', ['users', 'me']),
        isNull,
      );
      expect(
        matchMockRoute(
          [fixed.copyWith(enabled: false)],
          'GET',
          ['users', 'me'],
        ),
        isNull,
      );
      expect(
        () => validateMockDefinition(MockDefinition(path: '/users/:name'), [
          parameter,
        ]),
        throwsA(isA<MockValidationException>()),
      );
      for (final path in [
        'users',
        '/users/',
        '/x//y',
        '/:a/:a',
        '/:1',
        '/users?q=1',
        '/a%20b',
      ]) {
        expect(
          () => validateMockDefinition(MockDefinition(path: path), []),
          throwsA(isA<MockValidationException>()),
          reason: path,
        );
      }
      final a = MockDefinition(path: '/:type/details');
      final b = MockDefinition(path: '/users/:id');
      expect(matchMockRoute([a, b], 'GET', ['users', 'details']), b);
      expect(matchMockRoute([MockDefinition(path: '/')], 'GET', []), isNotNull);
    },
  );

  test(
    'Header and JSON Pointer conditions use AND and default is always last',
    () {
      final fallback = MockScenario();
      final matched = MockScenario(
        name: 'admin',
        conditions: [
          const MockCondition(key: 'X-Role', expected: 'admin'),
          const MockCondition(
            source: MockConditionSource.body,
            key: '/a~1b/0/~0x',
            expected: '1',
          ),
        ],
      );
      final route = MockDefinition(scenarios: [fallback, matched]);
      expect(
        matchMockScenario(route, {'x-role': 'admin'}, '{"a/b":[{"~x":1}]}'),
        matched,
      );
      expect(
        matchMockScenario(route, {'X-ROLE': 'admin'}, '{"a/b":[{"~x":"1"}]}'),
        fallback,
      );
      expect(
        matchMockScenario(route, {'x-role': 'Admin'}, '{"a/b":[{"~x":1}]}'),
        fallback,
      );
      expect(
        matchMockScenario(route, {'x-role': 'admin'}, 'not json'),
        fallback,
      );
      final missing = MockDefinition(
        scenarios: [
          MockScenario(
            conditions: [
              const MockCondition(
                source: MockConditionSource.body,
                key: '/missing',
                expected: 'null',
              ),
            ],
          ),
        ],
      );
      expect(matchMockScenario(missing, {}, '{}'), isNull);
      final deep = MockScenario(
        conditions: [
          const MockCondition(
            source: MockConditionSource.body,
            key: '',
            expected: '{"b":[true,null],"a":1}',
          ),
        ],
      );
      expect(
        matchMockScenario(
          MockDefinition(scenarios: [deep]),
          {},
          '{"a":1,"b":[true,null]}',
        ),
        deep,
      );
    },
  );

  test('templates preserve types and increments reset for each generation', () {
    final generator = MockGenerator(
      random: Random(7),
      now: () => DateTime(2026, 11, 3),
    );
    final template = jsonEncode({
      'users|3-3': [
        {
          'id|+1': 10,
          'name': '@cname',
          'age': '@integer(18, 60)',
          'active': '@boolean',
          'guid': '@guid',
          'email': '@email',
          'date': '@date("yyyy-MM-dd")',
        },
      ],
      'role|1': ['admin', 'user'],
      'text': 'value=@integer(1,1)',
      'word|2': 'a',
      'decimal|1-1.2-2': 1.0,
      'enabled|1-0': true,
      'sample|1': {'a': 1, 'b': 2},
      'pick': '@pick(["a", "b"])',
      'letters': '@string("lower", 4)',
      'english': '@name',
      'natural': '@natural(0,0)',
      'float': '@float(1,1,2,2)',
      'time': '@time',
      'datetime': '@datetime',
    });
    for (var run = 0; run < 2; run++) {
      final result = jsonDecode(generator.generate(template));
      expect((result['users'] as List).map((u) => u['id']), [10, 11, 12]);
      for (final user in result['users']) {
        expect(user['age'], inInclusiveRange(18, 60));
        expect(user['active'], isA<bool>());
        expect(
          user['guid'],
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(user['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      }
      expect(result['role'], anyOf('admin', 'user'));
      expect(result['text'], 'value=1');
      expect(result['word'], 'aa');
      expect(result['enabled'], true);
      expect(result['sample'], hasLength(1));
      expect(result['letters'], matches(RegExp(r'^[a-z]{4}$')));
      expect(result['natural'], 0);
    }
    final sequential = jsonDecode(
      generator.generate('{"rows|3-3":[{"value|+1":["a","b"]}]}'),
    );
    expect((sequential['rows'] as List).map((v) => v['value']), [
      'a',
      'b',
      'a',
    ]);
    expect(jsonDecode(generator.generate('"@pick([1,2], 2)"')), hasLength(2));
    expect(jsonDecode(generator.generate('"@string(2,2)"')), hasLength(2));
    expect(jsonDecode(generator.generate('"@boolean(1,0,true)"')), true);
    expect(
      jsonDecode(generator.generate(jsonEncode("@pick(['it\\'s','x'])"))),
      anyOf("it's", 'x'),
    );
  });

  test('unsupported rules and bounded generation fail explicitly', () {
    final generator = MockGenerator(random: Random(1));
    for (final template in [
      'not json',
      '{"x":"@unknown"}',
      '{"x|1001":[]}',
      '{"x|1-1001":[0]}',
      '{"x|2-1":0}',
      '{"x|1.13":0}',
      '{"x|+0":1}',
      '{"x":"@integer(2,1)"}',
      '{"x":"@pick([])"}',
      '{"x":"@boolean(0,0,true)"}',
      '{"x":"@integer(1"}',
      '{"x|1":["ok", "@unknown"]}',
      '{"x|1":{"a":"ok","b":"@unknown"}}',
      '{"x|1":null}',
      '{"x":"@/other"}',
      '{"x|+1":[]}',
      '{"x":1,"x|2":2}',
    ]) {
      expect(
        () => generator.generate(template),
        throwsA(isA<MockValidationException>()),
        reason: template,
      );
    }
    expect(
      () => generator.generate('${'[' * 34}0${']' * 34}'),
      throwsA(isA<MockValidationException>()),
    );
    expect(
      () => generator.generate(jsonEncode({'x|1000': 'a' * 3000})),
      throwsA(isA<MockValidationException>()),
    );
    expect(
      () => generator.generate('{"x|1000-1000":[{"y|1000-1000":[0]}]}'),
      throwsA(isA<MockValidationException>()),
    );
    final nestedPick = '@pick([${'[' * 34}0${']' * 34}])';
    expect(
      () => generator.generate(jsonEncode(nestedPick)),
      throwsA(isA<MockValidationException>()),
    );
    final oversizedPick = '@pick([${jsonEncode(List.filled(1001, 0))}])';
    expect(
      () => generator.generate(jsonEncode(oversizedPick)),
      throwsA(isA<MockValidationException>()),
    );
  });

  test('response and condition validation rejects invalid data but drafts are immutable', () {
    final conditions = <MockCondition>[];
    final definition = MockDefinition(
      scenarios: [MockScenario(conditions: conditions)],
    );
    conditions.add(const MockCondition());
    expect(definition.scenarios.single.conditions, isEmpty);
    expect(() => definition.scenarios.clear(), throwsUnsupportedError);
    for (final scenario in [
      MockScenario(statusCode: 199),
      MockScenario(delayMs: -1),
      MockScenario(headers: {'Content-Length': '1'}),
      MockScenario(headers: {'Bad Header': 'x'}),
      MockScenario(headersText: '{'),
      MockScenario(
        conditions: [
          const MockCondition(
            source: MockConditionSource.body,
            key: 'id',
            expected: '1',
          ),
        ],
      ),
      MockScenario(
        conditions: [
          const MockCondition(
            source: MockConditionSource.body,
            key: '/id',
            expected: 'admin',
          ),
        ],
      ),
    ]) {
      expect(
        () => validateMockDefinition(MockDefinition(scenarios: [scenario]), []),
        throwsA(isA<MockValidationException>()),
      );
    }
  });
}
