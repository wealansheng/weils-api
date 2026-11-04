import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/core/errors/app_failure.dart';
import 'package:weils_api/features/mock/domain/entities/mock_definition.dart';
import 'package:weils_api/features/workspace/data/data_sources/local_workspace_source.dart';
import 'package:weils_api/features/workspace/data/models/workspace_json.dart';
import 'package:weils_api/features/workspace/data/repositories/local_workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';

class _ControlledSource extends LocalWorkspaceSource {
  _ControlledSource({required super.directory, super.locationFile});
  bool failWrite = false;
  Completer<void>? pauseOpening;
  final opening = Completer<void>();

  /// 模拟原工作区无法保存，验证失败时不会切走。
  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (failWrite) throw const FileSystemException('write blocked');
    await super.write(data);
  }

  /// 在提交位置前暂停，验证切换期间的编辑保护。
  @override
  Future<Map<String, dynamic>> openWorkspace(String path) async {
    if (!opening.isCompleted) opening.complete();
    await pauseOpening?.future;
    return super.openWorkspace(path);
  }
}

/// 写入一个完整目标工作区并返回原文，便于确认切换不会改写目标文件。
Future<String> writeWorkspace(
  Directory directory,
  WorkspaceSnapshot snapshot,
) async {
  final text = jsonEncode(WorkspaceJson.encode(snapshot));
  await File('${directory.path}/workspace.json').writeAsString(text);
  return text;
}

