import '../../data/collection_query.dart';
import '../../data/vocabulary_repository.dart';
import '../../data/vocabulary_normalization.dart';

enum VocabularyViewMode { compact, detailed }

enum VocabularySort {
  original,
  targetAscending,
  targetDescending,
  nativeAscending,
  nativeDescending,
  newest,
  oldest,
}

final class CollectionViewPreferences {
  const CollectionViewPreferences({
    this.mode = VocabularyViewMode.compact,
    this.targetFirst = true,
    this.grouping,
    this.sort = VocabularySort.original,
  });
  final VocabularyViewMode mode;
  final bool targetFirst;
  final String? grouping;
  final VocabularySort sort;
  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'targetFirst': targetFirst,
    'grouping': grouping,
    'sort': sort.name,
  };
  factory CollectionViewPreferences.fromJson(Map<String, dynamic> json) =>
      CollectionViewPreferences(
        mode:
            VocabularyViewMode.values
                .where((v) => v.name == json['mode'])
                .firstOrNull ??
            VocabularyViewMode.compact,
        targetFirst: json['targetFirst'] != false,
        grouping: json['grouping'] is String
            ? json['grouping'] as String
            : null,
        sort:
            VocabularySort.values
                .where((v) => v.name == json['sort'])
                .firstOrNull ??
            VocabularySort.original,
      );
  @override
  bool operator ==(Object other) =>
      other is CollectionViewPreferences &&
      mode == other.mode &&
      targetFirst == other.targetFirst &&
      grouping == other.grouping &&
      sort == other.sort;
  @override
  int get hashCode => Object.hash(mode, targetFirst, grouping, sort);
}

List<VocabularyRecord> sortVocabulary(
  List<VocabularyRecord> entries,
  VocabularySort sort,
) {
  if (sort == VocabularySort.original) return List.of(entries);
  final order = {for (var i = 0; i < entries.length; i++) entries[i].id: i};
  return List<VocabularyRecord>.of(entries)..sort((a, b) {
    int result;
    if (sort == VocabularySort.newest || sort == VocabularySort.oldest) {
      if (a.addedAt == null || b.addedAt == null) {
        result = a.addedAt == b.addedAt
            ? 0
            : a.addedAt == null
            ? 1
            : -1;
      } else {
        result =
            a.addedAt!.compareTo(b.addedAt!) *
            (sort == VocabularySort.newest ? -1 : 1);
      }
    } else {
      final target =
          sort == VocabularySort.targetAscending ||
          sort == VocabularySort.targetDescending;
      result = compareVocabularyLabels(
        target ? a.targetText : a.nativeText,
        target ? b.targetText : b.nativeText,
      );
      if (sort == VocabularySort.targetDescending ||
          sort == VocabularySort.nativeDescending) {
        result = -result;
      }
    }
    return result != 0 ? result : order[a.id]!.compareTo(order[b.id]!);
  });
}

final class VocabularyViewGroup {
  const VocabularyViewGroup(this.id, this.name, this.entries);
  final String? id, name;
  final List<VocabularyRecord> entries;
}

List<VocabularyViewGroup> groupVocabulary(
  CollectionQuerySnapshot snapshot,
  CollectionViewPreferences view,
) {
  final entries = sortVocabulary(snapshot.entries, view.sort),
      dimension = view.grouping;
  if (dimension == null || !snapshot.categoryValues.containsKey(dimension)) {
    return [VocabularyViewGroup(null, null, entries)];
  }
  final values = List.of(snapshot.categoryValues[dimension]!)
    ..sort((a, b) => compareVocabularyLabels(a.name, b.name));
  final grouped = <VocabularyViewGroup>[];
  for (final value in values) {
    final members = entries
        .where(
          (entry) =>
              snapshot.assignments[entry.id]?.any(
                (a) =>
                    a.dimensionId == dimension && a.valueIds.contains(value.id),
              ) ??
              false,
        )
        .toList();
    if (members.isNotEmpty) {
      grouped.add(VocabularyViewGroup(value.id, value.name, members));
    }
  }
  final unassigned = entries
      .where(
        (entry) =>
            !(snapshot.assignments[entry.id]?.any(
                  (a) => a.dimensionId == dimension && a.valueIds.isNotEmpty,
                ) ??
                false),
      )
      .toList();
  if (unassigned.isNotEmpty) {
    grouped.add(VocabularyViewGroup('unassigned', null, unassigned));
  }
  return grouped;
}
