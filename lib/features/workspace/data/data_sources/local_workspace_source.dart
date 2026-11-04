import 'dart:convert';
import 'dart:io';

import 'package:weils_api/core/errors/app_failure.dart';
import 'package:weils_api/core/storage/atomic_json_file.dart';
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
  /// 解析本地 JSON 并校验工作区版本与必要结构。
  Map<String, dynamic> _decode(String text) {
    final data = jsonDecode(text) as Map<String, dynamic>;
    WorkspaceJson.validate(data);
    return data;
  }

  /// 先加载数据位置，再读取工作区；格式损坏时尝试备份恢复，读取异常交给上层处理。
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

  /// 首次访问时加载并校验目录指针，只接受存在的绝对路径。
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

  /// 尝试读取有效备份，并将损坏主文件改名保留，记录本次恢复方式。
  Future<Map<String, dynamic>?> _recover() async {
    final backup = File('${file.path}.bak');
    Map<String, dynamic>? recovered;
    if (await backup.exists()) {
      try {
        recovered = _decode(await backup.readAsString());
      } catch (_) {
        /* 保留无效备份，便于后续手动恢复。 */
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

  /// 立即编码当前快照，再按队列顺序原子写入，避免后续编辑改变待写数据。
  @override
  Future<void> write(Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    return _enqueue(() async {
      await _loadLocation();
      await AtomicJsonFile(file).writeText(encoded);
    });
  }

  /// 串行复制快照并切换目录指针，拒绝覆盖目标已有工作区；失败时清理未提交文件。
  /// 指针提交成功后才更新内存目录，原目录数据保留。
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

  /// 串行执行磁盘操作；前一次失败不会阻断后续保存或迁移。
  Future<void> _enqueue(Future<void> Function() action) {
    final next = _tail.catchError((Object _) {}).then((_) => action());
    _tail = next;
    return next;
  }
}
