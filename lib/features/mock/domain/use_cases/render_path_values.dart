import 'dart:convert';

import '../entities/mock_definition.dart';

/// Substitute only source template tokens. Captured user data is opaque: it
/// must never be reparsed as Mock.js or as another path reference.
String renderMockPathValues(
  String text,
  Map<String, String>? parameters, {
  required int maximumBytes,
}) {
  if (parameters == null) return text; // Save/preview has no incoming request.
  final result = StringBuffer();
  var cursor = 0, bytes = 0;
  void append(String value) {
    bytes += utf8.encode(value).length;
    if (bytes > maximumBytes) {
      throw const MockValidationException('生成正文超过 2 MB');
    }
    result.write(value);
  }

  for (final match in RegExp(r'\{\{path\.([^{}]+)\}\}').allMatches(text)) {
    append(text.substring(cursor, match.start));
    final key = match[1]!;
    if (!parameters.containsKey(key)) {
      throw MockValidationException('路径中未定义响应引用的参数：$key');
    }
    append(parameters[key]!);
    cursor = match.end;
  }
  append(text.substring(cursor));
  return result.toString();
}
