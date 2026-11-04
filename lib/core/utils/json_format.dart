import 'dart:convert';

/// 将合法 JSON 格式化为两空格缩进；解析失败时保留原文。
String prettyJson(String input) {
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(input));
  } catch (_) {
    return input;
  }
}
