import 'sqlite_category_defaults.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../ai/ai_contract.dart';
import '../categories_repository.dart';
import '../vocabulary_content.dart';
import '../vocabulary_normalization.dart';
import '../vocabulary_repository.dart';
import 'piko_database.dart';
import 'sqlite_categories_repository.dart';
import 'sqlite_vocabulary_repository.dart';
import 'sqlite_vocabulary_content.dart';

/// Proposals never write. All selected mutations share one authoritative SQLite
/// transaction, including a new editor anchor and staged related Hint changes.
final class SqliteAiService implements AiContentService {
  SqliteAiService(this.database, {this.enabled = pikoAiEnabled});
  final PikoDatabase database;
  @override
  final bool enabled;
  final _consumed = <String>{};
  bool _applying = false;
  void requireEnabled() {
    if (!enabled) throw AiFailure.disabled;
  }

  @override
  Future<AiSnapshot> snapshot(String collectionId) =>
      database.transaction(() async {
        final c = await (database.select(
          database.collections,
        )..where((r) => r.id.equals(collectionId))).getSingleOrNull();
        if (c == null) throw AiFailure.stale;
        final cats = SqliteCategoriesRepository(database),
            vocab = SqliteVocabularyRepository(database);
        final examples = await SqliteVocabularyContent(
          database,
        ).forCollection(collectionId);
        final rows =
            await (database.select(database.vocabularyEntries)
                  ..where((r) => r.collectionId.equals(collectionId))
                  ..orderBy([(r) => OrderingTerm.asc(r.id)]))
                .get();
        final entries = <AiEntry>[];
        for (final r in rows) {
          entries.add(
            AiEntry(
              SqliteVocabularyContent(
                database,
              ).record(r, examples[r.id] ?? const []),
              await vocab.categorizedAssignments(r.id),
            ),
          );
        }
        final groups = <AiGroup>[];
        for (final d in await cats.dimensions(collectionId)) {
          groups.add(AiGroup(d, await cats.values(d.id)));
        }
        return AiSnapshot(
          collectionId: collectionId,
          targetLanguage: c.targetLanguageName ?? c.targetLanguage,
          nativeLanguage: c.nativeLanguageName ?? c.nativeLanguage,
          entries: entries,
          groups: groups,
        );
      });

  @override
  Future<AiRequest> request({
    required String collectionId,
    required AiAction action,
    String goal = '',
    bool comprehensiveLevel = false,
    bool allowGroups = true,
    bool allowValues = true,
    AiEntry? anchor,
    Set<String>? targets,
  }) async {
    requireEnabled();
    var current = await snapshot(collectionId);
    if (action == AiAction.hints) {
      if (anchor == null ||
          anchor.record.collectionId != collectionId ||
          anchor.record.targetText.trim().isEmpty ||
          anchor.record.nativeText.trim().isEmpty) {
        throw AiFailure.dependency;
      }
      current = current.related(anchor);
      if (current.entries.length < 2) throw AiFailure.dependency;
      final selected =
          targets ?? current.entries.map((e) => e.record.id).toSet();
      if (selected.isEmpty ||
          !current.entries
              .map((e) => e.record.id)
              .toSet()
              .containsAll(selected)) {
        throw AiFailure.dependency;
      }
      targets = selected;
    }
    if (action == AiAction.generate && goal.trim().isEmpty) {
      throw AiFailure.dependency;
    }
    return AiRequest(
      id: const Uuid().v4(),
      action: action,
      snapshot: current,
      goal: goal,
      comprehensiveLevel: comprehensiveLevel,
      allowGroups: allowGroups,
      allowValues: allowValues,
      anchor: anchor,
      targets: targets ?? const {},
    );
  }

