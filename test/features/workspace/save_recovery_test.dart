import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/features/workspace/data/repositories/local_workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_snapshot.dart';

import '../../support/workspace_fixture.dart';

class _RecoveredStorage extends MemoryStorage {
  @override
  WorkspaceNotice get recoveryNotice => WorkspaceNotice.recoveredBackup;
}

void main() {
  for (final action in [
    'flush',
    'save request',
    'settings',
    'save mock',
    'delete mock',
    'mock port',
  ]) {
    test(
      'successful $action clears a stale save failure without dropping edits',
      () async {
        final storage = FailingStorage();
        final repository = LocalWorkspaceRepository(storage);
        await repository.initialize();
        try {
          final request = repository.newRequest();
          final mock = repository.newMock();
          storage.failWrite = true;
          expect((await repository.flush()).succeeded, false);
          expect(repository.state.notice, WorkspaceNotice.saveFailed);
          storage.failWrite = false;
          final result = switch (action) {
            'save request' => await repository.saveDraft(request.id),
            'settings' => await repository.updateSettings(timeout: 40),
            'save mock' => await repository.saveMock(mock.id),
            'delete mock' => await repository.deleteMock(mock.id),
            'mock port' => await repository.setMockPort(3456),
            _ => await repository.flush(),
          };
          expect(result.succeeded, true);
          expect(repository.state.notice, isNull);
          expect(repository.state.snapshot.drafts.single.id, request.id);
          if (action != 'delete mock') {
            expect(repository.state.snapshot.mockDrafts.single.id, mock.id);
          }
          expect(storage.data, isNotNull);
        } finally {
          repository.dispose();
        }
      },
    );
  }
  test('routine saving preserves backup recovery notices', () async {
    final repository = LocalWorkspaceRepository(_RecoveredStorage());
    await repository.initialize();
    try {
      expect(repository.state.notice, WorkspaceNotice.recoveredBackup);
      expect((await repository.flush()).succeeded, true);
      expect(repository.state.notice, WorkspaceNotice.recoveredBackup);
    } finally {
      repository.dispose();
    }
  });
}
