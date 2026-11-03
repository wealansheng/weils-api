import 'dart:convert';
import 'dart:math';

import '../entities/mock_definition.dart';
import 'render_path_values.dart';

const mockMaxBytes = 2 * 1024 * 1024;

/// A JSON-only subset of Mock.js. No evaluation or JavaScript runtime is used.
class MockGenerator {
  MockGenerator({Random? random, DateTime Function()? now})
    : random = random ?? Random(),
      now = now ?? DateTime.now;
  final Random random;
  final DateTime Function() now;
  Map<String, int> _increments = {};
  int _nodes = 0, _textBytes = 0;
  Map<String, String>? _pathParameters;

  String generate(String template, {Map<String, String>? pathParameters}) {
    _pathParameters = pathParameters == null
        ? null
        : Map.unmodifiable(pathParameters);
    if (utf8.encode(template).length > mockMaxBytes) _fail('模板超过 2 MB');
    _increments = {};
    _nodes = 0;
    _textBytes = 0;
    final Object? source;
    try {
      source = jsonDecode(template);
    } on FormatException {
      _fail('响应模板须为合法 JSON');
    }
    _validate(source, r'$', 0);
    _increments = {};
    _nodes = 0;
    _textBytes = 0;
    final value = _visit(source, r'$', 0);
    _nodes = 0;
    _checkOutput(value, 0);
    final result = const JsonEncoder.withIndent('  ').convert(value);
    if (utf8.encode(result).length > mockMaxBytes) _fail('生成正文超过 2 MB');
    return result;
  }

  Never _fail(String message) => throw MockValidationException(message);

  // A placeholder such as @pick can return a collection directly. Validate
  // the resulting tree as well as the template so it cannot bypass limits.
  void _checkOutput(Object? value, int depth) {
    if (depth > 32) _fail('生成深度超过 32 层');
    if (++_nodes > 100000) _fail('生成数据过大（最多 100000 个节点）');
    if (value is List) {
      _size(value.length);
      for (final item in value) {
        _checkOutput(item, depth + 1);
      }
    } else if (value is Map) {
      for (final item in value.values) {
        _checkOutput(item, depth + 1);
      }
    } else if (value is num && !value.isFinite) {
      _fail('JSON 数值须为有限数');
    }
  }

  /// Validate every branch, including array items/object properties which a
  /// random draw may not include in this particular output.
  void _validate(Object? value, String path, int depth) {
    if (depth > 32) _fail('$path：生成深度超过 32 层');
    if (value is List) {
      _size(value.length);
      for (final item in value) {
        _validate(item, '$path[]', depth + 1);
      }
    } else if (value is Map<String, dynamic>) {
      final names = <String>{};
      for (final e in value.entries) {
        final parts = e.key.split('|');
        if (parts.length > 2 ||
            parts.first.isEmpty ||
            !names.add(parts.first)) {
          _fail('$path：字段名或规则无效、重复');
        }
        if (parts.length == 2) {
          final step = RegExp(r'^\+(\d+)$').firstMatch(parts[1]);
          final range = RegExp(r'^(-?\d+)(?:-(-?\d+))?(?:\.(\d+)(?:-(\d+))?)?$')
              .firstMatch(parts[1]);
          if (step != null) {
            final amount = int.tryParse(step[1]!);
            if (amount == null ||
                amount < 1 ||
                amount > 1000 ||
                (e.value is! num &&
                    (e.value is! List || (e.value as List).isEmpty))) {
              _fail('$path：递增规则无效');
            }
          } else {
            if (range == null) _fail('$path：不支持的模板规则 ${parts[1]}');
            final min = int.tryParse(range[1]!),
                max = int.tryParse(range[2] ?? range[1]!);
            if (min == null ||
                max == null ||
                (min > max && e.value is! bool) ||
                min.abs() > 1000000000000 ||
                max.abs() > 1000000000000) {
              _fail('$path：范围无效');
            }
            if (range[3] != null) {
              final dmin = int.tryParse(range[3]!),
                  dmax = int.tryParse(range[4] ?? range[3]!);
              if (e.value is! num ||
                  dmin == null ||
                  dmax == null ||
                  dmin > dmax ||
                  dmax > 12) {
                _fail('$path：小数规则无效（最多 12 位）');
              }
            } else if (e.value is bool) {
              if (min < 0 || max < 0 || min + max == 0) _fail('$path：布尔权重无效');
            } else if (e.value is! num) {
              _size(min);
              _size(max);
              if (e.value is List &&
                  ((e.value as List).isEmpty && max > 0 ||
                      (e.value as List).length * max > 1000)) {
                _fail('$path：数组规则为空或超过 1000 项');
              }
              if (e.value is Map && max > (e.value as Map).length) {
                _fail('$path：抽取属性过多');
              }
              if (e.value is! List && e.value is! Map && e.value is! String) {
                _fail('$path：该类型不支持生成规则');
              }
            }
          }
        }
        _validate(e.value, '$path.${parts.first}', depth + 1);
      }
    } else if (value is String) {
      _placeholders(value);
    }
  }

