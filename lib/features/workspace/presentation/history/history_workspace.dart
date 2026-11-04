import 'package:flutter/material.dart';

import 'package:weils_api/shared/widgets/empty_message.dart';
import '../../domain/entities/history_record.dart';
import 'history_detail.dart';
import 'view_models/history_view_model.dart';

class HistoryWorkspace extends StatelessWidget {
  const HistoryWorkspace({
    super.key,
    required this.viewModel,
    required this.onReplay,
    required this.onLeave,
  });
  final HistoryViewModel viewModel;
  final ValueChanged<HistoryRecord> onReplay;
  final VoidCallback onLeave;
  /// 显示选中历史的详情，提供重发与返回接口管理入口。
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final record = viewModel.selectedHistory;
      return record == null
          ? EmptyMessage(
              icon: Icons.history_rounded,
              title: '从历史中继续调试',
              subtitle: '选中一条记录查看请求与响应快照，或先发送一个请求。',
              action: TextButton(
                onPressed: onLeave,
                child: const Text('前往接口管理'),
              ),
            )
          : HistoryDetail(
              key: ValueKey(record.id),
              record: record,
              onReplay: () => onReplay(record),
            );
    },
  );
}
