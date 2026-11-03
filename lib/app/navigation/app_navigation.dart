import 'package:flutter/foundation.dart';

enum AppDestination { workspace, history, mock }

class AppNavigation extends ChangeNotifier {
  AppDestination _destination = AppDestination.workspace;
  AppDestination get destination => _destination;
  bool get historyMode => destination == AppDestination.history;
  void select(AppDestination destination) {
    if (_destination == destination) return;
    _destination = destination;
    notifyListeners();
  }
}
