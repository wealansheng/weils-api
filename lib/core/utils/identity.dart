int _sequence = 0;
/// 组合微秒时间戳与进程内递增序号，避免同一时刻创建的实体标识重复。
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

/// 按顺序比较列表内容；同一列表实例可直接判定相等。
bool sameItems<T>(List<T> a, List<T> b) =>
    identical(a, b) ||
    (a.length == b.length &&
        Iterable<int>.generate(a.length).every((i) => a[i] == b[i]));
