import 'dart:async';

import 'package:flutter/services.dart';

abstract interface class DesktopWindow {
  Stream<void> get closeRequests;
  Future<void> close();
  Future<String?> selectDirectory(String initialPath);
  void dispose();
}

class MethodChannelDesktopWindow implements DesktopWindow {
  static const _channel = MethodChannel('weils/window');
  final _closeRequests = StreamController<void>.broadcast(sync: true);

  MethodChannelDesktopWindow() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'closeRequested') _closeRequests.add(null);
    });
  }

  @override
  Stream<void> get closeRequests => _closeRequests.stream;
  @override
  Future<void> close() => _channel.invokeMethod<void>('close');
  @override
  Future<String?> selectDirectory(String initialPath) =>
      _channel.invokeMethod<String>('selectDirectory', initialPath);
  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_closeRequests.close());
  }
}
