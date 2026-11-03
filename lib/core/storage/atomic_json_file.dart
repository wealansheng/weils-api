import 'dart:convert';
import 'dart:io';

/// Generic file primitive. Workspace schemas and recovery policy belong to data.
class AtomicJsonFile {
  const AtomicJsonFile(this.file);
  final File file;
  File get backup => File('${file.path}.bak');

  Future<void> write(Map<String, dynamic> data, {bool keepBackup = true}) =>
      writeText(jsonEncode(data), keepBackup: keepBackup);

  Future<void> writeText(String text, {bool keepBackup = true}) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(text, flush: true);
    if (keepBackup && await file.exists()) await file.copy(backup.path);
    await temp.rename(file.path);
  }
}
