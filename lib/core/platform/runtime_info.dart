import 'dart:io';

final defaultUserAgent =
    'Dart/${Platform.version.split(' ').first.split('.').take(2).join('.')} (dart:io)';

/// 优先读取指定环境变量，否则按用户目录与应用名生成默认数据目录。
String appDataDirectory(String appName, {String? overrideVariable}) =>
    (overrideVariable == null
        ? null
        : Platform.environment[overrideVariable]) ??
    '${Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? Directory.current.path}${Platform.pathSeparator}$appName';
