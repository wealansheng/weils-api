import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/workspace_snapshot.dart';
import '../../domain/repositories/workspace_repository.dart';

/// 每个视图模型仅观察自身所需的工作区投影，减少无关状态变化引起的刷新。
abstract class RepositoryViewModel<T> extends ChangeNotifier {
  RepositoryViewModel(this.repository, T Function(WorkspaceState) select)
    : value = select(repository.state) {
    _subscription = repository.changes.listen((state) {
      final next = select(state);
      if (next == value) return;
      value = next;
      notifyListeners();
    });
  }
  @protected
  final WorkspaceRepository repository;
  @protected
  T value;
  late final StreamSubscription<WorkspaceState> _subscription;
  /// 取消仓库状态订阅，结束派生视图模型的更新。
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
