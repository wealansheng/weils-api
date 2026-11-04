class SseEvent {
  const SseEvent({required this.type, required this.id, required this.data});
  final String type, id, data;
}

/// 增量解析 SSE 事件边界与字段；UTF-8 字节解码由请求网关负责。
class SseParser {
  SseParser(this.onEvent);
  final void Function(SseEvent) onEvent;
  final _line = StringBuffer();
  final _data = <String>[];
  String _type = '', _id = '';
  bool _start = true, _afterCr = false;

  /// 增量读取已解码文本，处理起始 BOM、跨块换行及 CR、LF、CRLF，并保留尚未完成的行。
  void add(String text) {
    for (final unit in text.codeUnits) {
      if (_start) {
        _start = false;
        if (unit == 0xfeff) continue;
      }
      if (_afterCr) {
        _afterCr = false;
        if (unit == 10) continue;
      }
      if (unit == 10 || unit == 13) {
        _processLine(_line.toString());
        _line.clear();
        _afterCr = unit == 13;
      } else {
        _line.writeCharCode(unit);
      }
    }
  }

  /// 按 SSE 字段规则累积 data、event 和 id；空行派发完整事件，id 跨事件继承。
  void _processLine(String line) {
    if (line.isEmpty) {
      if (_data.isNotEmpty) {
        onEvent(
          SseEvent(
            type: _type.isEmpty ? 'message' : _type,
            id: _id,
            data: _data.join('\n'),
          ),
        );
      }
      _data.clear();
      _type = '';
      return;
    }
    if (line.startsWith(':')) return;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'data':
        _data.add(value);
      case 'event':
        _type = value;
      case 'id':
        if (!value.contains('\u0000')) _id = value;
    }
  }

  /// 从保存的原文重建完整事件列表；没有空行结束的末尾事件不派发。
  static List<SseEvent> parse(String text) {
    final events = <SseEvent>[];
    SseParser(events.add).add(text);
    return List.unmodifiable(events);
  }
}
