import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/shared/widgets/anchored_select.dart';

import '../../domain/entities/request_spec.dart';
import '../../domain/use_cases/curl_codec.dart';

/// 打开 cURL 导入弹窗；仅在解析成功后返回新请求，取消或失败均不修改工作区。
Future<RequestSpec?> openCurlImportDialog(
  BuildContext context, {
  required String folderId,
}) => showDialog<RequestSpec>(
  context: context,
  builder: (_) => _CurlImportDialog(folderId: folderId),
);

class _CurlImportDialog extends StatefulWidget {
  const _CurlImportDialog({required this.folderId});
  final String folderId;

  /// 创建命令文本、格式选择与解析错误的局部状态。
  @override
  State<_CurlImportDialog> createState() => _CurlImportDialogState();
}

class _CurlImportDialogState extends State<_CurlImportDialog> {
  final _command = TextEditingController();
  CurlShell _shell = CurlShell.bash;
  String? _error;

  /// 释放弹窗持有的命令输入控制器。
  @override
  void dispose() {
    _command.dispose();
    super.dispose();
  }

  /// 校验命令并返回独立草稿，保留解析错误供用户修正后重试。
  void _import() {
    try {
      final request = CurlCodec.parse(
        _command.text,
        folderId: widget.folderId,
        shell: _shell,
      );
      Navigator.pop(context, request);
    } on CurlFormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  /// 展示命令粘贴区、格式选项和可恢复的错误提示，适应较小桌面窗口。
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    title: const Text(
      '导入 cURL',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
    content: SizedBox(
      width: 640,
      height: math.max(
        160,
        math.min(400, MediaQuery.sizeOf(context).height - 240),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('命令格式', style: TextStyle(fontSize: 13)),
              ),
              AnchoredSelect(
                id: 'curl-import-shell',
                label: 'cURL 命令格式',
                value: _shell.name,
                width: 160,
                menuWidth: 200,
                options: const [
                  SelectOption('bash', 'Bash'),
                  SelectOption('powerShell', 'PowerShell 7'),
                ],
                onChanged: (v) => setState(() {
                  _shell = CurlShell.values.byName(v);
                  _error = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '浏览器请选择“复制为 cURL（bash）”。导入后创建新草稿，不会自动发送请求。',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.6),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TextField(
              key: const ValueKey('curl-import-command'),
              controller: _command,
              autofocus: true,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: codeStyle.copyWith(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'cURL 命令',
                alignLabelWithHint: true,
                hintText: "curl 'https://api.example.com/users'",
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: const ValueKey('curl-import-error'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.red,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('curl-import-confirm'),
        onPressed: _import,
        child: const Text('导入为新请求'),
      ),
    ],
  );
}
