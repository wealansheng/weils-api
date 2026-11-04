import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/shared/widgets/anchored_select.dart';
import 'package:weils_api/features/workspace/domain/use_cases/curl_codec.dart';

class RequestIdentityBar extends StatelessWidget {
  const RequestIdentityBar({
    super.key,
    required this.request,
    required this.nameController,
    required this.dirty,
    required this.folders,
    required this.onNameChanged,
    required this.onFolderChanged,
    required this.onSave,
    required this.onExportCurl,
  });
  final RequestSpec request;
  final TextEditingController nameController;
  final bool dirty;
  final List<Folder> folders;
  final ValueChanged<String> onNameChanged, onFolderChanged;
  final VoidCallback onSave;
  final ValueChanged<CurlShell> onExportCurl;
  RequestSpec get r => request;

  /// 展示接口名称、所属目录和保存入口，并标记当前草稿的未保存状态。
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
    child: Row(
      children: [
        Expanded(
          child: SizedBox(
            width: 240,
            height: 34,
            child: TextField(
              key: const ValueKey('request-name'),
              controller: nameController,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: '接口名称',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 7),
              ),
              onChanged: onNameChanged,
            ),
          ),
        ),
        if (dirty)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text(
              '未保存',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
        const Spacer(),
        Icon(Icons.folder_outlined, size: 15, color: AppColors.muted),
        const SizedBox(width: 5),
        AnchoredSelect(
          id: 'request-folder',
          label: '所属模块',
          value: r.folderId,
          width: 130,
          menuWidth: 220,
          options: folders.map((f) => SelectOption(f.id, f.name)).toList(),
          onChanged: onFolderChanged,
        ),
        const SizedBox(width: 8),
        PopupMenuButton<CurlShell>(
          key: const ValueKey('export-curl'),
          tooltip: '复制为 cURL',
          icon: const Icon(Icons.terminal, size: 18),
          position: PopupMenuPosition.under,
          onSelected: onExportCurl,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: CurlShell.bash,
              key: ValueKey('export-curl-bash'),
              child: Text('复制 cURL（Bash）'),
            ),
            PopupMenuItem(
              value: CurlShell.powerShell,
              key: ValueKey('export-curl-powershell'),
              child: Text('复制 cURL（PowerShell 7）'),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: '保存接口 · Ctrl + S',
          child: OutlinedButton(onPressed: onSave, child: const Text('保存')),
        ),
      ],
    ),
  );
}
