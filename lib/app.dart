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
  @override
  State<WeilsApp> createState() => _WeilsAppState();
}

class _WeilsAppState extends State<WeilsApp> {
  late final _dependencies =
      widget.dependencies ?? createProductionDependencies();
  @override
  void initState() {
    super.initState();
    if (!_dependencies.workspace.state.ready) {
      unawaited(_dependencies.workspace.initialize());
    }
  }

  @override
  void dispose() {
    if (widget.dependencies == null) _dependencies.dispose();
    super.dispose();
  }

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
