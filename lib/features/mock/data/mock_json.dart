import '../domain/entities/mock_definition.dart';

abstract final class MockJson {
  static MockDefinition decode(Map<String, dynamic> j) => MockDefinition(
    id: j['id'] as String,
    name: j['name'] as String,
    enabled: j['enabled'] as bool,
    method: j['method'] as String,
    path: j['path'] as String,
    scenarios: (j['scenarios'] as List)
        .map(
          (s) => MockScenario(
            id: s['id'] as String,
            name: s['name'] as String,
            statusCode: s['statusCode'] as int,
            delayMs: s['delayMs'] as int,
            bodyType: s['bodyType'] as String,
            body: s['body'] as String,
            headersText: s['headersText'] as String,
            conditions: (s['conditions'] as List)
                .map(
                  (c) => MockCondition(
                    source: MockConditionSource.values.byName(
                      c['source'] as String,
                    ),
                    key: c['key'] as String,
                    expected: c['expected'] as String,
                  ),
                )
                .toList(),
          ),
        )
        .toList(),
  );
  static Map<String, dynamic> encode(MockDefinition d) => {
    'id': d.id,
    'name': d.name,
    'enabled': d.enabled,
    'method': d.method,
    'path': d.path,
    'scenarios': d.scenarios
        .map(
          (s) => {
            'id': s.id,
            'name': s.name,
            'statusCode': s.statusCode,
            'delayMs': s.delayMs,
            'bodyType': s.bodyType,
            'body': s.body,
            'headersText': s.headersText,
            'conditions': s.conditions
                .map(
                  (c) => {
                    'source': c.source.name,
                    'key': c.key,
                    'expected': c.expected,
                  },
                )
                .toList(),
          },
        )
        .toList(),
  };
}
