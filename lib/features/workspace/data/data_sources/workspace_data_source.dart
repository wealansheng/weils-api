import '../../domain/entities/workspace_snapshot.dart';

abstract interface class WorkspaceDataSource {
  String get directoryPath;
  WorkspaceNotice? get recoveryNotice;
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> data);
  Future<void> relocate(String path, Map<String, dynamic> data);
}
