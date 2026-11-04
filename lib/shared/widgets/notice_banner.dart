import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.message, this.onDismiss});
  final String message;
  final VoidCallback? onDismiss;
  /// 展示工作区通知，并在允许时提供关闭提示入口。
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFFFF6E6),
    padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: AppColors.amber),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        if (onDismiss != null)
          IconButton(
            tooltip: '关闭提示',
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 15),
          ),
      ],
    ),
  );
}
