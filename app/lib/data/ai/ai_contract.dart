import 'dart:convert';
import '../categories_repository.dart';
import '../vocabulary_content.dart';
import '../vocabulary_normalization.dart';
import '../vocabulary_repository.dart';

/// This availability switch is deliberately independent of service authorization.
const pikoAiEnabled = bool.fromEnvironment('PIKO_AI_ENABLED');

enum AiAction { generate, gaps, hints, review }

enum AiFailure {
  disabled,
  unavailable,
  accessDenied,
  limit,
  contextLimit,
  network,
  timeout,
  invalidResponse,
  stale,
  collision,
  dependency,
  consumed,
}

enum AiOutcome { change, keep, noHintNeeded, unresolved, requiresNewMeaning }

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final e in value.entries) e.key as String: _freeze(e.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is Iterable) return value.map(_canonical).toList();
  return value;
}

String aiContentKey(Object? value) => jsonEncode(_canonical(value));
bool aiSourceName(String name) =>
    {'source', 'quelle'}.contains(vocabularyIdentityKey(name));

final class AiGroup {
  AiGroup(this.dimension, Iterable<CategoryValueRecord> values)
    : values = List.unmodifiable(values);
  final CategoryDimensionRecord dimension;
  final List<CategoryValueRecord> values;
  Map<String, Object?> toJson() => {
    'id': dimension.id,
    'name': dimension.name,
    'mode': dimension.mode.name,
    'values': [
      for (final v in values) {'id': v.id, 'name': v.name},
    ],
  };
}

final class AiEntry {
  AiEntry(this.record, Map<String, Set<String>> assignments)
    : assignments = Map.unmodifiable({
        for (final e in assignments.entries)
          e.key: Set<String>.unmodifiable(e.value),
      });
  final VocabularyRecord record;
  final Map<String, Set<String>> assignments;
  Map<String, Object?> toJson({
    bool examples = true,
    Set<String> excludedGroups = const {},
  }) => {
    'id': record.id,
    'target': record.targetText,
    'native': record.nativeText,
    'hint': record.content.hintText,
    if (examples)
      'examples': [
        for (final e in record.content.examples)
          {'target': e.targetText, 'native': e.nativeText},
      ],
    'assignments': {
      for (final e in assignments.entries)
        if (!excludedGroups.contains(e.key)) e.key: (e.value.toList()..sort()),
    },
  };
}

final class AiSnapshot {
  AiSnapshot({
    required this.collectionId,
    required this.targetLanguage,
    required this.nativeLanguage,
    required Iterable<AiEntry> entries,
    required Iterable<AiGroup> groups,
  }) : entries = List.unmodifiable(entries),
       groups = List.unmodifiable(groups);
  final String collectionId, targetLanguage, nativeLanguage;
  final List<AiEntry> entries;
  final List<AiGroup> groups;
  Map<String, Object?> toJson({
    bool compact = false,
    bool excludeSource = false,
  }) {
    final source = {
      for (final g in groups)
        if (aiSourceName(g.dimension.name)) g.dimension.id,
    };
    final pairCounts = <String, int>{};
    for (final e in entries) {
      final k = aiContentKey([
        vocabularyIdentityKey(e.record.targetText),
        vocabularyIdentityKey(e.record.nativeText),
      ]);
      pairCounts[k] = (pairCounts[k] ?? 0) + 1;
    }
    return {
      'targetLanguage': targetLanguage,
      'nativeLanguage': nativeLanguage,
      'groups': [
        for (final g in groups)
          if (!excludeSource || !source.contains(g.dimension.id)) g.toJson(),
      ],
      'entries': [
        for (final e in entries)
          e.toJson(
            examples:
                !compact ||
                pairCounts[aiContentKey([
                      vocabularyIdentityKey(e.record.targetText),
                      vocabularyIdentityKey(e.record.nativeText),
                    ])]! >
                    1,
            excludedGroups: excludeSource ? source : const {},
          ),
      ],
    };
  }

  String get contentKey => aiContentKey(toJson());
  AiSnapshot related(AiEntry anchor) {
    final target = vocabularyIdentityKey(anchor.record.targetText),
        native = vocabularyIdentityKey(anchor.record.nativeText);
    return AiSnapshot(
      collectionId: collectionId,
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
      groups: groups,
      entries: [
        anchor,
        ...entries.where(
          (e) =>
              e.record.id != anchor.record.id &&
              ((target.isNotEmpty &&
                      vocabularyIdentityKey(e.record.targetText) == target) ||
                  (native.isNotEmpty &&
                      vocabularyIdentityKey(e.record.nativeText) == native)),
        ),
      ],
    );
  }
}

