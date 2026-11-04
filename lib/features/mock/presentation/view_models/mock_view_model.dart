import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:weils_api/core/errors/app_failure.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_snapshot.dart';
import 'package:weils_api/features/workspace/domain/repositories/workspace_repository.dart';
import '../../domain/entities/mock_definition.dart';
import '../../domain/repositories/mock_server.dart';

class MockViewModel extends ChangeNotifier {
  MockViewModel(this.repository, this.server) {
    _subscription = repository.changes.listen((_) {
      if (!_disposed) notifyListeners();
    });
  }
  final WorkspaceRepository repository;
  final MockServer server;
  late final StreamSubscription<WorkspaceState> _subscription;
  bool _disposed = false, busy = false;
  String search = '';
  String? error;
  WorkspaceSnapshot get snapshot => repository.state.snapshot;
  MockDefinition? get active => snapshot.activeMock;
  bool get running => server.running;
  String get address => 'http://127.0.0.1:${server.port ?? snapshot.mockPort}';
  List<MockDefinition> get definitions {
    final merged = <String, MockDefinition>{
      for (final d in snapshot.mocks) d.id: d,
      for (final d in snapshot.mockDrafts) d.id: d,
    };
    final query = search.toLowerCase();
    return merged.values
        .where(
          (d) =>
              '${d.name} ${d.method} ${d.path}'.toLowerCase().contains(query),
        )
        .toList();
  }

  void filter(String text) {
    search = text;
    notifyListeners();
  }

  void create() {
    repository.newMock();
    error = null;
    notifyListeners();
  }

  void select(String id) {
    repository.selectMock(id);
    error = null;
    notifyListeners();
  }

  void update(MockDefinition Function(MockDefinition) change) {
    if (active case final definition?) {
      repository.updateMockDraft(definition.id, change);
    }
  }

  void updateScenario(String id, MockScenario Function(MockScenario) change) =>
      update(
        (d) => d.copyWith(
          scenarios: [for (final s in d.scenarios) s.id == id ? change(s) : s],
        ),
      );
  void _result(Outcome<void> outcome) {
    if (outcome.succeeded) {
      error = null;
      return;
    }
    error = switch (outcome.failure?.code) {
      FailureCode.invalidData =>
        outcome.failure?.cause?.toString() ?? '配置无效，请检查端口和输入内容',
      FailureCode.read => '无法读取工作区，已暂停保存，请检查本地数据目录',
      _ => 'Mock 配置保存失败，请检查数据目录权限和磁盘空间',
    };
  }

  Future<bool> save() async {
    final id = active?.id;
    if (id == null || busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    final result = await repository.saveMock(id);
    if (_disposed) return result.succeeded;
    busy = false;
    _result(result);
    notifyListeners();
    return result.succeeded;
  }

  Future<void> delete(String id) async {
    if (busy) return;
    busy = true;
    notifyListeners();
    final result = await repository.deleteMock(id);
    if (_disposed) return;
    busy = false;
    _result(result);
    notifyListeners();
  }

  Future<void> toggle(String portText) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (running) {
        await server.stop();
      } else {
        final port = int.tryParse(portText);
        if (port == null || port < 1 || port > 65535) {
          error = '端口须为 1–65535 的整数';
        } else {
          final saved = await repository.setMockPort(port);
          _result(saved);
          if (saved.succeeded && !_disposed) {
            await server.start(port, () => repository.state.snapshot.mocks);
          }
        }
      }
    } on Object {
      error = '无法启动 Mock 服务，端口可能已被占用；请更换端口后重试';
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
