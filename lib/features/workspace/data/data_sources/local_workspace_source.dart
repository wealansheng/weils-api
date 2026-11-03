import 'dart:convert';
import 'dart:io';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/storage/atomic_json_file.dart';
import '../../domain/entities/workspace_snapshot.dart';
import '../models/workspace_json.dart';
import 'workspace_data_source.dart';

class LocalWorkspaceSource implements WorkspaceDataSource {
  LocalWorkspaceSource({required Directory directory, File? locationFile})
    : _directory = directory,
      locationFile =
          locationFile ??
          File('${directory.path}${Platform.pathSeparator}settings.json');
  Directory _directory;
  Directory get directory => _directory;
  @override
  String get directoryPath => directory.path;
  final File locationFile;
  bool _locationLoaded = false;
  @override
  WorkspaceNotice? recoveryNotice;
  Future<void> _tail = Future.value();
  File get file =>
      File('${directory.path}${Platform.pathSeparator}workspace.json');
  Map<String, dynamic> _decode(String text) {
    final data = jsonDecode(text) as Map<String, dynamic>;
    WorkspaceJson.validate(data);
    return data;
  }

  @override
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
        throw const AppFailure(FailureCode.invalidData);
      }
      final selected = Directory(path);
      if (!await selected.exists()) {
        throw const AppFailure(FailureCode.notFound);
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
        /* Preserve invalid backups for manual recovery. */
      }
    }
    await file.rename(
      '${file.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}',
    );
    recoveryNotice = recovered == null
        ? WorkspaceNotice.recoveredEmpty
        : WorkspaceNotice.recoveredBackup;
    return recovered;
  }

  @override
  Future<void> write(Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    return _enqueue(() async {
      await _loadLocation();
      await AtomicJsonFile(file).writeText(encoded);
    });
  }

  @override
  Future<void> relocate(String path, Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    return _enqueue(() async {
      await _loadLocation();
      final target = Directory(path);
      if (!target.isAbsolute || !await target.exists()) {
        throw const AppFailure(FailureCode.notFound);
      }
      final resolved = await target.resolveSymbolicLinks();
      final source = await directory.exists()
          ? await directory.resolveSymbolicLinks()
          : directory.absolute.path;
      if (Platform.isWindows
          ? resolved.toLowerCase() == source.toLowerCase()
          : resolved == source) {
        await AtomicJsonFile(file).writeText(encoded);
        return;
      }
      final destination = File(
        '$resolved${Platform.pathSeparator}workspace.json',
      );
      for (final suffix in ['', '.bak', '.tmp']) {
        if (await FileSystemEntity.type('${destination.path}$suffix') !=
            FileSystemEntityType.notFound) {
          throw const AppFailure(FailureCode.conflict);
        }
      }
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
