import 'dart:convert';

import 'package:weils_api/core/utils/identity.dart';

enum MockConditionSource { header, body }

class MockCondition {
  const MockCondition({
    this.source = MockConditionSource.header,
    this.key = '',
    this.expected = '',
  });
  final MockConditionSource source;
  final String key;

  /// Header 条件使用原始文本，Body 条件使用 JSON 编码的期望值。
  final String expected;
  /// 复制匹配条件，仅替换指定的来源、字段或期望值。
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
  /// 将 Headers 文本解析为只读字符串映射，格式无效时抛出可展示的校验异常。
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
  /// 保留场景标识并复制配置；显式传入的 Headers 文本优先于映射参数。
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
  /// 保留 Mock 标识并复制接口配置，未指定的字段沿用原值。
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
  /// 将具名参数统一为占位符，用于检测方法相同且路径结构重复的路由。
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

/// Mock 配置校验异常，供编辑器与 HTTP 响应共用，不依赖基础设施错误类型。
class MockValidationException implements Exception {
  const MockValidationException(this.message);
  final String message;
  /// 返回可直接用于界面提示和错误响应的校验信息。
  @override
  String toString() => message;
}

/// 校验路由结构、冲突、场景及条件，并检查路径引用和服务托管的 Headers。
void validateMockDefinition(
  MockDefinition definition,
  Iterable<MockDefinition> saved,
) {
  /// 终止当前定义校验，并将具体原因包装为 Mock 校验异常。
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
  final segments = path.split('/').skip(1).toList();
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    if (segment.contains('*')) {
      if (segment != '*' || index != segments.length - 1) {
        fail('通配符 * 须独占最后一个路径段，例如 /user/* 或 /a/b/*');
      }
      names.add('*');
      continue;
    }
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
    // 保存时校验引用的参数是否存在；实际值在请求时填入，JSON 和文本正文均需检查。
    for (final token in RegExp(
      r'\{\{path\.([^{}]+)\}\}',
    ).allMatches(scenario.body)) {
      if (!names.contains(token[1]!)) fail('路径中未定义响应引用的参数：${token[1]}');
    }
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
