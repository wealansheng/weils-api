import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/dependencies/app_dependencies.dart';
import 'app/dependencies/app_providers.dart';
import 'app/navigation/workspace_root.dart';
import 'core/theme/app_theme.dart';

class WeilsApp extends StatefulWidget {
  const WeilsApp({super.key, this.dependencies});
  final AppDependencies? dependencies;
  /// 创建应用依赖的初始化与释放状态。
  @override
  State<WeilsApp> createState() => _WeilsAppState();
}

class _WeilsAppState extends State<WeilsApp> {
  late final _dependencies =
      widget.dependencies ?? createProductionDependencies();
  /// 在工作区尚未就绪时启动异步加载，避免重复初始化注入的依赖。
  @override
  void initState() {
    super.initState();
    if (!_dependencies.workspace.state.ready) {
      unawaited(_dependencies.workspace.initialize());
    }
  }

  /// 释放应用自行创建的依赖；外部注入的依赖由调用方管理。
  @override
  void dispose() {
    if (widget.dependencies == null) _dependencies.dispose();
    super.dispose();
  }

  /// 注入共享依赖并创建使用统一主题的桌面应用入口。
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: appProviders(_dependencies),
    child: MaterialApp(
      title: 'Weils API',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: WorkspaceRoot(userAgent: _dependencies.userAgent),
    ),
  );
}
