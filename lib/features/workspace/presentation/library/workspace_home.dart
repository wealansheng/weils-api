import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/shared/widgets/api_mark.dart';

class WorkspaceHome extends StatelessWidget {
  const WorkspaceHome({
    super.key,
    required this.onCreate,
    required this.onImportCurl,
  });
  final VoidCallback onCreate;
  final VoidCallback onImportCurl;

  /// 展示接口管理空状态、新建入口与常用快捷键说明。
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ApiMark(size: 42),
          const SizedBox(height: 27),
          const Text(
            '从一个接口开始',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '创建你的第一个接口，开始调试',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 31),
          SizedBox(
            height: 39,
            child: FilledButton.icon(
              key: const ValueKey('create-request'),
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建 HTTP 接口'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            key: const ValueKey('import-curl-home'),
            onPressed: onImportCurl,
            icon: const Icon(Icons.terminal, size: 17),
            label: const Text('导入 cURL'),
          ),
        ],
      ),
    ),
  );
}
