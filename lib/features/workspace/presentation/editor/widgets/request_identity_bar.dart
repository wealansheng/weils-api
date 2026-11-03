import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/workspace_entities.dart';
import '../../../../../shared/widgets/anchored_select.dart';

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
  });
  final RequestSpec request;
  final TextEditingController nameController;
  final bool dirty;
  final List<Folder> folders;
  final ValueChanged<String> onNameChanged, onFolderChanged;
  final VoidCallback onSave;
  RequestSpec get r => request;
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
        const SizedBox(width: 16),
        Tooltip(
          message: '保存接口 · Ctrl + S',
          child: OutlinedButton(onPressed: onSave, child: const Text('保存')),
        ),
      ],
    ),
  );
}