final class AiRequest {
  AiRequest({
    required this.id,
    required this.action,
    required this.snapshot,
    this.goal = '',
    this.comprehensiveLevel = false,
    this.allowGroups = true,
    this.allowValues = true,
    Iterable<String> targets = const [],
    this.anchor,
  }) : targets = Set.unmodifiable(targets);
  final String id, goal;
  final AiAction action;
  final AiSnapshot snapshot;
  final bool comprehensiveLevel, allowGroups, allowValues;
  final Set<String> targets;
  final AiEntry? anchor;
  int get cardCeiling => comprehensiveLevel ? 1000 : 200;
  Map<String, Object?> toJson() => {
    'requestId': id,
    'action': action.name,
    'goal': goal,
    'allowNewGroups': allowGroups,
    'allowNewValues': allowValues,
    'context': snapshot.toJson(
      compact: action == AiAction.generate || action == AiAction.gaps,
      excludeSource: action == AiAction.hints,
    ),
    if (action == AiAction.hints) 'targets': targets.toList()..sort(),
  };
}

abstract interface class AiProvider {
  /// A result is read-only. Cancellation is implemented by the operation owner.
  Future<Map<String, Object?>> generate(AiRequest request);
  void close();
}

Map<String, Object?> aiObject(Object? v) {
  if (v is! Map<String, dynamic>) throw AiFailure.invalidResponse;
  return Map<String, Object?>.from(v);
}

List<Object?> aiList(Object? v) {
  if (v is! List) throw AiFailure.invalidResponse;
  return List<Object?>.from(v);
}

String aiText(Object? v, {bool empty = false, int max = 2000}) {
  if (v is! String || (!empty && v.trim().isEmpty) || v.runes.length > max) {
    throw AiFailure.invalidResponse;
  }
  if (!empty && !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(v)) {
    throw AiFailure.invalidResponse;
  }
  return v;
}

Map<String, Set<String>> aiAssignments(Object? value) {
  final groups = aiObject(value);
  return Map.unmodifiable({
    for (final g in groups.entries)
      g.key: Set<String>.unmodifiable(aiList(g.value).map((v) => aiText(v))),
  });
}

VocabularyContent aiContent(
  Map<String, Object?> value, {
  bool requireExample = false,
}) {
  final hint = value['hint'];
  if (hint != null) aiText(hint, max: VocabularyContent.maxHintLength);
  final examples = [
    for (final raw in aiList(value['examples']))
      ExamplePair(
        targetText: aiText(aiObject(raw)['target'], max: 1000),
        nativeText: aiText(aiObject(raw)['native'], max: 1000),
      ),
  ];
  if (requireExample && examples.isEmpty) throw AiFailure.invalidResponse;
  final content = VocabularyContent(
    examples: examples,
    hintText: hint as String?,
  ).normalized();
  if (content.examples.length != examples.length) {
    throw AiFailure.invalidResponse;
  }
  return content;
}

final class AiDefinition {
  const AiDefinition(
    this.id,
    this.name,
    this.reason, {
    this.groupId,
    this.mode,
  });
  final String id, name, reason;
  final String? groupId;
  final CategoryMode? mode;
}

final class AiCardProposal {
  const AiCardProposal(
    this.id,
    this.target,
    this.native,
    this.content,
    this.assignments,
    this.reason,
  );
  final String id, target, native, reason;
  final VocabularyContent content;
  final Map<String, Set<String>> assignments;
}

final class AiEditProposal {
  const AiEditProposal({
    required this.id,
    required this.entryId,
    required this.field,
    required this.value,
    required this.outcome,
    required this.reason,
    required this.rule,
  });
  final String id, entryId, field, reason, rule;
  final Object? value;
  final AiOutcome outcome;
  bool get applicable =>
      outcome == AiOutcome.change || outcome == AiOutcome.noHintNeeded;
}

