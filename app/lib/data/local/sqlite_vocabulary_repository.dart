import '../ai/ai_contract.dart';
import 'sqlite_category_defaults.dart';
import 'sqlite_vocabulary_content.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import '../vocabulary_repository.dart';
import '../vocabulary_content.dart';
import '../vocabulary_normalization.dart';
import 'piko_database.dart';
import 'sqlite_categories_repository.dart';
import 'sqlite_settings_repository.dart';

final class _OpeningSnapshot implements CategorizedVocabularyOpeningSnapshot {
  const _OpeningSnapshot(this.entry, this.issuer, this.assignments);
  @override
  final VocabularyRecord entry;
  final Object issuer;
  @override
  final Map<String, Set<String>> assignments;
}

final class SqliteVocabularyRepository
    implements
        VocabularyContentRepository,
        AiSupportedVocabularyRepository,
        EntryConfirmationRepository,
        QuestionExamplesRepository,
        CollectionHintPreferences {
  SqliteVocabularyRepository(this.database, {this.ai});
  @override
  final AiSupport? ai;
  final PikoDatabase database;
  final _issuer = Object();
  @override
  Future<bool> readQuestionExamples() async =>
      await SqliteSettingsRepository(database).read('questionExamples') !=
      'false';

  @override
  Future<HintVisibility> readHintVisibilityDefault({
    required String collectionId,
  }) async {
    final row = await _collection(collectionId);
    return row.automaticHintDefault
        ? HintVisibility.always
        : HintVisibility.hidden;
  }

  Future<Collection> _collection(String id) async {
    final row = await (database.select(
      database.collections,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) throw VocabularyValidation.collectionNotFound;
    return row;
  }

  @override
  Future<bool> hintDefaultOfferHandled(String collectionId) async =>
      (await _collection(collectionId)).hintDefaultOfferHandled;

  @override
  Future<void> setCollectionHintDefault(
    String collectionId,
    bool automatic,
  ) async {
    final count =
        await (database.update(
          database.collections,
        )..where((c) => c.id.equals(collectionId))).write(
          CollectionsCompanion(automaticHintDefault: Value(automatic)),
        );
    if (count != 1) throw VocabularyValidation.collectionNotFound;
  }

  @override
  Future<void> completeHintDefaultOffer(
    String collectionId, {
    required bool accept,
  }) => database.transaction(() async {
    final row = await _collection(collectionId);
    if (row.hintDefaultOfferHandled) return;
    await (database.update(
      database.collections,
    )..where((c) => c.id.equals(collectionId))).write(
      CollectionsCompanion(
        hintDefaultOfferHandled: const Value(true),
        automaticHintDefault: accept ? const Value(true) : const Value.absent(),
      ),
    );
  });

  Future<void> _writeContent(
    String id,
    VocabularyContent content,
    bool makeDefault,
    bool? active,
  ) async {
    final count =
        await (database.update(
          database.vocabularyEntries,
        )..where((row) => row.id.equals(id))).write(
          VocabularyEntriesCompanion(
            active: active == null ? const Value.absent() : Value(active),
            hintText: Value(content.hintText),
            hintKey: Value(vocabularyIdentityKey(content.hintText)),
            hintVisibility: Value(content.hintVisibility.name),
          ),
        );
    if (count != 1) throw VocabularyValidation.entryNotFound;
    await SqliteVocabularyContent(database).replace(id, content);
    if (makeDefault) {
      final entry = await (database.select(
        database.vocabularyEntries,
      )..where((e) => e.id.equals(id))).getSingle();
      await setCollectionHintDefault(
        entry.collectionId,
        content.hintVisibility == HintVisibility.always,
      );
    }
  }

  @override
  Future<VocabularyRecord> createWithContent({
    required String collectionId,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
    required VocabularyContent content,
    bool makeHintVisibilityDefault = false,
    bool active = true,
  }) {
    final normalized = content.normalized();
    final requested = {
      for (final group in assignments.entries)
        group.key: Set<String>.of(group.value),
    };
    return _write(() async {
      final categories = SqliteCategoriesRepository(database);
      await categories.validateAssignments(
        collectionId: collectionId,
        assignments: requested,
      );
      final saved = await _create(
        collectionId: collectionId,
        targetText: targetText,
        nativeText: nativeText,
        content: normalized,
      );
      await categories.replaceAssignments(
        entryId: saved.id,
        assignments: requested,
      );
      await _writeContent(
        saved.id,
        normalized,
        makeHintVisibilityDefault,
        active,
      );
      return VocabularyRecord(
        id: saved.id,
        collectionId: saved.collectionId,
        targetText: saved.targetText,
        nativeText: saved.nativeText,
        content: normalized,
        addedAt: saved.addedAt,
        active: active,
      );
    });
  }

  @override
  Future<EntryConfirmation> confirmNewEntry({
    required String collectionId,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
    required VocabularyContent content,
    bool makeHintVisibilityDefault = false,
    bool active = true,
  }) {
    final requested = {
      for (final group in assignments.entries)
        group.key: Set<String>.of(group.value),
    };
    return _write(() async {
      final saved = await createWithContent(
        collectionId: collectionId,
        targetText: targetText,
        nativeText: nativeText,
        assignments: await SqliteCategoryDefaults(
          database,
        ).manualAssignments(collectionId, requested),
        content: content,
        makeHintVisibilityDefault: makeHintVisibilityDefault,
        active: active,
      );
      // Read the committed assignments and current preferences inside the same
      // transaction. A failed read cannot leave an entry saved but unadvanced.
      final committed = await categorizedAssignments(saved.id);
      final groups = await SqliteCategoriesRepository(
        database,
      ).dimensions(collectionId);
      return EntryConfirmation(saved, {
        for (final group in groups)
          if (group.carryOver && committed.containsKey(group.id))
            group.id: committed[group.id]!,
      }, assignments: committed);
    });
  }

  @override
  Future<VocabularyRecord> updateWithContent({
    required String id,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
    required VocabularyContent content,
    bool makeHintVisibilityDefault = false,
    bool? active,
  }) {
    final normalized = content.normalized();
    final requested = {
      for (final group in assignments.entries)
        group.key: Set<String>.of(group.value),
    };
    return _write(() async {
      final saved = await _update(
        id: id,
        targetText: targetText,
        nativeText: nativeText,
        content: normalized,
      );
      await SqliteCategoriesRepository(
        database,
      ).replaceAssignments(entryId: id, assignments: requested);
      await _writeContent(id, normalized, makeHintVisibilityDefault, active);
      return VocabularyRecord(
        id: saved.id,
        collectionId: saved.collectionId,
        targetText: saved.targetText,
        nativeText: saved.nativeText,
        content: normalized,
        addedAt: saved.addedAt,
        active: active ?? saved.active,
      );
    });
  }

  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) => database.transaction(() async {
    final row =
        await (database.select(database.vocabularyEntries)..where(
              (row) =>
                  row.id.equals(entryId) &
                  row.collectionId.equals(collectionId),
            ))
            .getSingleOrNull();
    if (row == null) throw VocabularyValidation.entryNotFound;
    return _OpeningSnapshot(
      await _record(row),
      _issuer,
      await categorizedAssignments(entryId),
    );
  });

  @override
  Future<Map<String, Set<String>>> categorizedAssignments(
    String entryId,
  ) async => Map.unmodifiable({
    for (final group in await SqliteCategoriesRepository(
      database,
    ).assignments(entryId))
      group.dimensionId: Set<String>.unmodifiable(group.valueIds),
  });

  @override
  Future<VocabularyRecord> createCategorized({
    required String collectionId,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  }) {
    final requested = {
      for (final group in assignments.entries)
        group.key: Set<String>.of(group.value),
    };
    return _write(() async {
      final categories = SqliteCategoriesRepository(database);
      await categories.validateAssignments(
        collectionId: collectionId,
        assignments: requested,
      );
      final saved = await create(
        collectionId: collectionId,
        targetText: targetText,
        nativeText: nativeText,
      );
      await categories.replaceAssignments(
        entryId: saved.id,
        assignments: requested,
      );
      return saved;
    });
  }

  @override
  Future<VocabularyRecord> updateCategorized({
    required String id,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  }) {
    final requested = {
      for (final group in assignments.entries)
        group.key: Set<String>.of(group.value),
    };
    return _write(() async {
      final saved = await update(
        id: id,
        targetText: targetText,
        nativeText: nativeText,
      );
      await SqliteCategoriesRepository(
        database,
      ).replaceAssignments(entryId: id, assignments: requested);
      return saved;
    });
  }

  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) {
    if (snapshot is! _OpeningSnapshot || !identical(snapshot.issuer, _issuer)) {
      throw StateError('Opening snapshot belongs to a different repository.');
    }
    final original = snapshot.entry;
    return _write(() async {
      final row =
          await (database.select(database.vocabularyEntries)..where(
                (row) =>
                    row.id.equals(original.id) &
                    row.collectionId.equals(original.collectionId),
              ))
              .getSingleOrNull();
      if (row == null) throw VocabularyValidation.entryNotFound;
      final owner =
          await (database.select(database.collections)
                ..where((row) => row.id.equals(original.collectionId)))
              .getSingleOrNull();
      if (owner == null) throw VocabularyValidation.collectionNotFound;
      final count =
          await (database.update(database.vocabularyEntries)..where(
                (row) =>
                    row.id.equals(original.id) &
                    row.collectionId.equals(original.collectionId),
              ))
              .write(
                VocabularyEntriesCompanion(
                  targetText: Value(original.targetText),
                  nativeText: Value(original.nativeText),
                  targetKey: Value(vocabularyIdentityKey(original.targetText)),
                  nativeKey: Value(vocabularyIdentityKey(original.nativeText)),
                  active: Value(original.active),
                  hintText: Value(original.content.hintText),
                  hintKey: Value(
                    vocabularyIdentityKey(original.content.hintText),
                  ),
                  hintVisibility: Value(original.content.hintVisibility.name),
                ),
              );
      if (count != 1) throw VocabularyValidation.entryNotFound;
      await SqliteVocabularyContent(
        database,
      ).replace(original.id, original.content);
      // Explicit deletion of definitions remains effective: Discard restores
      // surviving assignments, never recreates a deleted category or value.
      final categories = SqliteCategoriesRepository(database);
      final assignments = <String, Set<String>>{};
      for (final group in snapshot.assignments.entries) {
        final dimension = await categories.dimensionById(group.key);
        if (dimension == null ||
            dimension.collectionId != original.collectionId) {
          continue;
        }
        final surviving = <String>{};
        for (final id in group.value) {
          final value = await categories.valueById(id);
          if (value?.dimensionId == group.key) surviving.add(id);
        }
        if (surviving.isNotEmpty) assignments[group.key] = surviving;
      }
      await categories.replaceAssignments(
        entryId: original.id,
        assignments: assignments,
      );
      return original;
    });
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    try {
      return await database.transaction(action);
    } on SqliteException catch (error) {
      // Other tables also have unique keys; only translate this exact constraint.
      if (error.extendedResultCode == 2067 &&
          error.message.contains(
            'vocabulary_entries.collection_id, vocabulary_entries.target_key, vocabulary_entries.native_key',
          )) {
        throw VocabularyValidation.duplicatePair;
      }
      rethrow;
    }
  }

  (String, String) _texts(String targetText, String nativeText) {
    final target = normalizeVocabularyText(targetText);
    final native = normalizeVocabularyText(nativeText);
    if (vocabularyIdentityKey(target).isEmpty) {
      throw VocabularyValidation.requiredTarget;
    }
    if (vocabularyIdentityKey(native).isEmpty) {
      throw VocabularyValidation.requiredNative;
    }
    return (target, native);
  }

  Future<VocabularyRecord> _record(VocabularyEntry row) async =>
      VocabularyRecord(
        id: row.id,
        active: row.active,
        collectionId: row.collectionId,
        targetText: row.targetText,
        nativeText: row.nativeText,
        addedAt: row.addedAt == null
            ? null
            : DateTime.parse(row.addedAt!).toUtc(),
        content: await SqliteVocabularyContent(database).read(row),
      );

  @override
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId) =>
      (database.select(database.vocabularyEntries)
            ..where((r) => r.collectionId.equals(collectionId))
            ..orderBy([
              (_) => OrderingTerm(
                expression: const CustomExpression<int>('rowid'),
              ),
            ]))
          .watch()
          .asyncMap(
            (_) => database.transaction(() async {
              final rows =
                  await (database.select(database.vocabularyEntries)
                        ..where((r) => r.collectionId.equals(collectionId))
                        ..orderBy([
                          (_) => OrderingTerm(
                            expression: const CustomExpression<int>('rowid'),
                          ),
                        ]))
                      .get();
              final store = SqliteVocabularyContent(database),
                  examples = await SqliteVocabularyContent(
                    database,
                  ).forCollection(collectionId);
              return rows
                  .map((row) => store.record(row, examples[row.id] ?? const []))
                  .toList(growable: false);
            }),
          );

  @override
  Stream<VocabularyRecord?> watchById(String id) =>
      (database.select(
        database.vocabularyEntries,
      )..where((r) => r.id.equals(id))).watchSingleOrNull().asyncMap(
        (_) => database.transaction(() async {
          final row = await (database.select(
            database.vocabularyEntries,
          )..where((r) => r.id.equals(id))).getSingleOrNull();
          return row == null ? null : await _record(row);
        }),
      );

  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) => _create(
    collectionId: collectionId,
    targetText: targetText,
    nativeText: nativeText,
  );

  Future<VocabularyRecord> _create({
    required String collectionId,
    required String targetText,
    required String nativeText,
    VocabularyContent? content,
  }) async {
    final (target, native) = _texts(targetText, nativeText);
    return _write(() async {
      final collection = await (database.select(
        database.collections,
      )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
      if (collection == null) throw VocabularyValidation.collectionNotFound;
      final id = const Uuid().v4();
      final rowId = await database.allocateVocabularyRowId();
      final visibility =
          content?.hintVisibility ??
          await readHintVisibilityDefault(collectionId: collectionId);
      final addedAt = database.clock.now().toUtc();
      await database.customInsert(
        'INSERT INTO vocabulary_entries (rowid, id, collection_id, target_text, native_text, target_key, native_key, hint_key, hint_text, hint_visibility, added_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(rowId),
          Variable(id),
          Variable(collectionId),
          Variable(target),
          Variable(native),
          Variable(vocabularyIdentityKey(target)),
          Variable(vocabularyIdentityKey(native)),
          Variable(vocabularyIdentityKey(content?.hintText)),
          Variable<String>(content?.hintText),
          Variable(visibility.name),
          Variable(addedAt.toIso8601String()),
        ],
        updates: {database.vocabularyEntries},
      );
      await database.createLearningItems(id);
      return VocabularyRecord(
        id: id,
        collectionId: collectionId,
        targetText: target,
        nativeText: native,
        content: VocabularyContent(hintVisibility: visibility),
        addedAt: addedAt,
      );
    });
  }

  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) => _update(id: id, targetText: targetText, nativeText: nativeText);

  Future<VocabularyRecord> _update({
    required String id,
    required String targetText,
    required String nativeText,
    VocabularyContent? content,
  }) async {
    final (target, native) = _texts(targetText, nativeText);
    return _write(() async {
      final existing = await (database.select(
        database.vocabularyEntries,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (existing == null) throw VocabularyValidation.entryNotFound;
      await (database.update(
        database.vocabularyEntries,
      )..where((row) => row.id.equals(id))).write(
        VocabularyEntriesCompanion(
          targetText: Value(target),
          nativeText: Value(native),
          targetKey: Value(vocabularyIdentityKey(target)),
          nativeKey: Value(vocabularyIdentityKey(native)),
          hintKey: Value(
            vocabularyIdentityKey(
              content == null ? existing.hintText : content.hintText,
            ),
          ),
          hintText: content == null
              ? const Value.absent()
              : Value(content.hintText),
        ),
      );
      return VocabularyRecord(
        id: existing.id,
        active: existing.active,
        collectionId: existing.collectionId,
        targetText: target,
        nativeText: native,
        content: (await _record(existing)).content,
        addedAt: existing.addedAt == null
            ? null
            : DateTime.parse(existing.addedAt!).toUtc(),
      );
    });
  }
}
