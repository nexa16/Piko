import '../shared/generated_catalogs.dart';

/// Stable local presentation keys; order and palette belong to the shared catalog.
List<String> get categoryTagRoles => List<String>.unmodifiable(
  ((designCatalog['categoryTags'] as Map<String, Object?>)['roles'] as List)
      .cast<String>(),
);
String categoryTagRole(String? role, String groupId) {
  final roles = categoryTagRoles;
  if (roles.contains(role)) return role!;
  final hash = groupId.codeUnits.fold<int>(
    0,
    (a, b) => (a * 31 + b) & 0x7fffffff,
  );
  return roles[hash % roles.length];
}

String allocateCategoryTagRole(Iterable<String?> used) {
  final counts = {for (final key in categoryTagRoles) key: 0};
  for (final key in used) {
    if (counts.containsKey(key)) counts[key!] = counts[key]! + 1;
  }
  return counts.keys.reduce((a, b) => counts[b]! < counts[a]! ? b : a);
}
