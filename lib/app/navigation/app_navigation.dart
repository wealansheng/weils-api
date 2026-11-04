import 'package:flutter/foundation.dart';

enum AppDestination { workspace, history, mock }

class AppNavigation extends ChangeNotifier {
  AppDestination _destination = AppDestination.workspace;
  AppDestination get destination => _destination;
  bool get historyMode => destination == AppDestination.history;
  /// 更新当前导航目标，仅在目标变化时通知界面。
  void select(AppDestination destination) {
    if (_destination == destination) return;
    _destination = destination;
    notifyListeners();
  }
}
