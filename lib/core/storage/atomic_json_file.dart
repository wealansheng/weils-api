import 'dart:convert';
import 'dart:io';

/// 提供通用原子文件写入；工作区格式校验与恢复策略由数据层负责。
class AtomicJsonFile {
  const AtomicJsonFile(this.file);
  final File file;
  File get backup => File('${file.path}.bak');

  /// 将 JSON 编码后交给原子写入流程，可选择保留原文件备份。
  Future<void> write(Map<String, dynamic> data, {bool keepBackup = true}) =>
      writeText(jsonEncode(data), keepBackup: keepBackup);

  /// 先写入并刷新临时文件，再备份旧文件并重命名替换，减少写入中断造成的数据损坏。
  Future<void> writeText(String text, {bool keepBackup = true}) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(text, flush: true);
    if (keepBackup && await file.exists()) await file.copy(backup.path);
    await temp.rename(file.path);
  }
}
