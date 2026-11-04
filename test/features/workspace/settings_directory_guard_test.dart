import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/core/errors/app_failure.dart';
import 'package:weils_api/features/settings/presentation/view_models/settings_view_model.dart';
import 'package:weils_api/features/workspace/domain/use_cases/update_workspace_settings.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';

import '../../support/workspace_fixture.dart';

class _DirectoryWindow extends FakeDesktopWindow {
  /// 模拟用户通过原生目录选择器选择其他工作区。
  @override
  Future<String?> selectDirectory(String initialPath) async =>
      'another-workspace';
}

void main() {
  test(
    'empty-directory migration retains the current response cache',
    () async {
      final fixture = WorkspaceFixture(storage: RelocatingMemoryStorage());
      await fixture.initialize();
      final request = fixture.newRequest();
      final response = ResponseRecord(statusCode: 200, body: '保留响应');
      fixture.responses[request.id] = response;
      final execution = fixture.dependencies.execution;
      try {
        expect(
          await fixture.updateSettings(
            timeout: 45,
            directoryPath: 'empty-target',
          ),
          true,
        );
        expect(execution.responseFor(request.id), same(response));
        expect(fixture.repository.state.workspaceRevision, 0);
      } finally {
        fixture.dispose();
      }
    },
  );
  test(
    'running work blocks directory changes but allows timeout-only settings',
    () async {
      final storage = RelocatingMemoryStorage();
      final fixture = WorkspaceFixture(storage: storage);
      await fixture.initialize();
      final window = _DirectoryWindow();
      var blocked = true;
      final settings = SettingsViewModel(
        fixture.repository,
        window,
        UpdateWorkspaceSettings(fixture.repository),
        directoryChangeBlocked: () => blocked,
      );
      try {
        expect(await settings.save(40), true);
        await settings.chooseDirectory();
        expect(await settings.save(50), false);
        expect(settings.failure?.code, FailureCode.busy);
        expect(storage.relocations, 0);
        expect(fixture.timeoutSeconds, 40);
        blocked = false;
        expect(await settings.save(50), true);
        expect(storage.directoryPath, 'another-workspace');
      } finally {
        settings.dispose();
        window.dispose();
        fixture.dispose();
      }
    },
  );
}
