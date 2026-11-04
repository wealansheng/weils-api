import 'dart:convert';

import '../entities/mock_definition.dart';

/// 仅替换源模板中的路径标记，并限制替换结果的 UTF-8 大小。
/// 捕获的请求值作为普通文本插入，不再解析为 Mock 占位符或其他路径引用。
String renderMockPathValues(
  String text,
  Map<String, String>? parameters, {
  required int maximumBytes,
}) {
  if (parameters == null) return text; // 保存与预览阶段没有实际请求，保留路径标记。
  final result = StringBuffer();
  var cursor = 0, bytes = 0;
  /// 追加片段并累计 UTF-8 字节数，超过响应大小限制时立即终止。
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
