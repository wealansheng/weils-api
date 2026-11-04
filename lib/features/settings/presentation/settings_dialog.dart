import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/shared/widgets/input_dialogs.dart';

import 'formatters/settings_messages.dart';
import 'view_models/settings_view_model.dart';

/// 打开全局设置弹窗，并创建由弹窗管理生命周期的设置视图模型。
Future<void> openSettings(
  BuildContext context,
  SettingsViewModel Function() createViewModel,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => ChangeNotifierProvider(
    create: (_) => createViewModel(),
    child: Builder(
      builder: (context) =>
          _SettingsDialog(viewModel: context.read<SettingsViewModel>()),
    ),
  ),
);

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.viewModel});
  final SettingsViewModel viewModel;
  /// 创建超时、SSE 捕获上限与数据目录的表单状态。
  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final TextEditingController _timeout, _sseLimit;
  final _form = GlobalKey<FormState>();
  SettingsViewModel get vm => widget.viewModel;
  bool get _saving => vm.saving;
  bool get _choosing => vm.choosing;
  String? get _error =>
      vm.pickerFailed ? '无法打开目录选择器，请重试。' : settingsFailureMessage(vm.failure);
  /// 使用已保存的超时与 SSE 上限初始化文本输入。
  @override
  void initState() {
    super.initState();
    _timeout = TextEditingController(text: '${vm.timeout}');
    _sseLimit = TextEditingController(text: '${vm.sseMaxResponseMb}');
  }

  /// 释放设置表单的输入控制器。
  @override
  void dispose() {
    _timeout.dispose();
    _sseLimit.dispose();
    super.dispose();
  }

  /// 展示并校验全局设置，协调目录选择、保存与历史清理操作。
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => PopScope(
      canPop: !_saving && !_choosing,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '请求超时',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    enabled: !_saving && !_choosing,
                    key: const ValueKey('request-timeout-seconds'),
                    controller: _timeout,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      suffixText: '秒',
                      helperText: '1–300 秒；SSE 仅限制收到响应头之前的等待',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 300
                          ? '请填写 1–300 之间的整数'
                          : null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SSE 捕获上限',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('sse-max-response-mb'),
                    enabled: !_saving && !_choosing,
                    controller: _sseLimit,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      suffixText: 'MB',
                      helperText: '1–50 MB，达到后停止；仅影响后续 SSE 请求',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 50
                          ? '请填写 1–50 之间的整数'
                          : null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '请求历史',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '清空记录不会删除已保存的接口。',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _saving || _choosing
                            ? null
                            : () async {
                                final confirmed = await confirmAction(
                                  context,
                                  title: '清空请求历史？',
                                  detail: '将删除本机全部请求历史与响应快照，此操作无法撤销。',
                                  action: '清空历史',
                                );
                                if (confirmed) {
                                  final ok = await vm.clearHistory();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok ? '请求历史已清空' : '清空失败，原记录已保留',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: const Text('清空历史'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '本地数据目录',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('choose-data-directory'),
                        onPressed: _saving || _choosing
                            ? null
                            : vm.chooseDirectory,
                        icon: const Icon(Icons.folder_open_outlined, size: 16),
                        label: Text(_choosing ? '选择中…' : '更改目录'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.shell,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: SelectableText(
                      vm.directory,
                      key: const ValueKey('data-directory-path'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.ink,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '保存设置后，现有数据将复制到新目录，原目录保留。请选择未存放工作区数据的文件夹。',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.6,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const ValueKey('settings-error'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.red,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving || _choosing
                ? null
                : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _saving || _choosing
                ? null
                : () async {
                    if (!_form.currentState!.validate()) return;
                    final ok = await vm.save(
                      int.parse(_timeout.text),
                      sseMaxResponseMb: int.parse(_sseLimit.text),
                    );
                    if (context.mounted) {
                      if (ok) {
                        Navigator.pop(context);
                      }
                    }
                  },
            child: Text(_saving ? '保存中…' : '保存设置'),
          ),
        ],
      ),
    ),
  );
}
