import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/workspace_snapshot.dart';
import '../../domain/repositories/workspace_repository.dart';

/// Each VM observes only its projection, not every workspace change.
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
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
