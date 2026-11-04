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
  /// 合并已保存定义与草稿，同标识优先显示草稿，再按名称、方法和路径筛选。
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

  /// 更新 Mock 搜索文本并通知列表刷新。
  void filter(String text) {
    search = text;
    notifyListeners();
  }

  /// 新建并选中 Mock 草稿，清除上一次操作错误。
  void create() {
    repository.newMock();
    error = null;
    notifyListeners();
  }

  /// 打开指定 Mock 的编辑草稿，并清除上一次操作错误。
  void select(String id) {
    repository.selectMock(id);
    error = null;
    notifyListeners();
  }

  /// 将当前 Mock 的不可变编辑操作交给仓库处理。
  void update(MockDefinition Function(MockDefinition) change) {
    if (active case final definition?) {
      repository.updateMockDraft(definition.id, change);
    }
  }

  /// 按场景标识更新当前 Mock，其余场景保持原有顺序。
  void updateScenario(String id, MockScenario Function(MockScenario) change) =>
      update(
        (d) => d.copyWith(
          scenarios: [for (final s in d.scenarios) s.id == id ? change(s) : s],
        ),
      );
  /// 将仓库操作结果转换为可展示的 Mock 错误信息。
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

  /// 防止并发提交，保存当前 Mock 并更新成功或失败状态。
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

  /// 删除指定 Mock，在异步操作结束后更新界面反馈。
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

  /// 切换 Mock 服务状态；启动前校验并保存端口，使用已保存定义提供响应。
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

  /// 取消仓库订阅，并阻止异步操作结束后继续通知已释放的界面。
  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
