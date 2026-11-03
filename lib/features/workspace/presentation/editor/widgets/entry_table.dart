import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/entry.dart';
import '../../../domain/use_cases/request_headers.dart';

class EntryTable extends StatelessWidget {
  const EntryTable({
    super.key,
    required this.entries,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.kind,
    this.defaults = const [],
    this.stickyAdd = false,
  });
  final List<Entry> entries;
  final VoidCallback onAdd;
  final void Function(String, Entry Function(Entry)) onUpdate;
  final ValueChanged<String> onDelete;
  final String kind;
  final List<DefaultHeader> defaults;
  final bool stickyAdd;
  Widget _add() => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 14),
      label: Text('添加$kind', style: const TextStyle(fontSize: 12)),
    ),
  );
  Widget _defaultRow(DefaultHeader header) => Container(
    key: ValueKey('default-header-${header.name.toLowerCase()}'),
    height: 36,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: 36,
          child: Tooltip(
            message: '自动生成，添加同名 Header 可覆盖',
            child: Icon(Icons.check_rounded, size: 15, color: AppColors.muted),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SelectableText(
              header.name,
              maxLines: 1,
              style: codeStyle.copyWith(
                fontSize: 12,
                height: 1.2,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                header.value ?? '根据 URL 自动生成',
                maxLines: 1,
                style: codeStyle.copyWith(
                  fontSize: 12,
                  height: 1.2,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
        ),
        const Expanded(
          flex: 2,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '默认',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
        ),
        const SizedBox(width: 30),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 33,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 36),
            Expanded(
              flex: 3,
              child: Text(
                '$kind名',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
            const Expanded(
              flex: 4,
              child: Text(
                '值',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
            const Expanded(
              flex: 2,
              child: Text(
                '说明',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 30),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: defaults.length + entries.length + (stickyAdd ? 0 : 1),
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final automatic = defaults.indexWhere(
              (h) => 'default-header-${h.name.toLowerCase()}' == key.value,
            );
            if (automatic >= 0) return automatic;
            final custom = entries.indexWhere((e) => e.id == key.value);
            return custom >= 0 ? defaults.length + custom : null;
          },
          itemBuilder: (context, index) {
            if (index < defaults.length) return _defaultRow(defaults[index]);
            final customIndex = index - defaults.length;
            if (customIndex == entries.length) {
              return _add();
            }
            final e = entries[customIndex];
            Widget field(
              String key,
              String value,
              String hint,
              ValueChanged<String> update,
            ) => TextFormField(
              key: ValueKey('${e.id}-$key'),
              initialValue: value,
              style: codeStyle.copyWith(fontSize: 12, height: 1.2),
              decoration: InputDecoration(
                hintText: hint,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              onChanged: (v) {
                update(v);
              },
            );
            return Container(
              key: ValueKey(e.id),
              height: 36,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Checkbox(
                      semanticLabel: '启用${e.name.isEmpty ? kind : e.name}',
                      value: e.enabled,
                      onChanged: (v) {
                        onUpdate(
                          e.id,
                          (row) => row.copyWith(enabled: v ?? false),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: field(
                      'name',
                      e.name,
                      '名称',
                      (v) => onUpdate(e.id, (row) => row.copyWith(name: v)),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: field(
                      'value',
                      e.value,
                      '值',
                      (v) => onUpdate(e.id, (row) => row.copyWith(value: v)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: field(
                      'description',
                      e.description,
                      '可选',
                      (v) =>
                          onUpdate(e.id, (row) => row.copyWith(description: v)),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: IconButton(
                      tooltip: '删除$kind',
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () => onDelete(e.id),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      if (stickyAdd) SizedBox(height: 34, child: _add()),
    ],
  );
}
