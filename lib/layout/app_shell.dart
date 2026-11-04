import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.header,
    required this.rail,
    required this.sidebar,
    required this.body,
    required this.footer,
    this.notice,
  });
  final Widget header, rail, sidebar, body, footer;
  final Widget? notice;
  /// 组合桌面页头、活动栏、侧栏、主内容、通知和页脚布局。
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max(constraints.maxWidth, 1000.0);
      final height = math.max(constraints.maxHeight, 600.0);
      final content = SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            header,
            ?notice,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  rail,
                  SizedBox(width: width >= 1400 ? 270 : 250, child: sidebar),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: body),
                        footer,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      if (width == constraints.maxWidth && height == constraints.maxHeight) {
        return content;
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(child: content),
      );
    },
  );
}
