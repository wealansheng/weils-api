import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';

class ResponseHeadersTable extends StatelessWidget {
  const ResponseHeadersTable({super.key, required this.headers});

  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final nameWidth = (constraints.maxWidth * .32).clamp(160.0, 280.0);
        final entries = headers.entries.toList();
        Widget row(String name, String value, {bool heading = false}) => Table(
          columnWidths: {0: FixedColumnWidth(nameWidth)},
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          border: const TableBorder(
            bottom: BorderSide(color: AppColors.line),
            verticalInside: BorderSide(color: AppColors.line),
          ),
          children: [
            TableRow(
              decoration: heading
                  ? const BoxDecoration(color: Color(0xFFF8FAFC))
                  : null,
              children: [
                for (final cell in [(name, 'name'), (value, 'value')])
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: heading ? 8 : 9,
                    ),
                    child: Semantics(
                      header: heading,
                      child: Text(
                        cell.$1,
                        key: heading
                            ? null
                            : ValueKey('response-header-${cell.$2}-$name'),
                        style: heading
                            ? const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.muted,
                              )
                            : codeStyle.copyWith(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
        return SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row('名称', '值', heading: true),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无响应头',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        key: const ValueKey('response-headers-rows'),
                        padding: EdgeInsets.zero,
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return row(entry.key, entry.value);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
