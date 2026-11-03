import 'package:flutter/material.dart';

import 'core/workspace_controller.dart';
import 'ui/theme.dart';
import 'ui/workspace_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeilsApp());
}

class WeilsApp extends StatefulWidget {
  const WeilsApp({super.key, this.controller});
  final WorkspaceController? controller;
  @override
  State<WeilsApp> createState() => _WeilsAppState();
}

class _WeilsAppState extends State<WeilsApp> {
  late final WorkspaceController _controller;
  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? WorkspaceController();
    if (!_controller.ready) _controller.initialize();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Weils API',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: WorkspacePage(controller: _controller),
  );
}
