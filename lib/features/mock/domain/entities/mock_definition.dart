import 'dart:convert';

import '../../../../core/utils/identity.dart';

enum MockConditionSource { header, body }

class MockCondition {
  const MockCondition({
    this.source = MockConditionSource.header,
    this.key = '',
    this.expected = '',
  });
  final MockConditionSource source;
  final String key;

  /// Header text, or a JSON encoded value for a Body condition.
  final String expected;
  MockCondition copyWith({
    MockConditionSource? source,
    String? key,
    String? expected,
  }) => MockCondition(
    source: source ?? this.source,
    key: key ?? this.key,
    expected: expected ?? this.expected,
  );
  @override
  bool operator ==(Object other) =>
      other is MockCondition &&
      source == other.source &&
      key == other.key &&
      expected == other.expected;
  @override
  int get hashCode => Object.hash(source, key, expected);
}

class MockScenario {
  MockScenario({
    String? id,
    this.name = '默认响应',
    List<MockCondition> conditions = const [],
    this.statusCode = 200,
    Map<String, String> headers = const {},
    String? headersText,
    this.bodyType = 'json',
    this.body = '{\n  "message": "ok"\n}',
    this.delayMs = 0,
  }) : id = id ?? newId(),
       conditions = List.unmodifiable(conditions),
       headersText =
           headersText ?? const JsonEncoder.withIndent('  ').convert(headers);
  final String id, name, bodyType, body, headersText;
  final List<MockCondition> conditions;
  final int statusCode, delayMs;
  Map<String, String> get headers {
    try {
      return Map.unmodifiable(
        Map<String, String>.from(jsonDecode(headersText) as Map),
      );
    } on Object {
      throw const MockValidationException('响应 Headers 须为名称和值均为字符串的 JSON 对象');
    }
  }

  bool get isDefault => conditions.isEmpty;
  MockScenario copyWith({
    String? name,
    List<MockCondition>? conditions,
    int? statusCode,
    Map<String, String>? headers,
    String? headersText,
    String? bodyType,
    String? body,
    int? delayMs,
  }) => MockScenario(
    id: id,
    name: name ?? this.name,
    conditions: conditions ?? this.conditions,
    statusCode: statusCode ?? this.statusCode,
    headersText:
        headersText ??
        (headers == null
            ? this.headersText
            : const JsonEncoder.withIndent('  ').convert(headers)),
    bodyType: bodyType ?? this.bodyType,
    body: body ?? this.body,
    delayMs: delayMs ?? this.delayMs,
  );
  @override
  bool operator ==(Object other) =>
      other is MockScenario &&
      id == other.id &&
      name == other.name &&
      sameItems(conditions, other.conditions) &&
      statusCode == other.statusCode &&
      bodyType == other.bodyType &&
      body == other.body &&
      delayMs == other.delayMs &&
      headersText == other.headersText;
  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(conditions),
    statusCode,
    bodyType,
    body,
    delayMs,
    headersText,
  );
}

class MockDefinition {
  MockDefinition({
    String? id,
    this.name = '未命名 Mock',
    this.enabled = true,
    this.method = 'GET',
    this.path = '/users',
    List<MockScenario>? scenarios,
  }) : id = id ?? newId(),
       scenarios = List.unmodifiable(scenarios ?? [MockScenario()]);
  final String id, name, method, path;
  final bool enabled;
  final List<MockScenario> scenarios;
  MockDefinition copyWith({
    String? name,
    bool? enabled,
    String? method,
    String? path,
    List<MockScenario>? scenarios,
  }) => MockDefinition(
    id: id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    method: method ?? this.method,
    path: path ?? this.path,
    scenarios: scenarios ?? this.scenarios,
  );
  String get routeShape =>
      path.split('/').map((s) => s.startsWith(':') ? ':' : s).join('/');
  @override
  bool operator ==(Object other) =>
      other is MockDefinition &&
      id == other.id &&
      name == other.name &&
      enabled == other.enabled &&
      method == other.method &&
      path == other.path &&
      sameItems(scenarios, other.scenarios);
  @override
  int get hashCode =>
      Object.hash(id, name, enabled, method, path, Object.hashAll(scenarios));
}

/// Configuration errors include a field path, so both editor and HTTP failures
/// can point at the same invalid input without infrastructure dependencies.
class MockValidationException implements Exception {
  const MockValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

void validateMockDefinition(
  MockDefinition definition,
  Iterable<MockDefinition> saved,
) {
  void fail(String text) => throw MockValidationException(text);
  if (!['GET', 'POST', 'PUT', 'DELETE'].contains(definition.method)) {
    fail('不支持的 HTTP 方法');
  }
  final path = definition.path;
  if (!path.startsWith('/') ||
      path.contains(RegExp(r'[?#\s]')) ||
      path.contains('//') ||
      (path.length > 1 && path.endsWith('/')) ||
      path.contains('%')) {
    fail('路径须以 / 开头，不含查询参数、空白、编码字符或末尾斜线');
  }
  final names = <String>{};
  for (final segment in path.split('/').skip(1)) {
    if (segment.startsWith(':')) {
      final name = segment.substring(1);
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name) ||
          !names.add(name)) {
        fail('路径参数名称无效或重复');
      }
    } else if (segment.contains(':')) {
      fail('路径参数须独占一个路径段，例如 /users/:id');
    }
  }
  if (saved.any(
    (d) =>
        d.id != definition.id &&
        d.method == definition.method &&
        d.routeShape == definition.routeShape,
  )) {
    fail('已存在相同方法及路径结构的 Mock 接口');
  }
  if (definition.scenarios.isEmpty) fail('至少需要一个响应场景');
  if (definition.scenarios.where((s) => s.isDefault).length > 1) {
    fail('只允许一个无条件的默认响应');
  }
  for (final scenario in definition.scenarios) {
    if (scenario.statusCode < 200 || scenario.statusCode > 599) {
      fail('响应状态码须在 200–599 之间');
    }
    if (scenario.delayMs < 0 || scenario.delayMs > 300000) {
      fail('延迟须在 0–300000 毫秒之间');
    }
    if (!['json', 'text'].contains(scenario.bodyType)) fail('响应正文类型无效');
    for (final entry in scenario.headers.entries) {
      if (!RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$").hasMatch(entry.key) ||
          entry.value.contains(RegExp(r'[\r\n]'))) {
        fail('响应 Header 名称或值无效');
      }
      if ([
        'content-length',
        'transfer-encoding',
        'connection',
        'access-control-allow-origin',
        'access-control-allow-methods',
        'access-control-allow-headers',
      ].contains(entry.key.toLowerCase())) {
        fail('${entry.key} 由 Mock 服务自动管理');
      }
    }
    for (final condition in scenario.conditions) {
      if (condition.source == MockConditionSource.header) {
        if (!RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$").hasMatch(condition.key) ||
            condition.expected.contains(RegExp(r'[\r\n]'))) {
          fail('请求 Header 条件无效');
        }
      } else {
        if (condition.key.isNotEmpty && !condition.key.startsWith('/')) {
          fail('Body 字段须使用 JSON Pointer，例如 /user/id');
        }
        if (RegExp(r'~(?![01])').hasMatch(condition.key)) {
          fail('JSON Pointer 转义无效');
        }
        try {
          jsonDecode(condition.expected);
        } on FormatException {
          fail('Body 条件值须为合法 JSON，如 1、true 或 "admin"');
        }
      }
    }
  }
}
