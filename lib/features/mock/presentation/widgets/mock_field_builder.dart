import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:weils_api/shared/widgets/anchored_select.dart';
import '../../domain/entities/mock_definition.dart';
import '../../domain/use_cases/generate_mock.dart';
import 'mock_input.dart';

class _Field {
  _Field();
  final key = UniqueKey();
  String name = '', type = 'constant', value = 'null', count = '5';
}

/// 打开字段表单，成功应用时返回生成的 JSON 模板，取消时返回空值。
Future<String?> openMockFieldBuilder(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _FieldBuilder());

class _FieldBuilder extends StatefulWidget {
  const _FieldBuilder();
  /// 创建字段列表、字段类型与模板校验提示状态。
  @override
  State<_FieldBuilder> createState() => _FieldBuilderState();
}

class _FieldBuilderState extends State<_FieldBuilder> {
  final _fields = [_Field()];
  String? _error;
  /// 将字段表单转换为 JSON 模板，校验字段唯一性与生成规则后返回结果。
  void _apply() {
    try {
      final template = <String, Object?>{};
      final names = <String>{};
      for (final field in _fields) {
        final name = field.name.trim();
        if (name.isEmpty || name.contains('|') || !names.add(name)) {
          throw const MockValidationException('字段名不能为空、重复或包含 |');
        }
        switch (field.type) {
          case 'constant':
            template[name] = jsonDecode(field.value);
          case 'random':
            template[name] = field.value;
          case 'object':
            final value = jsonDecode(field.value);
            if (value is! Map) {
              throw const MockValidationException('对象字段的模板须为 JSON 对象');
            }
            template[name] = value;
          case 'array':
            final count = int.tryParse(field.count);
            if (count == null || count < 0 || count > 1000) {
              throw const MockValidationException('数组数量须在 0–1000 之间');
            }
            // 使用两端相等的范围规则，使数量为 1 时仍生成数组。
            template['$name|$count-$count'] = [jsonDecode(field.value)];
        }
      }
      final source = const JsonEncoder.withIndent('  ').convert(template);
      MockGenerator().generate(source);
      Navigator.pop(context, source);
    } on Object catch (e) {
      setState(
        () => _error = e is FormatException
            ? '值须为合法 JSON，字符串请加双引号'
            : e.toString(),
      );
    }
  }

  /// 构建常量、随机值、对象及数组字段的模板编辑表单。
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('字段表生成模板'),
    content: SizedBox(
      width: 700,
      height: 390,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '常量填写 JSON；随机值填写 @integer(1, 100) 等占位符。对象与数组项可填写嵌套 JSON 模板。',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final field in _fields)
                  Padding(
                    key: field.key,
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: MockInput(
                                value: field.name,
                                label: '字段名',
                                onChanged: (v) => field.name = v,
                              ),
                            ),
                            const SizedBox(width: 10),
                            AnchoredSelect(
                              id: 'field-${field.key}',
                              label: '字段类型',
                              value: field.type,
                              width: 105,
                              height: 40,
                              options: const [
                                SelectOption('constant', '常量'),
                                SelectOption('random', '随机值'),
                                SelectOption('object', '对象'),
                                SelectOption('array', '数组'),
                              ],
                              onChanged: (v) => setState(() {
                                field.type = v;
                                field.value = switch (v) {
                                  'random' => '@cname',
                                  'object' => '{"id":"@guid"}',
                                  'array' => '{"id|+1":1,"name":"@cname"}',
                                  _ => 'null',
                                };
                              }),
                            ),
                            if (field.type == 'array') ...[
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 70,
                                child: MockInput(
                                  value: field.count,
                                  label: '数量',
                                  onChanged: (v) => field.count = v,
                                ),
                              ),
                            ],
                            IconButton(
                              tooltip: '删除字段',
                              onPressed: () =>
                                  setState(() => _fields.remove(field)),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        MockInput(
                          value: field.value,
                          label: field.type == 'array'
                              ? '数组项模板（JSON）'
                              : '值 / 模板',
                          monospace: true,
                          lines: field.type == 'object' || field.type == 'array'
                              ? 3
                              : 1,
                          onChanged: (v) => field.value = v,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _fields.add(_Field())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加字段'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('apply-field-template'),
        onPressed: _apply,
        child: const Text('应用模板'),
      ),
    ],
  );
}