  int _integer(int min, int max) {
    if (min > max || min.abs() > 1000000000000 || max.abs() > 1000000000000) {
      _fail('整数范围无效或超过 ±10¹²');
    }
    return min + (random.nextDouble() * (max - min + 1)).floor();
  }

  void _size(int count) {
    if (count < 0 || count > 1000) _fail('重复次数须在 0–1000 之间');
  }

  String _track(String text) {
    _textBytes += utf8.encode(text).length;
    if (_textBytes > mockMaxBytes) _fail('生成正文超过 2 MB');
    return text;
  }

  Object? _visit(Object? value, String path, int depth, [String? rule]) {
    if (depth > 32) _fail('$path：生成深度超过 32 层');
    if (++_nodes > 100000) _fail('生成数据过大（最多 100000 个节点）');
    if (rule == null) {
      if (value is Map<String, dynamic>) {
        final result = <String, Object?>{};
        for (final entry in value.entries) {
          final parts = entry.key.split('|');
          if (parts.length > 2 || parts.first.isEmpty) _fail('$path：字段规则无效');
          if (result.containsKey(parts.first)) _fail('$path：生成后字段名重复');
          result[_track(parts.first)] = _visit(
            entry.value,
            '$path.${parts.first}',
            depth + 1,
            parts.length == 2 ? parts[1] : null,
          );
        }
        return result;
      }
      if (value is List) {
        _size(value.length);
        return value.map((v) => _visit(v, '$path[]', depth + 1)).toList();
      }
      return value is String ? _placeholders(value) : value;
    }
    final step = RegExp(r'^\+(\d+)$').firstMatch(rule);
    if (step != null) {
      final amount = int.parse(step[1]!);
      if (amount < 1 || amount > 1000) _fail('$path：递增步长须在 1–1000 之间');
      final index = _increments[path] ?? 0;
      _increments[path] = index + amount;
      if (value is num) return value + index;
      if (value is List && value.isNotEmpty) {
        return _visit(value[index % value.length], '$path[]', depth + 1);
      }
      _fail('$path：递增规则仅适用于数字和非空数组');
    }
    final match = RegExp(r'^(-?\d+)(?:-(-?\d+))?(?:\.(\d+)(?:-(\d+))?)?$')
        .firstMatch(rule);
    if (match == null) _fail('$path：不支持的模板规则 $rule');
    final min = int.tryParse(match[1]!),
        max = int.tryParse(match[2] ?? match[1]!);
    if (min == null || max == null || (min > max && value is! bool)) {
      _fail('$path：范围无效');
    }
    if (value is num && value is! bool) {
      final whole = _integer(min, max);
      if (match[3] == null) return whole;
      final dmin = int.tryParse(match[3]!),
          dmax = int.tryParse(match[4] ?? match[3]!);
      if (dmin == null ||
          dmax == null ||
          dmin < 0 ||
          dmax > 12 ||
          dmin > dmax) {
        _fail('$path：小数位数须在 0–12 之间');
      }
      final count = _integer(dmin, dmax);
      if (count == 0) return whole;
      final fraction = value.toString().split('.').skip(1).firstOrNull ?? '';
      final digits = List.generate(
        count,
        (i) => i < fraction.length
            ? fraction[i]
            : '${_integer(i == count - 1 ? 1 : 0, 9)}',
      ).join();
      return double.parse('$whole.$digits');
    }
    if (match[3] != null) _fail('$path：小数规则仅适用于数字');
    if (value is bool) {
      if (min < 0 || max < 0 || min + max == 0) _fail('$path：布尔权重无效');
      return random.nextDouble() < min / (min + max) ? value : !value;
    }
    final count = _integer(min, max);
    _size(count);
    if (value is String) {
      if (utf8.encode(value).length * count > mockMaxBytes) {
        _fail('生成正文超过 2 MB');
      }
      return _placeholders(List.filled(count, value).join());
    }
    if (value is List) {
      if (value.isEmpty && count > 0) _fail('$path：无法从空数组生成数据');
      if (value.length * count > 1000) _fail('$path：数组最多 1000 项');
      if (rule == '1') {
        return _visit(
          value[_integer(0, value.length - 1)],
          '$path[]',
          depth + 1,
        );
      }
      return [
        for (var i = 0; i < count; i++)
          for (final item in value) _visit(item, '$path[]', depth + 1),
      ];
    }
    if (value is Map<String, dynamic>) {
      if (count > value.length) _fail('$path：抽取属性数量超过对象字段数');
      final keys = value.keys.toList()..shuffle(random);
      return _visit(
        {for (final key in keys.take(count)) key: value[key]},
        path,
        depth + 1,
      );
    }
    _fail('$path：该类型不支持生成规则');
  }

