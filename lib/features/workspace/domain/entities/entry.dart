import 'package:weils_api/core/utils/identity.dart';

class Entry {
  Entry({
    String? id,
    this.name = '',
    this.value = '',
    this.description = '',
    this.enabled = true,
  }) : id = id ?? newId();
  final String id, name, value, description;
  final bool enabled;
  /// 保留条目标识并复制参数或 Header，未指定的字段沿用原值。
  Entry copyWith({
    String? name,
    String? value,
    String? description,
    bool? enabled,
  }) => Entry(
    id: id,
    name: name ?? this.name,
    value: value ?? this.value,
    description: description ?? this.description,
    enabled: enabled ?? this.enabled,
  );
  @override
  bool operator ==(Object other) =>
      other is Entry &&
      id == other.id &&
      name == other.name &&
      value == other.value &&
      description == other.description &&
      enabled == other.enabled;
  @override
  int get hashCode => Object.hash(id, name, value, description, enabled);
}
