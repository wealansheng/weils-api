class Folder {
  const Folder(this.id, this.name);
  final String id, name;
  /// 保留目录标识，仅替换指定的目录名称。
  Folder copyWith({String? name}) => Folder(id, name ?? this.name);
  @override
  bool operator ==(Object other) =>
      other is Folder && id == other.id && name == other.name;
  @override
  int get hashCode => Object.hash(id, name);
}
