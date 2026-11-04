import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class DesktopFooter extends StatelessWidget {
  const DesktopFooter({super.key, required this.onHelp});
  final VoidCallback onHelp;
  /// 展示桌面应用底部状态与帮助入口。
  @override
  Widget build(BuildContext context) => Container(
    height: 33,
    padding: const EdgeInsets.only(right: 15),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: onHelp,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            minimumSize: const Size(0, 28),
          ),
          icon: const Icon(Icons.menu_book_outlined, size: 16),
          label: const Text('帮助文档', style: TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );
}
