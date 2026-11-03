import 'dart:convert';
import 'dart:io';

class WorkspaceStorage {
  WorkspaceStorage({Directory? directory, File? locationFile})
    : _directory = directory ?? defaultDirectory(),
      locationFile =
          locationFile ??
          File(
            '${(directory ?? defaultDirectory()).path}${Platform.pathSeparator}settings.json',
          );

  static Directory defaultDirectory() => Directory(
    Platform.environment['WEILS_API_DATA_DIR'] ??
        '${Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? Directory.current.path}${Platform.pathSeparator}WeilsAPI',
  );

  Directory _directory;
  Directory get directory => _directory;
  final File locationFile;
  bool _locationLoaded = false;
  String? recoveryNotice;
  Future<void> _tail = Future.value();
  File get file =>
      File('${directory.path}${Platform.pathSeparator}workspace.json');
  Map<String, dynamic> _decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['version'] != 1 ||
        json['requests'] is! List ||
        json['drafts'] is! List ||
        json['folders'] is! List ||
        json['history'] is! List) {
      throw const FormatException('Unsupported workspace data');
    }
    return json;
  }

  Future<Map<String, dynamic>?> read() async {
    await _loadLocation();
    if (!await file.exists()) return null;
    try {
      return _decode(await file.readAsString());
    } on FormatException {
      return _recover();
    } on TypeError {
      return _recover();
    }
  }

  Future<void> _loadLocation() async {
    if (_locationLoaded) return;
    if (await locationFile.exists()) {
      final config = jsonDecode(await locationFile.readAsString()) as Map;
      final path = config['dataDirectory'];
      if (config['version'] != 1 ||
          path is! String ||
          path.isEmpty ||
          !Directory(path).isAbsolute) {
        throw const FormatException('Invalid data directory settings');
      }
      final selected = Directory(path);
      if (!await selected.exists()) {
        throw FileSystemException('Data directory is unavailable', path);
      }
      _directory = selected;
    }
    _locationLoaded = true;
  }

  Future<Map<String, dynamic>?> _recover() async {
    final backup = File('${file.path}.bak');
    Map<String, dynamic>? recovered;
    if (await backup.exists()) {
      try {
        recovered = _decode(await backup.readAsString());
      } catch (_) {
        /* Preserve invalid backups. */
      }
    }
    final quarantine =
        '${file.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}';
    await file.rename(quarantine);
    recoveryNotice = recovered != null
        ? '数据文件无法读取，已恢复上一次备份。原文件已保留在数据目录。'
        : '数据文件无法读取，已打开空白工作区。原文件已保留在数据目录，可用于恢复。';
    return recovered;
  }

  /// Serialize writes and atomically replace the workspace after a flushed temp
  /// write. A last-known-good backup is kept for interrupted/corrupt writes.
  Future<void> write(Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    return _enqueue(() async {
      await _loadLocation();
      await _writeEncoded(encoded);
    });
  }

  Future<void> _writeEncoded(String encoded) async {
    await directory.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(encoded, flush: true);
    if (await file.exists()) await file.copy('${file.path}.bak');
    await temp.rename(file.path);
  }

  /// Commit data before its location pointer. Neither source data nor an
  /// existing destination workspace is replaced during relocation.
  Future<void> relocate(String path, Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    return _enqueue(() async {
      await _loadLocation();
      final target = Directory(path);
      if (!target.isAbsolute || !await target.exists()) {
        throw const StorageLocationException('所选文件夹不存在，请重新选择。');
      }
      final resolved = await target.resolveSymbolicLinks();
      final source = await directory.exists()
          ? await directory.resolveSymbolicLinks()
          : directory.absolute.path;
      if (Platform.isWindows
          ? resolved.toLowerCase() == source.toLowerCase()
          : resolved == source) {
        await _writeEncoded(encoded);
        return;
      }
      final destination = File(
        '$resolved${Platform.pathSeparator}workspace.json',
      );
      for (final suffix in ['', '.bak', '.tmp']) {
        if (await FileSystemEntity.type('${destination.path}$suffix') !=
            FileSystemEntityType.notFound) {
          throw const StorageLocationException('所选目录已有工作区数据，请选择其他文件夹。');
        }
      }
      // Reserve the new workspace exclusively, so even a concurrent creator
      // cannot cause an existing workspace to be overwritten.
      await destination.create(exclusive: true);
      var committed = false;
      final pointerTemp = File(
        '${locationFile.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
      );
      try {
        await destination.writeAsString(encoded, flush: true);
        await locationFile.parent.create(recursive: true);
        await pointerTemp.writeAsString(
          jsonEncode({'version': 1, 'dataDirectory': resolved}),
          flush: true,
        );
        await pointerTemp.rename(locationFile.path);
        _directory = Directory(resolved);
        committed = true;
      } finally {
        if (!committed && await destination.exists()) {
          await destination.delete();
        }
        if (await pointerTemp.exists()) await pointerTemp.delete();
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _tail.catchError((Object _) {}).then((_) => action());
    _tail = next;
    return next;
  }
}

class StorageLocationException implements Exception {
  const StorageLocationException(this.message);
  final String message;
}
