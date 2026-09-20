/// One department an employee can be filed under.
///
/// [inUse] is the number of employees currently in it. It is not stored — it
/// is counted on each read, because it decides what the admin is warned about
/// before deleting one, and a stale count there would be worse than none.
class DepartmentModel {
  final String id;
  final String name;
  final int inUse;

  const DepartmentModel({required this.id, required this.name, this.inUse = 0});

  /// A department that exists only because employees are in it — carried over
  /// from before the list existed, or written straight into the database by an
  /// import. It is offered by the picker like any other, and gets a row of its
  /// own the moment the admin renames it.
  bool get isUnlisted => id.isEmpty;

  factory DepartmentModel.fromJson(Map<String, dynamic> json) =>
      DepartmentModel(
        id: json['id'] as String? ?? '',
        name: (json['name'] as String? ?? '').trim(),
        inUse: (json['in_use'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
