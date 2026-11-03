import 'dart:convert';
import 'dart:io';

class WorkspaceStorage {
  WorkspaceStorage({Directory? directory})
    : directory =
          directory ??
          Directory(
            Platform.environment['WEILS_API_DATA_DIR'] ??
                '${Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? Directory.current.path}${Platform.pathSeparator}WeilsAPI',
          );
  final Directory directory;
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
    if (!await file.exists()) return null;
    try {
      return _decode(await file.readAsString());
    } on FormatException {
      return _recover();
    } on TypeError {
      return _recover();
    }
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
    final next = _tail.catchError((Object _) {}).then((_) async {
      await directory.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(encoded, flush: true);
      if (await file.exists()) await file.copy('${file.path}.bak');
      await temp.rename(file.path);
    });
    _tail = next;
    return next;
  }
}