  Object? _placeholders(String text) {
    if (RegExp(r'@(?:/|\.\.?/)').hasMatch(text)) _fail('暂不支持模板字段引用');
    final pieces = <Object?>[];
    var pieceBytes = 0;
    void addPiece(Object? value) {
      pieceBytes += utf8
          .encode(value is String ? value : jsonEncode(value))
          .length;
      if (pieceBytes > mockMaxBytes) _fail('生成正文超过 2 MB');
      pieces.add(value);
    }

    String sourceText(String value) => renderMockPathValues(
      value,
      _pathParameters,
      maximumBytes: mockMaxBytes,
    );
    var cursor = 0;
    final pattern = RegExp(r'@([A-Za-z_][A-Za-z0-9_]*)');
    while (cursor < text.length) {
      final found = pattern.firstMatch(text.substring(cursor));
      if (found == null) {
        addPiece(sourceText(text.substring(cursor)));
        break;
      }
      final start = cursor + found.start, nameEnd = cursor + found.end;
      if (start > cursor) addPiece(sourceText(text.substring(cursor, start)));
      var end = nameEnd;
      var args = <Object?>[];
      if (end < text.length && text[end] == '(') {
        var nesting = 1;
        String? quote;
        var escaped = false;
        final argStart = ++end;
        while (end < text.length && nesting > 0) {
          final char = text[end];
          if (escaped) {
            escaped = false;
          } else if (char == '\\' && quote != null) {
            escaped = true;
          } else if (quote != null) {
            if (char == quote) quote = null;
          } else if (char == '"' || char == "'") {
            quote = char;
          } else if (char == '(') {
            nesting++;
          } else if (char == ')') {
            nesting--;
          }
          if (nesting > 0) end++;
        }
        if (nesting != 0) _fail('占位符参数括号未闭合');
        args = _arguments(text.substring(argStart, end));
        end++;
      }
      addPiece(_call(found[1]!.toLowerCase(), args));
      cursor = end;
    }
    if (pieces.isEmpty) return _track('');
    if (pieces.length == 1 && text.startsWith('@')) {
      final result = pieces.single;
      if (result is String) return _track(result);
      return result;
    }
    return _track(pieces.map((p) => p is String ? p : jsonEncode(p)).join());
  }

