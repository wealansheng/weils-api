import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production imports respect layer and feature ownership', () {
    final root = Directory('lib').absolute.uri;
    final failures = <String>[];
    final directives = RegExp(
      r'''\b(?:import|export|part)\s+['"]([^'"]+)['"]''',
    );
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final from = root.relativize(file.absolute.uri).path;
      for (final match in directives.allMatches(file.readAsStringSync())) {
        final uri = match[1]!;
        final String target;
        if (uri.startsWith('package:weils_api/')) {
          target = uri.substring('package:weils_api/'.length);
        } else if (uri.contains(':')) {
          target = uri;
        } else {
          target = root.relativize(file.absolute.uri.resolve(uri)).path;
        }
        final internal = !target.contains(':');
        bool allowed = true;
        if (from.startsWith('core/')) {
          allowed = !internal || target.startsWith('core/');
        } else if (from.startsWith('shared/') || from.startsWith('layout/')) {
          allowed =
              !internal ||
              ['core/', 'shared/', 'layout/'].any(target.startsWith);
        } else if (from.contains('/domain/')) {
          allowed = target.startsWith('dart:')
              ? ![
                  'dart:io',
                  'dart:ui',
                  'dart:ffi',
                  'dart:isolate',
                ].contains(target)
              : internal &&
                    (target.contains('/domain/') ||
                        target.startsWith('core/errors/') ||
                        target.startsWith('core/utils/'));
        } else if (from.contains('/data/')) {
          allowed =
              !target.startsWith('package:flutter/') &&
              !target.startsWith('package:provider/') &&
              (!internal ||
                  target.startsWith('core/') ||
                  target.contains('/domain/') ||
                  target.contains('/data/'));
        } else if (from.contains('/presentation/')) {
          allowed =
              !['dart:io', 'dart:ffi'].contains(target) &&
              (!internal ||
                  !target.contains('/data/') && !target.startsWith('app/'));
          if (from.contains('/view_models/')) {
            allowed =
                allowed &&
                (!target.contains('/view_models/') ||
                    target.endsWith('/repository_view_model.dart'));
          }
          if (file.readAsStringSync().contains('MethodChannel(')) {
            allowed = false;
          }
        }
        if (!allowed) failures.add('$from → $target');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}

extension on Uri {
  Uri relativize(Uri other) => Uri(path: other.path.substring(path.length));
}
