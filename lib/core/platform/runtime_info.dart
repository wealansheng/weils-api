import 'dart:io';

final defaultUserAgent =
    'Dart/${Platform.version.split(' ').first.split('.').take(2).join('.')} (dart:io)';

String appDataDirectory(String appName, {String? overrideVariable}) =>
    (overrideVariable == null
        ? null
        : Platform.environment[overrideVariable]) ??
    '${Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? Directory.current.path}${Platform.pathSeparator}$appName';