  List<Object?> _arguments(String source) {
    // Normalize single-quoted string arguments without changing quoted content.
    final normalized = StringBuffer();
    var i = 0;
    while (i < source.length) {
      if (source[i] == '"') {
        normalized.write(source[i++]);
        while (i < source.length) {
          final char = source[i++];
          normalized.write(char);
          if (char == '\\' && i < source.length) {
            normalized.write(source[i++]);
          } else if (char == '"') {
            break;
          }
        }
      } else if (source[i] == "'") {
        i++;
        final value = StringBuffer();
        var closed = false;
        while (i < source.length) {
          final char = source[i++];
          if (char == "'") {
            closed = true;
            break;
          }
          if (char == '\\' && i < source.length) {
            final next = source[i++];
            value.write(switch (next) {
              'n' => '\n',
              'r' => '\r',
              't' => '\t',
              _ => next,
            });
          } else {
            value.write(char);
          }
        }
        if (!closed) _fail('占位符字符串未闭合');
        normalized.write(jsonEncode(value.toString()));
      } else {
        normalized.write(source[i++]);
      }
    }
    try {
      return (jsonDecode('[$normalized]') as List).cast<Object?>();
    } on FormatException {
      _fail('占位符参数须为 JSON 值或单引号字符串');
    }
  }

