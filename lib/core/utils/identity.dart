int _sequence = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

bool sameItems<T>(List<T> a, List<T> b) =>
    identical(a, b) ||
    (a.length == b.length &&
        Iterable<int>.generate(a.length).every((i) => a[i] == b[i]));
