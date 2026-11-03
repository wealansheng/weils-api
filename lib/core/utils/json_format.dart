import 'dart:convert';

String prettyJson(String input) {
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(input));
  } catch (_) {
    return input;
  }
}
