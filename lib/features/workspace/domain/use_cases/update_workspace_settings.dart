import '../../../../core/errors/app_failure.dart';
import '../repositories/workspace_repository.dart';

/// Settings and a possible data relocation are committed as one operation.
class UpdateWorkspaceSettings {
  const UpdateWorkspaceSettings(this.repository);
  final WorkspaceRepository repository;
  Future<Outcome<void>> call({required int timeout, String? directoryPath}) =>
      repository.updateSettings(timeout: timeout, directoryPath: directoryPath);
}
