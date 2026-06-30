/// Dart mirror of the Money service's `CategoryResponse` (ADR-0024) — one entry in
/// the managed category overlay (system built-ins + the user's own categories).
///
/// [isSystem] marks the immutable built-ins the client can't edit. [serviceTypes]
/// is the domain-link hint carried by system categories only (e.g. Books →
/// `["books"]`); it is null for user categories.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.isSystem,
    this.serviceTypes,
  });

  /// Server category id (a Guid, as a string). The one budgeting category a
  /// spending line references.
  final String id;

  final String name;

  /// True for the built-in system categories (immutable).
  final bool isSystem;

  /// Domain services a system category maps to; null for user categories.
  final List<String>? serviceTypes;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        isSystem: json['system'] as bool,
        serviceTypes: (json['serviceTypes'] as List<dynamic>?)
            ?.map((x) => x as String)
            .toList(),
      );
}