void main() {
  late Directory root, original, target;
  late _ControlledSource source;
  late LocalWorkspaceRepository repository;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('weils-workspace-switch-');
    original = await Directory('${root.path}/original').create();
    target = await Directory('${root.path}/target').create();
    source = _ControlledSource(directory: original);
    repository = LocalWorkspaceRepository(source);
    await repository.initialize();
  });
  tearDown(() async {
    repository.dispose();
    await root.delete(recursive: true);
  });

  test('loads existing workspace, preserves both datasets and restores selected directory', () async {
    final old = repository.newRequest();
    await repository.saveDraft(old.id);
    repository.updateDraft(old.id, (r) => r.copyWith(body: '原目录未保存的正文'));
    final request = RequestSpec(name: '目标接口', protocol: 'sse', body: '目标正文');
    final mock = MockDefinition(name: '目标 Mock');
    final snapshot = WorkspaceSnapshot(
      requests: [request],
      drafts: [request.copyWith(body: '目标草稿')],
      activeId: request.id,
      history: [
        HistoryRecord(
          request: request,
          response: ResponseRecord(body: '目标历史'),
        ),
      ],
      timeoutSeconds: 67,
      sseMaxResponseMb: 7,
      mocks: [mock],
      mockDrafts: [mock.copyWith(name: '目标 Mock 草稿')],
      mockActiveId: mock.id,
      mockPort: 4321,
    );
    final before = await writeWorkspace(target, snapshot);
    final backup = File('${target.path}/workspace.json.bak');
    await backup.writeAsString('目标备份保持原样');
    final result = await repository.updateSettings(
      timeout: 90,
      sseMaxResponseMb: 9,
      directoryPath: target.path,
    );
    expect(result.succeeded, true);
    final loaded = repository.state.snapshot;
    expect(loaded.active!.body, '目标草稿');
    expect(loaded.active!.protocol, 'sse');
    expect(loaded.history.single.response.body, '目标历史');
    expect(loaded.activeMock!.name, '目标 Mock 草稿');
    expect(loaded.mockPort, 4321);
    expect(loaded.timeoutSeconds, 67);
    expect(loaded.sseMaxResponseMb, 7);
    expect(await File('${target.path}/workspace.json').readAsString(), before);
    expect(await backup.readAsString(), '目标备份保持原样');
    final preserved = await File('${original.path}/workspace.json')
        .readAsString();
    final oldData = WorkspaceJson.decode(
      jsonDecode(preserved) as Map<String, dynamic>,
    );
    expect(oldData.active!.body, '原目录未保存的正文');
    expect(oldData.requests.single.body, isEmpty);
    final restored = LocalWorkspaceRepository(
      LocalWorkspaceSource(directory: original),
    );
    try {
      await restored.initialize();
      expect(restored.state.storageBlocked, false);
      expect(restored.state.snapshot.active!.body, '目标草稿');
      restored.updateDraft(request.id, (r) => r.copyWith(body: '切换后编辑'));
      expect((await restored.flush()).succeeded, true);
      expect(
        await File('${original.path}/workspace.json').readAsString(),
        preserved,
      );
      expect(
        (jsonDecode(await File('${target.path}/workspace.json').readAsString())
            as Map)['drafts'][0]['body'],
        '切换后编辑',
      );
    } finally {
      restored.dispose();
    }
  });

  final invalidEnum = WorkspaceJson.encode(
    WorkspaceSnapshot(
      mocks: [
        MockDefinition(
          scenarios: [
            MockScenario(conditions: [const MockCondition()]),
          ],
        ),
      ],
    ),
  );
  invalidEnum['mocks'][0]['scenarios'][0]['conditions'][0]['source'] =
      'unknown';
  for (final malformed in [
    '{',
    jsonEncode({
      'version': 1,
      'folders': [
        {'id': 123},
      ],
      'requests': [],
      'drafts': [],
      'history': [],
    }),
    jsonEncode(invalidEnum),
  ]) {
    test(
      'invalid target data never changes pointer or replaces current workspace: $malformed',
      () async {
        final request = repository.newRequest();
        repository.updateDraft(request.id, (r) => r.copyWith(name: '保留原工作区'));
        final targetFile = File('${target.path}/workspace.json');
        await targetFile.writeAsString(malformed);
        final result = await repository.updateSettings(
          timeout: 90,
          directoryPath: target.path,
        );
        expect(result.failure?.code, FailureCode.invalidData);
        expect(source.directoryPath, original.path);
        expect(repository.state.snapshot.active!.name, '保留原工作区');
        expect(await source.locationFile.exists(), false);
        expect(await targetFile.readAsString(), malformed);
      },
    );
  }

  test(
    'pointer commit failure preserves target and current workspace',
    () async {
      repository.dispose();
      source = _ControlledSource(
        directory: original,
        locationFile: File('${root.path}/config/settings.json'),
      );
      repository = LocalWorkspaceRepository(source);
      await repository.initialize();
      repository.newRequest();
      await repository.flush();
      await File('${root.path}/config').writeAsString('阻止创建配置目录');
      final before = await writeWorkspace(target, WorkspaceSnapshot());
      final result = await repository.updateSettings(
        timeout: 90,
        directoryPath: target.path,
      );
      expect(result.succeeded, false);
      expect(source.directoryPath, original.path);
      expect(repository.state.snapshot.drafts, hasLength(1));
      expect(
        await File('${target.path}/workspace.json').readAsString(),
        before,
      );
    },
  );

  test(
    'current save failure prevents switching and preserves live edits',
    () async {
      final request = repository.newRequest();
      source.failWrite = true;
      final before = await writeWorkspace(target, WorkspaceSnapshot());
      final result = await repository.updateSettings(
        timeout: 90,
        directoryPath: target.path,
      );
      expect(result.failure?.code, FailureCode.write);
      expect(source.directoryPath, original.path);
      expect(repository.state.snapshot.active!.id, request.id);
      expect(await source.locationFile.exists(), false);
      expect(
        await File('${target.path}/workspace.json').readAsString(),
        before,
      );
    },
  );

  test(
    'loading protects old drafts and queued flush saves the loaded workspace',
    () async {
      final old = repository.newRequest();
      await writeWorkspace(target, WorkspaceSnapshot(timeoutSeconds: 58));
      source.pauseOpening = Completer<void>();
      final switching = repository.updateSettings(
        timeout: 90,
        directoryPath: target.path,
      );
      await source.opening.future;
      expect(
        () => repository.updateDraft(old.id, (r) => r.copyWith(body: '不能混入目标')),
        throwsA(
          isA<AppFailure>().having((e) => e.code, 'code', FailureCode.busy),
        ),
      );
      final flush = repository.flush();
      source.pauseOpening!.complete();
      expect((await switching).succeeded, true);
      expect((await flush).succeeded, true);
      final loaded = jsonDecode(
        await File('${target.path}/workspace.json').readAsString(),
      ) as Map;
      expect(loaded['drafts'], isEmpty);
      expect(loaded['timeoutSeconds'], 58);
    },
  );
}
