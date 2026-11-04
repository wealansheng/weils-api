import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/repositories/request_gateway.dart';
import 'package:weils_api/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/use_cases/send_request.dart';

/// 应用级请求执行状态，使连接在切换标签页或进入历史页面后继续接收。
class RequestExecutionViewModel extends ChangeNotifier {
  RequestExecutionViewModel(
    this.repository,
    this.sendRequest, {
    Map<String, ResponseRecord> initialResponses = const {},
  }) {
    _responses.addAll(initialResponses);
    _lastSnapshot = repository.state.snapshot;
    _subscription = repository.changes.listen((state) {
      if (identical(state.snapshot, _lastSnapshot)) return;
      _lastSnapshot = state.snapshot;
      final ids = state.snapshot.drafts.map((r) => r.id).toSet();
      _responses.removeWhere((id, _) => !ids.contains(id));
      if (_validation != null) {
        _validation = null;
        notifyListeners();
      }
    });
  }
  final WorkspaceRepository repository;
  final SendRequest sendRequest;
  late WorkspaceSnapshot _lastSnapshot;
  late final StreamSubscription<WorkspaceState> _subscription;
  final _responses = <String, ResponseRecord>{};
  RequestTask<HistoryRecord>? _task;
  StreamSubscription<ResponseRecord>? _updates;
  String? _runningId, _validationId;
  RequestValidation? _validation;
  bool _disposed = false;
  String? get runningId => _runningId;
  bool get running => _task != null;
  /// 获取指定草稿最近的实时或最终响应。
  ResponseRecord? responseFor(String id) => _responses[id];
  /// 仅为对应草稿返回当前发送校验错误。
  RequestValidation? validationFor(String id) =>
      _validationId == id ? _validation : null;
  /// 仅在执行模型未释放时通知界面刷新。
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 校验并执行单个请求，跨页面保留连接与实时响应，结束后保留已捕获内容。
  Future<void> send(RequestSpec request) async {
    if (running) return;
    _validationId = request.id;
    _validation = request.validate();
    if (_validation != null) {
      _notify();
      return;
    }
    _runningId = request.id;
    final task = sendRequest(request);
    _task = task;
    _responses.remove(request.id);
    _updates = task.updates.listen((response) {
      if (_disposed) return;
      if (repository.state.snapshot.draft(request.id) != null) {
        _responses[request.id] = response;
        _notify();
      }
    });
    _notify();
    final record = await task.result;
    unawaited(_updates?.cancel());
    _updates = null;
    if (repository.state.snapshot.draft(request.id) != null) {
      _responses[request.id] = record.response;
    }
    _task = null;
    _runningId = null;
    _notify();
  }

  /// 请求取消当前传输，最终结果仍由原任务统一收尾。
  void cancel() => _task?.cancel();
  /// 取消当前任务与实时订阅，并等待最终结果及历史保存完成，供退出流程使用。
  Future<void> stop() async {
    _task?.cancel();
    unawaited(_updates?.cancel());
    await _task?.result;
  }

  /// 取消传输和状态订阅，阻止释放后继续触发界面通知。
  @override
  void dispose() {
    _disposed = true;
    _task?.cancel();
    unawaited(_updates?.cancel());
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
