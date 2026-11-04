import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/repositories/request_gateway.dart';
import 'package:weils_api/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/use_cases/send_request.dart';

/// Application-scoped so sending survives switching tabs or opening history.
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
  String? _runningId, _validationId;
  RequestValidation? _validation;
  bool _disposed = false;
  String? get runningId => _runningId;
  bool get running => _task != null;
  ResponseRecord? responseFor(String id) => _responses[id];
  RequestValidation? validationFor(String id) =>
      _validationId == id ? _validation : null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

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
    _notify();
    final record = await task.result;
    if (repository.state.snapshot.draft(request.id) != null) {
      _responses[request.id] = record.response;
    }
    _task = null;
    _runningId = null;
    _notify();
  }

  void cancel() => _task?.cancel();
  Future<void> stop() async {
    _task?.cancel();
    await _task?.result;
  }

  @override
  void dispose() {
    _disposed = true;
    _task?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
