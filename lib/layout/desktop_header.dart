import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../shared/widgets/api_mark.dart';

class DesktopHeader extends StatelessWidget {
  const DesktopHeader({super.key, required this.onSettings});
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(
      color: AppColors.shell,
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        const ApiMark(size: 19),
        const SizedBox(width: 12),
        const Text(
          'Weils API',
          style: TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          width: 1,
          height: 17,
          margin: const EdgeInsets.symmetric(horizontal: 21),
          color: AppColors.line,
        ),
        const Text(
          '本地工作区',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, size: 18),
          style: TextButton.styleFrom(foregroundColor: AppColors.ink),
          label: const Text('设置'),
        ),
      ],
    ),
  );
}
