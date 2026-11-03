class Folder {
  const Folder(this.id, this.name);
  final String id, name;
  Folder copyWith({String? name}) => Folder(id, name ?? this.name);
  @override
  bool operator ==(Object other) =>
      other is Folder && id == other.id && name == other.name;
  @override
  int get hashCode => Object.hash(id, name);
}
