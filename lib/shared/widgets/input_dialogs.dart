import 'package:flutter/material.dart';

/// 打开名称输入弹窗并校验非空，返回去除首尾空白的结果；延迟释放输入控制器以等待关闭动画。
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
  // 弹窗关闭动画期间可能仍会访问输入框，等待动画结束后再释放控制器。
  await Future<void>.delayed(const Duration(milliseconds: 250));
  field.dispose();
  return result;
}

/// 展示需要确认的操作，关闭或取消弹窗时统一返回否定结果。
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