final class AiPlan {
  AiPlan._(
    this.request,
    this.groups,
    this.values,
    this.cards,
    this.edits,
    this.limitations,
    this.processedIds,
    this.complete,
  );
  final AiRequest request;
  final List<AiDefinition> groups, values;
  final List<AiCardProposal> cards;
  final List<AiEditProposal> edits;
  final List<String> limitations, processedIds;
  final bool complete;
  factory AiPlan.parse(AiRequest request, Map<String, Object?> raw) {
    if (raw['requestId'] != request.id || raw['complete'] is! bool) {
      throw AiFailure.invalidResponse;
    }
    final ids = <String>{};
    String id(Object? v) {
      final s = aiText(v);
      if (!ids.add(s)) throw AiFailure.invalidResponse;
      return s;
    }

    final groups = [
      for (final r in aiList(raw['groups']))
        AiDefinition(
          id(aiObject(r)['id']),
          aiText(aiObject(r)['name']),
          aiText(aiObject(r)['reason']),
          mode: switch (aiObject(r)['mode']) {
            'single' => CategoryMode.single,
            'multiple' => CategoryMode.multiple,
            _ => throw AiFailure.invalidResponse,
          },
        ),
    ];
    final values = [
      for (final r in aiList(raw['values']))
        AiDefinition(
          id(aiObject(r)['id']),
          aiText(aiObject(r)['name']),
          aiText(aiObject(r)['reason']),
          groupId: aiText(aiObject(r)['groupId']),
        ),
    ];
    final cards = [
      for (final r in aiList(raw['cards']))
        AiCardProposal(
          id(aiObject(r)['id']),
          aiText(aiObject(r)['target']),
          aiText(aiObject(r)['native']),
          aiContent(aiObject(r), requireExample: true),
          aiAssignments(aiObject(r)['assignments']),
          aiText(aiObject(r)['reason']),
        ),
    ];
    final edits = [
      for (final r in aiList(raw['edits']))
        AiEditProposal(
          id: id(aiObject(r)['id']),
          entryId: aiText(aiObject(r)['entryId']),
          field: aiText(aiObject(r)['field']),
          value: _freeze(aiObject(r)['value']),
          outcome: AiOutcome.values.firstWhere(
            (v) => v.name == aiObject(r)['outcome'],
            orElse: () => throw AiFailure.invalidResponse,
          ),
          reason: aiText(aiObject(r)['reason']),
          rule: aiText(aiObject(r)['rule']),
        ),
    ];
    final processed = aiList(
      raw['processedIds'],
    ).map((v) => aiText(v)).toList();
    if (processed.toSet().length != processed.length ||
        !request.snapshot.entries
            .map((e) => e.record.id)
            .toSet()
            .containsAll(processed)) {
      throw AiFailure.invalidResponse;
    }
    if (cards.length > request.cardCeiling) throw AiFailure.limit;
    if ((!request.allowGroups && groups.isNotEmpty) ||
        (!request.allowValues && values.isNotEmpty)) {
      throw AiFailure.invalidResponse;
    }
    if (request.action == AiAction.hints) {
      if (groups.isNotEmpty ||
          values.isNotEmpty ||
          cards.isNotEmpty ||
          edits.length != request.targets.length ||
          edits.map((e) => e.entryId).toSet().length != edits.length ||
          !request.targets.containsAll(edits.map((e) => e.entryId)) ||
          edits.any(
            (e) =>
                e.field != 'hint' || e.outcome == AiOutcome.requiresNewMeaning,
          )) {
        throw AiFailure.invalidResponse;
      }
    }
    if (request.action == AiAction.review && cards.isNotEmpty) {
      throw AiFailure.invalidResponse;
    }
    for (final e in edits) {
      if (!request.snapshot.entries.any((v) => v.record.id == e.entryId)) {
        throw AiFailure.invalidResponse;
      }
      if (e.field == 'hint' && e.applicable) {
        if (e.outcome == AiOutcome.noHintNeeded) {
          if (e.value != null) throw AiFailure.invalidResponse;
        } else {
          aiText(e.value, max: 2000);
        }
      }
      if ((request.action == AiAction.generate ||
              request.action == AiAction.gaps) &&
          e.field != 'assignments') {
        throw AiFailure.invalidResponse;
      }
      if (!{
        'target',
        'native',
        'hint',
        'examples',
        'assignments',
      }.contains(e.field)) {
        throw AiFailure.invalidResponse;
      }
    }
    if (raw['complete'] == true &&
        (request.action == AiAction.review ||
            request.action == AiAction.hints) &&
        !processed.toSet().containsAll(
          request.action == AiAction.hints
              ? request.targets
              : request.snapshot.entries.map((e) => e.record.id),
        )) {
      throw AiFailure.invalidResponse;
    }
    return AiPlan._(
      request,
      List.unmodifiable(groups),
      List.unmodifiable(values),
      List.unmodifiable(cards),
      List.unmodifiable(edits),
      List.unmodifiable(aiList(raw['limitations']).map((v) => aiText(v))),
      List.unmodifiable(processed),
      raw['complete'] as bool,
    );
  }
}
