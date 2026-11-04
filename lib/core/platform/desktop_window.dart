import 'dart:async';

import 'package:flutter/services.dart';

abstract interface class DesktopWindow {
  Stream<void> get closeRequests;
  /// 请求原生窗口关闭，调用方负责提前完成保存和请求取消。
  Future<void> close();
  /// 打开目录选择器，用户取消时返回空值。
  Future<String?> selectDirectory(String initialPath);
  /// 释放窗口服务的事件监听等资源。
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
  /// 通过平台通道执行原生窗口关闭。
  @override
  Future<void> close() => _channel.invokeMethod<void>('close');
  /// 将当前目录传给原生选择器，并返回用户选择的目录。
  @override
  Future<String?> selectDirectory(String initialPath) =>
      _channel.invokeMethod<String>('selectDirectory', initialPath);
  /// 移除平台调用处理器并关闭窗口事件流。
  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_closeRequests.close());
  }
}
