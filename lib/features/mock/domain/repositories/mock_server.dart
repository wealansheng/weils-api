import '../entities/mock_definition.dart';

abstract interface class MockServer {
  bool get running;
  int? get port;
  /// 启动指定端口的服务，使用回调获取已保存的 Mock 定义。
  Future<void> start(int port, List<MockDefinition> Function() definitions);
  /// 停止监听并释放进行中的服务请求。
  Future<void> stop();
  /// 释放服务资源，结束其生命周期。
  void dispose();
}