  @override
  Future<bool> applicable(AiRequest request, {AiEntry? currentDraft}) async {
    final fresh = await snapshot(request.snapshot.collectionId);
    if (request.action != AiAction.hints) {
      return fresh.contentKey == request.snapshot.contentKey;
    }
    final anchor = request.anchor!;
    final saved = fresh.entries
        .where((e) => e.record.id == anchor.record.id)
        .firstOrNull;
    final now = saved ?? currentDraft;
    if (now == null) return false;
    return aiContentKey(fresh.related(now).toJson(excludeSource: true)) ==
        aiContentKey(request.snapshot.toJson(excludeSource: true));
  }

  /// Learning writes are intentionally outside the snapshot and never replaced.
  /// [newAnchor] is provided only by successful new-entry confirmation, never by
  /// merely accepting a Hint proposal in its review area.
  @override
  Future<AiAdoption> apply(
    AiPlan plan,
    Set<String> selected, {
    bool allowPartial = false,
    AiEntry? newAnchor,
    bool makeHintVisibilityDefault = false,
    void Function()? beforeCommit,
  }) async {
    requireEnabled();
    if (_applying || _consumed.contains(plan.request.id)) {
      throw AiFailure.consumed;
    }
    if (!plan.complete && !allowPartial) throw AiFailure.dependency;
    final candidates = {
      ...plan.groups.map((e) => e.id),
      ...plan.values.map((e) => e.id),
      ...plan.cards.map((e) => e.id),
      ...plan.edits.where((e) => e.applicable).map((e) => e.id),
    };
    if (!candidates.containsAll(selected)) throw AiFailure.dependency;
    _applying = true;
    try {
      final created = await database.transaction(() async {
        if (!await applicable(plan.request, currentDraft: newAnchor)) {
          throw AiFailure.stale;
        }
        final fresh = await snapshot(plan.request.snapshot.collectionId);
        final old = {for (final e in fresh.entries) e.record.id: e};
        if (newAnchor != null) {
          if (plan.request.action != AiAction.hints ||
              old.containsKey(newAnchor.record.id) ||
              newAnchor.record.id != plan.request.anchor?.record.id ||
              aiContentKey(newAnchor.toJson()) !=
                  aiContentKey(plan.request.anchor!.toJson())) {
            throw AiFailure.stale;
          }
          old[newAnchor.record.id] = newAnchor;
        } else if (plan.request.action == AiAction.hints &&
            !old.containsKey(plan.request.anchor!.record.id)) {
          throw AiFailure.dependency;
        }
        final cats = SqliteCategoriesRepository(database),
            vocab = SqliteVocabularyRepository(database);
        final groupIds = {
          for (final g in fresh.groups) g.dimension.id: g.dimension.id,
        };
        final valueIds = {
          for (final g in fresh.groups)
            for (final v in g.values) v.id: v.id,
        };
        for (final g in plan.groups.where((g) => selected.contains(g.id))) {
          if (!plan.request.allowGroups ||
              groupIds.containsKey(g.id) ||
              valueIds.containsKey(g.id)) {
            throw AiFailure.dependency;
          }
          groupIds[g.id] = (await cats.createDimension(
            collectionId: fresh.collectionId,
            name: g.name,
            mode: g.mode!,
          )).id;
        }
        for (final v in plan.values.where((v) => selected.contains(v.id))) {
          if (!plan.request.allowValues ||
              valueIds.containsKey(v.id) ||
              !groupIds.containsKey(v.groupId)) {
            throw AiFailure.dependency;
          }
          valueIds[v.id] = (await cats.createValue(
            dimensionId: groupIds[v.groupId]!,
            name: v.name,
          )).id;
        }
        Future<Map<String, Set<String>>> resolve(
          Map<String, Set<String>> raw,
        ) async {
          final result = <String, Set<String>>{};
          for (final g in raw.entries) {
            final gid = groupIds[g.key];
            if (gid == null) throw AiFailure.dependency;
            final values = <String>{};
            for (final v in g.value) {
              final id = valueIds[v];
              if (id == null) throw AiFailure.dependency;
              values.add(id);
            }
            result[gid] = values;
          }
          await cats.validateAssignments(
            collectionId: fresh.collectionId,
            assignments: result,
          );
          return result;
        }

        final changed = <String, AiEntry>{};
        final fields = <String>{};
        final sourceIds = {
          for (final g in await cats.dimensions(fresh.collectionId))
            if (g.acquisitionSource || aiSourceName(g.name)) g.id,
        };
        for (final edit in plan.edits.where((e) => selected.contains(e.id))) {
          if (!edit.applicable ||
              !fields.add('${edit.entryId}:${edit.field}')) {
            throw AiFailure.dependency;
          }
          final entry = changed[edit.entryId] ?? old[edit.entryId];
          if (entry == null) throw AiFailure.stale;
          var target = entry.record.targetText,
              native = entry.record.nativeText,
              content = entry.record.content;
          var assignments = {
            for (final g in entry.assignments.entries)
              g.key: Set<String>.of(g.value),
          };
          switch (edit.field) {
            case 'target':
              target = aiText(edit.value);
              break;
            case 'native':
              native = aiText(edit.value);
              break;
            case 'hint':
              content = VocabularyContent(
                examples: content.examples,
                hintText: edit.value as String?,
                hintVisibility: content.hintVisibility,
              ).normalized();
              break;
            case 'examples':
              content = aiContent({
                'hint': content.hintText,
                'examples': edit.value,
              }, requireExample: true);
              content = VocabularyContent(
                examples: content.examples,
                hintText: content.hintText,
                hintVisibility: entry.record.content.hintVisibility,
              );
              break;
            case 'assignments':
              final proposed = await resolve(aiAssignments(edit.value));
              if (plan.request.action == AiAction.review) {
                for (final sid in sourceIds) {
                  if (aiContentKey((proposed[sid] ?? {}).toList()..sort()) !=
                      aiContentKey(
                        (entry.assignments[sid] ?? {}).toList()..sort(),
                      )) {
                    throw AiFailure.dependency;
                  }
                }
                assignments = proposed;
              } else {
                for (final g in proposed.entries) {
                  if (sourceIds.contains(g.key)) {
                    if (!entry.assignments[g.key].orEmpty.containsAll(
                      g.value,
                    )) {
                      throw AiFailure.dependency;
                    }
                    continue;
                  }
                  final dimension = await cats.dimensionById(g.key);
                  if (dimension == null) throw AiFailure.dependency;
                  final current = assignments[g.key] ?? <String>{};
                  if (dimension.mode == CategoryMode.single &&
                      current.isNotEmpty &&
                      !current.containsAll(g.value)) {
                    throw AiFailure.dependency;
                  }
                  assignments[g.key] = {...current, ...g.value};
                }
              }
              break;
            default:
              throw AiFailure.invalidResponse;
          }
          if (plan.request.action == AiAction.hints && edit.field != 'hint') {
            throw AiFailure.dependency;
          }
          if ((plan.request.action == AiAction.generate ||
                  plan.request.action == AiAction.gaps) &&
              edit.field != 'assignments') {
            throw AiFailure.dependency;
          }
          changed[edit.entryId] = AiEntry(
            VocabularyRecord(
              id: entry.record.id,
              collectionId: fresh.collectionId,
              targetText: target,
              nativeText: native,
              content: content,
              active: entry.record.active,
              addedAt: entry.record.addedAt,
            ),
            assignments,
          );
        }
        if (newAnchor != null) {
          changed.putIfAbsent(newAnchor.record.id, () => newAnchor);
        }
        final newCards = <AiEntry>[];
        final groupsNow = await cats.dimensions(fresh.collectionId);
        for (final card in plan.cards.where((c) => selected.contains(c.id))) {
          final assignments = await resolve(card.assignments);
          // Acquisition is supplied by the app, never inferred by the model.
          for (final g in groupsNow.where(
            (g) => g.acquisitionSource || aiSourceName(g.name),
          )) {
            final matches = (await cats.values(g.id))
                .where(
                  (v) => {
                    'ai-generated',
                    'ai-generiert',
                  }.contains(vocabularyIdentityKey(v.name)),
                )
                .toList();
            if (matches.length == 1) {
              assignments[g.id] = {matches.single.id};
            } else {
              assignments.remove(g.id);
            }
          }
          newCards.add(
            AiEntry(
              VocabularyRecord(
                id: const Uuid().v4(),
                collectionId: fresh.collectionId,
                targetText: card.target,
                nativeText: card.native,
                content: card.content,
              ),
              assignments,
            ),
          );
        }
        final keys = <String>{};
        for (final entry in [
          ...old.values.map((e) => changed[e.record.id] ?? e),
          ...newCards,
        ]) {
          if (!keys.add(
            aiContentKey([
              vocabularyIdentityKey(entry.record.targetText),
              vocabularyIdentityKey(entry.record.nativeText),
              vocabularyIdentityKey(entry.record.content.hintText),
            ]),
          )) {
            throw AiFailure.collision;
          }
        }
        // Unique tuples are checked for the whole final collection first. Vacate
        // changed comparison keys to permit valid swaps without transient clashes.
        for (final id in changed.keys.where(
          (id) => id != newAnchor?.record.id,
        )) {
          String temporary;
          do {
            temporary = 'piko-ai-${const Uuid().v4()}';
          } while (await (database.select(database.vocabularyEntries)..where(
                    (r) =>
                        r.collectionId.equals(fresh.collectionId) &
                        r.targetKey.equals(temporary),
                  ))
                  .getSingleOrNull() !=
              null);
          await (database.update(database.vocabularyEntries)
                ..where((r) => r.id.equals(id)))
              .write(VocabularyEntriesCompanion(targetKey: Value(temporary)));
        }
        VocabularyRecord? savedAnchor;
        final relatedUpdates = <String, VocabularyRecord>{};
        for (final entry in changed.values) {
          final r = entry.record;
          if (r.id == newAnchor?.record.id) {
            savedAnchor = await vocab.createWithContent(
              collectionId: fresh.collectionId,
              targetText: r.targetText,
              nativeText: r.nativeText,
              assignments: await SqliteCategoryDefaults(
                database,
              ).manualAssignments(fresh.collectionId, entry.assignments),
              content: r.content,
              active: r.active,
              makeHintVisibilityDefault: makeHintVisibilityDefault,
            );
          } else {
            relatedUpdates[r.id] = await vocab.updateWithContent(
              id: r.id,
              targetText: r.targetText,
              nativeText: r.nativeText,
              assignments: entry.assignments,
              content: r.content,
            );
          }
        }
        for (final entry in newCards) {
          final r = entry.record;
          await vocab.createWithContent(
            collectionId: fresh.collectionId,
            targetText: r.targetText,
            nativeText: r.nativeText,
            assignments: entry.assignments,
            content: r.content,
          );
        }
        beforeCommit?.call();
        if (savedAnchor == null) {
          return AiAdoption(updatedEntries: relatedUpdates);
        }
        final committed = await vocab.categorizedAssignments(savedAnchor.id);
        final carryGroups = await cats.dimensions(fresh.collectionId);
        return AiAdoption(
          updatedEntries: relatedUpdates,
          confirmation: EntryConfirmation(
            savedAnchor,
            {
              for (final g in carryGroups)
                if (g.carryOver && committed.containsKey(g.id))
                  g.id: committed[g.id]!,
            },
            assignments: committed,
            relatedEntries: relatedUpdates,
          ),
        );
      });
      _consumed.add(plan.request.id);
      return created;
    } finally {
      _applying = false;
    }
  }
}

extension on Set<String>? {
  Set<String> get orEmpty => this ?? const {};
}
