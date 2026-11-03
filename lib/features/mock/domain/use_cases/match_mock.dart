import 'dart:convert';

import '../entities/mock_definition.dart';

MockDefinition? matchMockRoute(
  Iterable<MockDefinition> definitions,
  String method,
  List<String> segments,
) {
  final candidates = definitions.where((d) {
    if (!d.enabled || d.method != method) return false;
    final route = d.path == '/' ? <String>[] : d.path.substring(1).split('/');
    if (route.length != segments.length) return false;
    for (var i = 0; i < route.length; i++) {
      if (route[i].startsWith(':')) {
        if (segments[i].isEmpty) return false;
      } else if (route[i] != segments[i]) {
        return false;
      }
    }
    return true;
  }).toList();
  candidates.sort((a, b) {
    final aa = a.path.split('/'), bb = b.path.split('/');
    for (var i = 0; i < aa.length; i++) {
      final result = (aa[i].startsWith(':') ? 1 : 0).compareTo(
        bb[i].startsWith(':') ? 1 : 0,
      );
      if (result != 0) return result;
    }
    return 0;
  });
  return candidates.firstOrNull;
}

MockScenario? matchMockScenario(
  MockDefinition definition,
  Map<String, String> headers,
  String body,
) {
  final normalized = {
    for (final e in headers.entries) e.key.toLowerCase(): e.value,
  };
  Object? decoded;
  var validJson = true;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    validJson = false;
  }
  bool matches(MockCondition condition) {
    if (condition.source == MockConditionSource.header) {
      return normalized[condition.key.toLowerCase()] == condition.expected;
    }
    if (!validJson) return false;
    Object? current = decoded;
    if (condition.key.isNotEmpty) {
      for (final raw in condition.key.substring(1).split('/')) {
        final key = raw.replaceAll('~1', '/').replaceAll('~0', '~');
        if (current is Map<String, dynamic> && current.containsKey(key)) {
          current = current[key];
        } else if (current is List &&
            RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(key)) {
          final index = int.tryParse(key);
          if (index == null || index >= current.length) return false;
          current = current[index];
        } else {
          return false;
        }
      }
    }
    return _jsonEqual(current, jsonDecode(condition.expected));
  }

  for (final scenario in definition.scenarios.where((s) => !s.isDefault)) {
    if (scenario.conditions.every(matches)) return scenario;
  }
  return definition.scenarios.where((s) => s.isDefault).firstOrNull;
}

bool _jsonEqual(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _jsonEqual(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _jsonEqual(a[i], b[i]));
  }
  return a == b;
}
