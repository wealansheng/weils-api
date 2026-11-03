import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/workspace_controller.dart';
import 'theme.dart';

Future<String?> askName(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  final field = TextEditingController(text: initial);
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 340,
        child: Form(
          key: form,
          child: TextFormField(
            controller: field,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(labelText: '名称'),
            validator: (v) => v == null || v.trim().isEmpty ? '请填写名称' : null,
            onFieldSubmitted: (_) {
              if (form.currentState!.validate()) {
                Navigator.pop(context, field.text.trim());
              }
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, field.text.trim());
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
  // Dialog route transitions may retain the field for a frame after pop.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  field.dispose();
  return result;
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String detail,
  String action = '删除',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 360,
          child: Text(
            detail,
            style: const TextStyle(fontSize: 13, height: 1.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<void> openSettings(BuildContext context, WorkspaceController c) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SettingsDialog(controller: c),
    );

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.controller});
  final WorkspaceController controller;
  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final TextEditingController _timeout;
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  bool _choosing = false;
  String? _selectedDirectory, _error;

  Future<void> _chooseDirectory() async {
    setState(() {
      _choosing = true;
      _error = null;
    });
    try {
      final path = await const MethodChannel('weils/window')
          .invokeMethod<String>(
            'selectDirectory',
            _selectedDirectory ?? widget.controller.storage.directory.path,
          );
      if (mounted && path != null && path.isNotEmpty) {
        setState(() => _selectedDirectory = path);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '无法打开目录选择器，请重试。');
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _timeout = TextEditingController(
      text: '${widget.controller.timeoutSeconds}',
    );
  }

  @override
  void dispose() {
    _timeout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
                  controller: _timeout,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    suffixText: '秒',
                    helperText: '1–300 秒，适用于下一次发送的请求',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 300
                        ? '请填写 1–300 之间的整数'
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
                                final ok = await widget.controller
                                    .clearHistory();
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
                      onPressed: _saving || _choosing ? null : _chooseDirectory,
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
                    _selectedDirectory ??
                        widget.controller.storage.directory.path,
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
          onPressed: _saving || _choosing ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving || _choosing
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  final ok = await widget.controller.updateSettings(
                    timeout: int.parse(_timeout.text),
                    directoryPath: _selectedDirectory,
                  );
                  if (context.mounted) {
                    setState(() {
                      _saving = false;
                      _error = widget.controller.settingsError;
                    });
                    if (ok) {
                      Navigator.pop(context);
                    }
                  }
                },
          child: Text(_saving ? '保存中…' : '保存设置'),
        ),
      ],
    ),
  );
}

Future<void> openHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    title: const Text(
      '帮助文档',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
    content: SizedBox(
      width: 570,
      height: 410,
      child: ListView(
        children: const [
          _HelpItem(
            '新建与组织接口',
            '点击“新建 HTTP 接口”或侧栏加号创建请求。加号菜单也可新建文件夹；右键接口或文件夹可重命名、删除。搜索支持接口名称和 URL。',
          ),
          _HelpItem(
            '编辑与发送',
            '选择 HTTP 方法，填写完整的 http:// 或 https:// 地址。Params 和 Headers 使用启用勾选框；Params 中同名字段会覆盖地址里的查询参数。Body 支持 JSON 与原始文本，认证支持 Bearer Token。',
          ),
          _HelpItem(
            '保存与草稿',
            'Ctrl + S 保存当前接口。未保存内容会保留为本地草稿；关闭标签页或退出应用时，可以保存、放弃修改或取消关闭。发送请求不会自动保存接口定义。',
          ),
          _HelpItem(
            '查看响应',
            'Ctrl + Enter 发送当前请求，再次操作可取消。下方显示真实状态码、耗时、大小、正文和响应头。JSON 可格式化，非 JSON 保留原文。响应捕获上限为 2 MB，超出时明确提示截断。',
          ),
          _HelpItem(
            '从历史继续调试',
            '每次发送都会记录请求与结果，包括失败和取消。历史记录先以只读快照打开；点击“编辑并重发”生成独立草稿，原记录保持不变。',
          ),
          _HelpItem(
            '本地使用',
            '接口、草稿、认证信息与请求历史存放在本机数据目录。设置中可以调整超时或清空历史。关闭应用不会自动清空历史。',
          ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('知道了'),
      ),
    ],
  ),
);

class _HelpItem extends StatelessWidget {
  const _HelpItem(this.title, this.text);
  final String title, text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
            height: 1.9,
          ),
        ),
      ],
    ),
  );
}
