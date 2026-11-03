import 'dart:convert';

import '../entities/mock_definition.dart';

class MockRouteMatch {
  MockRouteMatch(this.definition, Map<String, String> pathParameters)
    : pathParameters = Map.unmodifiable(pathParameters);

  final MockDefinition definition;
  final Map<String, String> pathParameters;
}

/// Existing callers can continue to retrieve just the definition.
MockDefinition? matchMockRoute(
  Iterable<MockDefinition> definitions,
  String method,
  List<String> segments,
) => resolveMockRoute(definitions, method, segments)?.definition;

MockRouteMatch? resolveMockRoute(
  Iterable<MockDefinition> definitions,
  String method,
  List<String> segments,
) {
  final candidates = <MockRouteMatch>[];
  for (final d in definitions) {
    if (!d.enabled || d.method != method) continue;
    final route = d.path == '/' ? <String>[] : d.path.substring(1).split('/');
    final wildcard = route.isNotEmpty && route.last == '*';
    final prefixLength = wildcard ? route.length - 1 : route.length;
    if (wildcard
        ? segments.length < prefixLength ||
              (prefixLength > 0 && segments.length == prefixLength)
        : route.length != segments.length) {
      continue;
    }
    final parameters = <String, String>{};
    var matched = true;
    for (var i = 0; i < prefixLength; i++) {
      if (route[i].startsWith(':')) {
        if (segments[i].isEmpty) {
          matched = false;
          break;
        }
        parameters[route[i].substring(1)] = segments[i];
      } else if (route[i] != segments[i]) {
        matched = false;
        break;
      }
    }
    if (!matched) continue;
    if (wildcard) parameters['*'] = segments.skip(prefixLength).join('/');
    candidates.add(MockRouteMatch(d, parameters));
  }
  candidates.sort((a, b) {
    final aa = a.definition.path.split('/'), bb = b.definition.path.split('/');
    int rank(String segment) => segment == '*'
        ? 2
        : segment.startsWith(':')
        ? 1
        : 0;
    for (var i = 0; i < aa.length && i < bb.length; i++) {
      final result = rank(aa[i]).compareTo(rank(bb[i]));
      if (result != 0) return result;
    }
    // Exact routes beat a trailing wildcard, including for an empty capture.
    return aa.length.compareTo(bb.length);
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