  Object? _call(String name, List<Object?> args) {
    void arity(int min, int max) {
      if (args.length < min || args.length > max) _fail('@$name 参数数量无效');
    }

    int integerArg(int index, int fallback) {
      if (index >= args.length) return fallback;
      if (args[index] is! int) _fail('@$name 参数须为整数');
      return args[index] as int;
    }

    String stringArg(int index, String fallback) {
      if (index >= args.length) return fallback;
      if (args[index] is! String) _fail('@$name 参数须为字符串');
      return args[index] as String;
    }

    switch (name) {
      case 'integer':
      case 'natural':
        arity(0, 2);
        final min = integerArg(0, name == 'natural' ? 0 : -10000),
            max = integerArg(1, 10000);
        if (name == 'natural' && min < 0) _fail('@natural 最小值不能为负');
        return _integer(min, max);
      case 'float':
        arity(0, 4);
        return _visit(
          0.0,
          '@float',
          0,
          '${integerArg(0, 0)}-${integerArg(1, 100)}.${integerArg(2, 0)}-${integerArg(3, 4)}',
        );
      case 'boolean':
        if (args.isEmpty) return random.nextBool();
        arity(3, 3);
        final min = integerArg(0, 1), max = integerArg(1, 1);
        if (args[2] is! bool || min < 0 || max < 0 || min + max == 0) {
          _fail('@boolean 参数无效');
        }
        return random.nextDouble() < min / (min + max)
            ? args[2]
            : !(args[2] as bool);
      case 'string':
        arity(0, 3);
        var pool =
            'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        var offset = 0;
        if (args.isNotEmpty && args.first is String) {
          pool = args.first as String;
          offset = 1;
          pool = switch (pool) {
            'lower' => 'abcdefghijklmnopqrstuvwxyz',
            'upper' => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
            'number' => '0123456789',
            'symbol' => '!@#\$%^&*()[]',
            'alpha' => 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
            _ => pool,
          };
        }
        if (args.length - offset > 2 || pool.isEmpty) _fail('@string 参数无效');
        final min = integerArg(offset, 3),
            max = integerArg(offset + 1, args.length > offset ? min : 7);
        final count = _integer(min, max);
        _size(count);
        return List.generate(
          count,
          (_) => pool[_integer(0, pool.length - 1)],
        ).join();
      case 'pick':
        arity(1, 3);
        if (args.first is! List || (args.first as List).isEmpty) {
          _fail('@pick 第一个参数须为非空数组');
        }
        final items = List<Object?>.from(args.first as List);
        if (args.length == 1) return items[_integer(0, items.length - 1)];
        final count = _integer(
          integerArg(1, 1),
          integerArg(2, integerArg(1, 1)),
        );
        _size(count);
        if (count > items.length) _fail('@pick 数量超过数组长度');
        items.shuffle(random);
        return items.take(count).toList();
      case 'guid':
        arity(0, 0);
        final bytes = List.generate(16, (_) => _integer(0, 255));
        bytes[6] = (bytes[6] & 15) | 64;
        bytes[8] = (bytes[8] & 63) | 128;
        final hex = bytes
            .map((v) => v.toRadixString(16).padLeft(2, '0'))
            .join();
        return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      case 'name':
      case 'cname':
        arity(0, 0);
        const first = [
          'James',
          'Emma',
          'Olivia',
          'Noah',
          'Liam',
          'Sophia',
          'Lucas',
          'Mia',
        ];
        const last = [
          'Smith',
          'Brown',
          'Taylor',
          'Wilson',
          'Davis',
          'Clark',
          'Lee',
          'Walker',
        ];
        const family = ['赵', '钱', '孙', '李', '周', '吴', '郑', '王', '陈', '林'];
        const given = ['明', '华', '宇', '欣', '雨', '晨', '宁', '悦', '安', '涵'];
        return name == 'name'
            ? '${first[_integer(0, 7)]} ${last[_integer(0, 7)]}'
            : '${family[_integer(0, 9)]}${given[_integer(0, 9)]}${given[_integer(0, 9)]}';
      case 'email':
        arity(0, 1);
        final domain = stringArg(0, 'example.com');
        if (domain.contains('@') || domain.contains(RegExp(r'\s'))) {
          _fail('@email 域名无效');
        }
        return 'user${_integer(10000, 999999)}@$domain';
      case 'date':
      case 'time':
      case 'datetime':
        arity(0, 1);
        final current = now();
        final start = DateTime(2000).millisecondsSinceEpoch;
        final end = max(start, current.millisecondsSinceEpoch);
        final date = DateTime.fromMillisecondsSinceEpoch(
          start + (random.nextDouble() * (end - start)).floor(),
        );
        final format = stringArg(
          0,
          name == 'date'
              ? 'yyyy-MM-dd'
              : name == 'time'
              ? 'HH:mm:ss'
              : 'yyyy-MM-dd HH:mm:ss',
        );
        final tokens = <String, String>{
          'yyyy': '${date.year}'.padLeft(4, '0'),
          'yy': '${date.year % 100}'.padLeft(2, '0'),
          'MM': '${date.month}'.padLeft(2, '0'),
          'M': '${date.month}',
          'dd': '${date.day}'.padLeft(2, '0'),
          'd': '${date.day}',
          'HH': '${date.hour}'.padLeft(2, '0'),
          'H': '${date.hour}',
          'hh': '${(date.hour + 11) % 12 + 1}'.padLeft(2, '0'),
          'h': '${(date.hour + 11) % 12 + 1}',
          'mm': '${date.minute}'.padLeft(2, '0'),
          'm': '${date.minute}',
          'ss': '${date.second}'.padLeft(2, '0'),
          's': '${date.second}',
          'SSS': '${date.millisecond}'.padLeft(3, '0'),
        };
        return format.replaceAllMapped(
          RegExp(r'yyyy|SSS|yy|MM|dd|HH|hh|mm|ss|M|d|H|h|m|s'),
          (m) => tokens[m[0]]!,
        );
      default:
        _fail('不支持的占位符 @$name；请查看模板语法帮助');
    }
  }
}
