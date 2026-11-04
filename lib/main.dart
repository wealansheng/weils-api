import 'package:flutter/widgets.dart';

import 'app.dart';

/// 启动 Flutter 应用并交由应用组件初始化依赖。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeilsApp());
}
