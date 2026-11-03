import '../entities/mock_definition.dart';

abstract interface class MockServer {
  bool get running;
  int? get port;
  Future<void> start(int port, List<MockDefinition> Function() definitions);
  Future<void> stop();
  void dispose();
}
