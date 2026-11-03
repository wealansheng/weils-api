import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/features/mock/domain/entities/mock_definition.dart';
import 'package:weils_api/features/workspace/data/data_sources/local_workspace_source.dart';
import 'package:weils_api/features/workspace/data/repositories/local_workspace_repository.dart';

import '../../support/workspace_fixture.dart';

class _PausedStorage extends MemoryStorage {
  Completer<void>? paused;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    await paused?.future;
    await super.write(data);
  }
}

void main() {
  test(
    'legacy data, dirty drafts, successful save, restore and discard',
    () async {
      final storage = MemoryStorage();
      final repository = LocalWorkspaceRepository(storage);
      await repository.initialize();
      expect(repository.state.snapshot.mockPort, 3000);
      expect(repository.state.snapshot.mocks, isEmpty);
      final draft = repository.newMock();
      repository.updateMockDraft(
        draft.id,
        (d) => d.copyWith(path: '/users/:id'),
      );
      expect(repository.state.snapshot.hasDirtyDrafts, true);
      expect((await repository.saveMock(draft.id)).succeeded, true);
      repository.updateMockDraft(
        draft.id,
        (d) => d.copyWith(
          name: 'unsaved',
          scenarios: [MockScenario(headersText: '{')],
        ),
      );
      await repository.flush();
      final restored = LocalWorkspaceRepository(storage);
      await restored.initialize();
      expect(restored.state.snapshot.mocks.single.path, '/users/:id');
      expect(restored.state.snapshot.activeMock!.name, 'unsaved');
      expect(
        restored.state.snapshot.activeMock!.scenarios.single.headersText,
        '{',
      );
      expect((await restored.saveMock(draft.id)).succeeded, false);
      await restored.flush(discardDirtyDrafts: true);
      final discarded = LocalWorkspaceRepository(storage);
      await discarded.initialize();
      expect(discarded.state.snapshot.mockDrafts, isEmpty);
      expect(discarded.state.snapshot.mocks, hasLength(1));
      expect((await discarded.deleteMock(draft.id)).succeeded, true);
      expect(discarded.state.snapshot.mocks, isEmpty);
      repository.dispose();
      restored.dispose();
      discarded.dispose();
    },
  );
  test(
    'failed saves and deletes never publish new server definitions',
    () async {
      final storage = FailingStorage();
      final repository = LocalWorkspaceRepository(storage);
      await repository.initialize();
      final draft = repository.newMock();
      expect((await repository.saveMock(draft.id)).succeeded, true);
      final old = repository.state.snapshot.mocks;
      repository.updateMockDraft(draft.id, (d) => d.copyWith(name: 'new'));
      storage.failWrite = true;
      expect((await repository.saveMock(draft.id)).succeeded, false);
      expect(repository.state.snapshot.mocks, same(old));
      expect(repository.state.snapshot.activeMock!.name, 'new');
      expect((await repository.deleteMock(draft.id)).succeeded, false);
      expect(repository.state.snapshot.mocks, same(old));
      expect((await repository.setMockPort(4000)).succeeded, false);
      expect(repository.state.snapshot.mockPort, 3000);
      storage.failWrite = false;
      expect((await repository.saveMock(draft.id)).succeeded, true);
      expect(repository.state.snapshot.mocks.single.name, 'new');
      final duplicate = repository.newMock();
      repository.updateMockDraft(
        duplicate.id,
        (d) => d.copyWith(path: draft.path),
      );
      expect((await repository.saveMock(duplicate.id)).succeeded, false);
      repository.dispose();
    },
  );
  test('a pending save does not publish until disk completion or overwrite newer drafts', () async {
    final storage = _PausedStorage();
    final repository = LocalWorkspaceRepository(storage);
    await repository.initialize();
    final draft = repository.newMock();
    storage.paused = Completer<void>();
    final save = repository.saveMock(draft.id);
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.snapshot.mocks, isEmpty);
    repository.updateMockDraft(draft.id, (d) => d.copyWith(name: 'newer'));
    final flush = repository.flush();
    storage.paused!.complete();
    await save;
    await flush;
    expect(repository.state.snapshot.mocks.single.name, '未命名 Mock');
    expect(repository.state.snapshot.activeMock!.name, 'newer');
    final restored = LocalWorkspaceRepository(storage);
    await restored.initialize();
    expect(restored.state.snapshot.activeMock!.name, 'newer');
    repository.dispose();
    restored.dispose();
  });
  test(
    'real directory migration and restart include saved mocks, drafts and port',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'weils-mock-migration-',
      );
      final source = Directory('${root.path}/source'),
          target = Directory('${root.path}/target');
      await source.create();
      await target.create();
      final repository = LocalWorkspaceRepository(
        LocalWorkspaceSource(directory: source),
      );
      try {
        await repository.initialize();
        final draft = repository.newMock();
        await repository.saveMock(draft.id);
        repository.updateMockDraft(draft.id, (d) => d.copyWith(name: 'draft'));
        await repository.setMockPort(3456);
        expect(
          (await repository.updateSettings(
            timeout: 30,
            directoryPath: target.path,
          )).succeeded,
          true,
        );
        final restored = LocalWorkspaceRepository(
          LocalWorkspaceSource(directory: source),
        );
        await restored.initialize();
        expect(
          FileSystemEntity.identicalSync(
            restored.state.dataDirectory,
            target.path,
          ),
          true,
        );
        expect(restored.state.snapshot.mocks, hasLength(1));
        expect(restored.state.snapshot.activeMock!.name, 'draft');
        expect(restored.state.snapshot.mockPort, 3456);
        expect(await File('${source.path}/workspace.json').exists(), true);
        restored.dispose();
      } finally {
        repository.dispose();
        await root.delete(recursive: true);
      }
    },
  );
}
