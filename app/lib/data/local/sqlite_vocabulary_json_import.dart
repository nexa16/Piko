part of 'sqlite_vocabulary_json_service.dart';

final class _ImportRequest {
  _ImportRequest(
    this.collectionId,
    this.groups,
    this.source,
    this.entries,
    this.ids,
    this.issues, [
    this.schemaVersion = 1,
  ]);
  final String collectionId;
  final Set<VocabularyJsonGroup> groups;
  final Map<String, dynamic>? source;
  final List<dynamic> entries;
  final List<String> ids;
  final List<VocabularyJsonIssue> issues;
  final int schemaVersion;
}

final class _EntryChange {
  _EntryChange({
    required this.id,
    required this.target,
    required this.native,
    required this.isNew,
    required this.assignments,
    required this.changed,
    required this.content,
    required this.active,
  });
  final String id, target, native;
  final bool isNew, changed, active;
  final VocabularyContent content;

  /// Null leaves existing assignments untouched; empty explicitly clears them.
  final Map<String, Set<String>>? assignments;
}

final class _ImportPlan {
  _ImportPlan({
    required this.request,
    required this.issues,
    required this.notices,
    required this.entries,
    required this.dimensions,
    required this.values,
    required this.fingerprint,
  });
  final _ImportRequest request;
  final List<VocabularyJsonIssue> issues;
  final Set<VocabularyJsonNotice> notices;
  final List<_EntryChange> entries;
  final List<CategoryDimensionRecord> dimensions;
  final List<CategoryValueRecord> values;
  final String fingerprint;
  int get newCount => entries.where((entry) => entry.isNew).length;
  int get updatedCount =>
      entries.where((entry) => !entry.isNew && entry.changed).length;
  int get unchangedCount =>
      entries.where((entry) => !entry.isNew && !entry.changed).length;
}

final class _SqliteImportPreview implements VocabularyJsonPreview {
  _SqliteImportPreview(this.issuer, this.plan)
    : issues = List.unmodifiable(plan.issues),
      notices = Set.unmodifiable(plan.notices);
  final Object issuer;
  final _ImportPlan plan;
  bool consumed = false, pending = false;
  @override
  String get collectionId => plan.request.collectionId;
  @override
  Set<VocabularyJsonGroup> get groups => plan.request.groups;
  @override
  final List<VocabularyJsonIssue> issues;
  @override
  final Set<VocabularyJsonNotice> notices;
  @override
  int get newCount => plan.newCount;
  @override
  int get updatedCount => plan.updatedCount;
  @override
  int get unchangedCount => plan.unchangedCount;
  @override
  int get errorCount => issues.length;
  @override
  bool get canApply => issues.isEmpty;
}

extension _VocabularyJsonImport on SqliteVocabularyJsonService {
  String? _uuid(Object? value) =>
      value is String &&
          RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(value)
      ? value.toLowerCase()
      : null;

  _ImportRequest _request(
    String collectionId,
    String json,
    Set<VocabularyJsonGroup> groups,
  ) {
    final issues = <VocabularyJsonIssue>[];
    void issue(VocabularyJsonIssueCode code, String path, [int? row]) =>
        issues.add(VocabularyJsonIssue(code: code, path: path, row: row));
    final selected = Set<VocabularyJsonGroup>.unmodifiable(groups);
    if (selected.isEmpty) {
      issue(VocabularyJsonIssueCode.groupsRequired, 'groups');
    }
    _ImportRequest invalid() =>
        _ImportRequest(collectionId, selected, null, [], [], issues);
    // Count encoded bytes before parsing, including multibyte text from paste.
    if (utf8.encode(json).length > VocabularyJsonFormat.maxImportBytes) {
      issue(VocabularyJsonIssueCode.tooLarge, r'$');
      return invalid();
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      issue(VocabularyJsonIssueCode.invalidJson, r'$');
      return invalid();
    }
    if (decoded is! Map<String, dynamic>) {
      issue(VocabularyJsonIssueCode.invalidEnvelope, r'$');
      return invalid();
    }
    if (decoded['format'] != VocabularyJsonFormat.format) {
      issue(VocabularyJsonIssueCode.unsupportedFormat, 'format');
    }
    if (decoded['schemaVersion'] is! int ||
        decoded['schemaVersion'] != VocabularyJsonFormat.schemaVersion) {
      issue(VocabularyJsonIssueCode.unsupportedVersion, 'schemaVersion');
    }
    final collections = decoded['collections'];
    if (collections is! List || collections.length != 1) {
      issue(VocabularyJsonIssueCode.exactlyOneCollection, 'collections');
      return invalid();
    }
    final source = collections.single;
    if (source is! Map<String, dynamic>) {
      issue(VocabularyJsonIssueCode.invalidEnvelope, 'collections[0]');
      return invalid();
    }
    if (source.containsKey('id') && _uuid(source['id']) == null) {
      issue(VocabularyJsonIssueCode.invalidId, 'collections[0].id');
    }
    final entries = source['entries'];
    if (entries is! List) {
      issue(VocabularyJsonIssueCode.invalidField, 'collections[0].entries');
      return invalid();
    }
    final ids = <String>[];
    final seen = <String>{};
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry is! Map<String, dynamic>) {
        issue(
          VocabularyJsonIssueCode.invalidField,
          'collections[0].entries[$index]',
          index + 1,
        );
        ids.add(const Uuid().v4());
        continue;
      }
      final id = entry.containsKey('id')
          ? _uuid(entry['id'])
          : const Uuid().v4();
      if (id == null) {
        issue(
          VocabularyJsonIssueCode.invalidId,
          'collections[0].entries[$index].id',
          index + 1,
        );
      }
      final identity = id ?? const Uuid().v4();
      if (!seen.add(identity)) {
        issue(
          VocabularyJsonIssueCode.duplicateId,
          'collections[0].entries[$index].id',
          index + 1,
        );
      }
      ids.add(identity);
    }
    return _ImportRequest(
      collectionId,
      selected,
      source,
      entries,
      ids,
      issues,
      decoded['schemaVersion'] is int ? decoded['schemaVersion'] as int : 0,
    );
  }

  Future<VocabularyJsonPreview> _analyzeImport({
    required String collectionId,
    required String json,
    required Set<VocabularyJsonGroup> groups,
  }) async {
    final request = _request(collectionId, json, groups);
    final plan = await database.transaction(() => _planImport(request));
    return _SqliteImportPreview(_importIssuer, plan);
  }

  /// Current destination data, including learning, is a confirmation precondition.
  /// Settings/allocators and unrelated Collections do not invalidate a preview.
  Future<String> _importFingerprint(String collectionId) async {
    final result = <String, Object?>{};
    for (final (name, sql) in [
      (
        'collections',
        'SELECT id,name,target_language,native_language FROM collections WHERE id = ?',
      ),
      (
        'vocabulary_entries',
        'SELECT rowid AS original_rowid,* FROM vocabulary_entries WHERE collection_id = ? ORDER BY rowid',
      ),
      (
        'category_dimensions',
        'SELECT * FROM category_dimensions WHERE collection_id = ? ORDER BY position,id',
      ),
      (
        'category_values',
        'SELECT v.* FROM category_values v JOIN category_dimensions d ON d.id=v.dimension_id WHERE d.collection_id = ? ORDER BY d.position,d.id,v.position,v.id',
      ),
      (
        'assignments',
        'SELECT * FROM vocabulary_category_assignments WHERE collection_id = ? ORDER BY entry_id,dimension_id,value_id',
      ),
      (
        'learning_items',
        'SELECT l.* FROM learning_items l JOIN vocabulary_entries v ON v.id=l.entry_id WHERE v.collection_id = ? ORDER BY l.id',
      ),
      (
        'reviews',
        'SELECT r.* FROM regular_reviews r JOIN learning_items l ON l.id=r.item_id JOIN vocabulary_entries v ON v.id=l.entry_id WHERE v.collection_id = ? ORDER BY r.rowid',
      ),
      (
        'retries',
        'SELECT r.* FROM retry_obligations r JOIN learning_items l ON l.id=r.item_id JOIN vocabulary_entries v ON v.id=l.entry_id WHERE v.collection_id = ? ORDER BY r.id',
      ),
      (
        'scopes',
        'SELECT * FROM scope_answer_ordinals WHERE collection_id = ? ORDER BY direction',
      ),
    ]) {
      result[name] =
          (await database
                  .customSelect(sql, variables: [Variable(collectionId)])
                  .get())
              .map((row) => row.data)
              .toList();
    }
    return jsonEncode(result);
  }

  Future<_ImportPlan> _planImport(_ImportRequest request) async {
    final issues = List<VocabularyJsonIssue>.of(request.issues);
    final notices = <VocabularyJsonNotice>{};
    final changes = <_EntryChange>[];
    final newDimensions = <CategoryDimensionRecord>[];
    final newValues = <CategoryValueRecord>[];
    void issue(VocabularyJsonIssueCode code, String path, [int? row]) =>
        issues.add(VocabularyJsonIssue(code: code, path: path, row: row));
    var fingerprint = '';
    _ImportPlan result() => _ImportPlan(
      request: request,
      issues: issues,
      notices: notices,
      entries: changes,
      dimensions: newDimensions,
      values: newValues,
      fingerprint: fingerprint,
    );
    final source = request.source;
    if (source == null) return result();
    final owner = await (database.select(
      database.collections,
    )..where((row) => row.id.equals(request.collectionId))).getSingleOrNull();
    if (owner == null) {
      issue(VocabularyJsonIssueCode.collectionNotFound, 'destination');
      return result();
    }
    fingerprint = jsonEncode([
      await _importFingerprint(request.collectionId),
      (await SqliteVocabularyContent(
        database,
      ).forCollection(request.collectionId)).map(
        (id, pairs) => MapEntry(id, [
          for (final p in pairs) [p.targetText, p.nativeText],
        ]),
      ),
    ]);
    try {
      final target = VocabularyLanguage.fromJson(source['targetLanguage']);
      final native = VocabularyLanguage.fromJson(source['nativeLanguage']);
      if (!target.matches(
            VocabularyLanguage.stored(
              owner.targetLanguage,
              owner.targetLanguageName,
            ),
          ) ||
          !native.matches(
            VocabularyLanguage.stored(
              owner.nativeLanguage,
              owner.nativeLanguageName,
            ),
          )) {
        issue(VocabularyJsonIssueCode.languageMismatch, 'collections[0]');
      }
    } on FormatException {
      issue(VocabularyJsonIssueCode.languageMismatch, 'collections[0]');
    }
    final exampleStore = SqliteVocabularyContent(database);
    final examples = await exampleStore.forCollection(owner.id);
    final existing = {
      for (final row in await (database.select(
        database.vocabularyEntries,
      )..where((row) => row.collectionId.equals(owner.id))).get())
        row.id: row,
    };
    final entryOwners = {
      for (final row
          in await database
              .customSelect('SELECT id,collection_id FROM vocabulary_entries')
              .get())
        row.read<String>('id'): row.read<String>('collection_id'),
    };
    final defaultVisibility = await SqliteVocabularyRepository(
      database,
    ).readHintVisibilityDefault(collectionId: request.collectionId);
    var usesDefaultVisibility = false;
    final dimensions = {
      for (final row
          in await database.select(database.categoryDimensions).get())
        row.id: row,
    };
    final values = {
      for (final row in await database.select(database.categoryValues).get())
        row.id: row,
    };
    final currentAssignments = <String, Map<String, Set<String>>>{};
    for (final row in await (database.select(
      database.vocabularyCategoryAssignments,
    )..where((row) => row.collectionId.equals(owner.id))).get()) {
      currentAssignments
          .putIfAbsent(row.entryId, () => {})
          .putIfAbsent(row.dimensionId, () => <String>{})
          .add(row.valueId);
    }
    final importedDimensions = <String, CategoryDimensionRecord>{};
    final importedValues = <String, CategoryValueRecord>{};
    final selectCategories = request.groups.contains(
      VocabularyJsonGroup.categoryAssignments,
    );
    if (selectCategories && source.containsKey('categoryDimensions')) {
      final definitions = source['categoryDimensions'];
      if (definitions is! List) {
        issue(
          VocabularyJsonIssueCode.invalidField,
          'collections[0].categoryDimensions',
        );
      } else {
        final definitionIds = <String>{};
        for (var index = 0; index < definitions.length; index++) {
          final definition = definitions[index];
          final path = 'collections[0].categoryDimensions[$index]';
          if (definition is! Map<String, dynamic>) {
            issue(VocabularyJsonIssueCode.invalidField, path);
            continue;
          }
          final id = _uuid(definition['id']);
          if (id == null) {
            issue(VocabularyJsonIssueCode.invalidId, '$path.id');
            continue;
          }
          if (!definitionIds.add(id)) {
            issue(VocabularyJsonIssueCode.duplicateId, '$path.id');
            continue;
          }
          final name = definition['name'];
          final mode = definition['mode'];
          final entries = definition['values'];
          if (name is! String ||
              name.trim().isEmpty ||
              (mode != 'single' && mode != 'multiple') ||
              entries is! List) {
            issue(VocabularyJsonIssueCode.invalidField, path);
            continue;
          }
          importedDimensions[id] = CategoryDimensionRecord(
            id: id,
            collectionId: owner.id,
            name: name.trim(),
            mode: CategoryMode.values.byName(mode as String),
            position: index,
          );
          if (values.containsKey(id) ||
              dimensions.containsKey(id) &&
                  dimensions[id]!.collectionId != owner.id) {
            issue(VocabularyJsonIssueCode.invalidOwnership, '$path.id');
          }
          final local = dimensions[id];
          if (local != null &&
              (local.name != name.trim() || local.mode != mode)) {
            notices.add(
              VocabularyJsonNotice.destinationCategoryMetadataRetained,
            );
          }
          for (var valueIndex = 0; valueIndex < entries.length; valueIndex++) {
            final value = entries[valueIndex];
            final valuePath = '$path.values[$valueIndex]';
            if (value is! Map<String, dynamic>) {
              issue(VocabularyJsonIssueCode.invalidField, valuePath);
              continue;
            }
            final valueId = _uuid(value['id']);
            if (valueId == null) {
              issue(VocabularyJsonIssueCode.invalidId, '$valuePath.id');
              continue;
            }
            if (!definitionIds.add(valueId)) {
              issue(VocabularyJsonIssueCode.duplicateId, '$valuePath.id');
              continue;
            }
            final valueName = value['name'];
            if (valueName is! String || valueName.trim().isEmpty) {
              issue(VocabularyJsonIssueCode.invalidField, '$valuePath.name');
              continue;
            }
            importedValues[valueId] = CategoryValueRecord(
              id: valueId,
              dimensionId: id,
              name: valueName.trim(),
              position: valueIndex,
            );
            if (dimensions.containsKey(valueId) ||
                values.containsKey(valueId) &&
                    values[valueId]!.dimensionId != id) {
              issue(VocabularyJsonIssueCode.invalidOwnership, '$valuePath.id');
            }
            if (values[valueId] != null &&
                values[valueId]!.name != valueName.trim()) {
              notices.add(
                VocabularyJsonNotice.destinationCategoryMetadataRetained,
              );
            }
          }
        }
      }
    }
    final referencedDimensions = <String>{}, referencedValues = <String>{};
    final finalPairs = {
      for (final entry in existing.values)
        entry.id: (
          vocabularyIdentityKey(entry.targetText),
          vocabularyIdentityKey(entry.nativeText),
          vocabularyIdentityKey(entry.hintText),
        ),
    };
    for (var index = 0; index < request.entries.length; index++) {
      final row = request.entries[index];
      if (row is! Map<String, dynamic>) continue;
      final path = 'collections[0].entries[$index]';
      final rowNumber = index + 1, id = request.ids[index];
      if (row.containsKey('learning')) {
        notices.add(VocabularyJsonNotice.importedLearningIgnored);
      }
      final old = existing[id];
      final startIssues = issues.length;
      if (!row.containsKey('id') && entryOwners.containsKey(id)) {
        issue(VocabularyJsonIssueCode.duplicateId, '$path.id', rowNumber);
      }
      if (entryOwners.containsKey(id) && entryOwners[id] != owner.id) {
        issue(VocabularyJsonIssueCode.foreignId, '$path.id', rowNumber);
      }
      String text(
        String field,
        VocabularyJsonGroup group,
        String? previous,
        VocabularyJsonIssueCode required,
      ) {
        final selected = old == null || request.groups.contains(group);
        if (!selected || !row.containsKey(field)) {
          if (previous != null) return previous;
          issue(required, '$path.$field', rowNumber);
          return '';
        }
        final raw = row[field];
        if (raw is! String) {
          issue(
            VocabularyJsonIssueCode.invalidField,
            '$path.$field',
            rowNumber,
          );
          return previous ?? '';
        }
        final normalized = normalizeVocabularyText(raw);
        if (vocabularyIdentityKey(normalized).isEmpty)
          issue(required, '$path.$field', rowNumber);
        return normalized;
      }

      final target = text(
        'targetText',
        VocabularyJsonGroup.targetText,
        old?.targetText,
        VocabularyJsonIssueCode.requiredTarget,
      );
      final native = text(
        'nativeText',
        VocabularyJsonGroup.nativeText,
        old?.nativeText,
        VocabularyJsonIssueCode.requiredNative,
      );
      final priorContent = old == null
          ? VocabularyContent(hintVisibility: defaultVisibility)
          : VocabularyContent.fromStored(
              examples: examples[old.id] ?? const [],
              hintText: old.hintText,
              hintVisibility: old.hintVisibility,
            );
      var pairs = priorContent.examples;
      var hintText = priorContent.hintText;
      var visibility = priorContent.hintVisibility;
      final selectExample =
          request.schemaVersion >= 2 &&
          request.groups.contains(VocabularyJsonGroup.example);
      final selectHint =
          request.schemaVersion >= 2 &&
          request.groups.contains(VocabularyJsonGroup.hint);
      String? optionalText(Object? raw, String field, int maximum) {
        if (raw == null) return null;
        if (raw is! String) {
          issue(
            VocabularyJsonIssueCode.invalidField,
            '$path.$field',
            rowNumber,
          );
          return null;
        }
        final value = normalizeVocabularyText(raw);
        if (value.runes.length > maximum) {
          issue(
            VocabularyJsonIssueCode.invalidField,
            '$path.$field',
            rowNumber,
          );
        }
        return value.isEmpty ? null : value;
      }

      final exampleField = request.schemaVersion == 2 ? 'example' : 'examples';
      if (selectExample && row.containsKey(exampleField)) {
        final raw = row[exampleField];
        final list = raw == null
            ? <Object?>[]
            : request.schemaVersion == 2
            ? [raw]
            : raw;
        if (list is! List) {
          issue(
            VocabularyJsonIssueCode.invalidField,
            '$path.$exampleField',
            rowNumber,
          );
        } else {
          pairs = [];
          for (var i = 0; i < list.length; i++) {
            final pair = list[i];
            final field = request.schemaVersion == 2
                ? exampleField
                : '$exampleField[$i]';
            if (pair is! Map<String, dynamic>) {
              issue(
                VocabularyJsonIssueCode.invalidField,
                '$path.$field',
                rowNumber,
              );
              continue;
            }
            for (final language in ['targetText', 'nativeText']) {
              if (pair[language] is! String) {
                issue(
                  VocabularyJsonIssueCode.invalidField,
                  '$path.$field.$language',
                  rowNumber,
                );
              }
            }
            final target = optionalText(
              pair['targetText'],
              '$field.targetText',
              VocabularyContent.maxExampleLength,
            );
            final native = optionalText(
              pair['nativeText'],
              '$field.nativeText',
              VocabularyContent.maxExampleLength,
            );
            if ((target == null) != (native == null)) {
              issue(
                VocabularyJsonIssueCode.invalidField,
                '$path.$field',
                rowNumber,
              );
            }
            if (target != null && native != null) {
              pairs.add(ExamplePair(targetText: target, nativeText: native));
            }
          }
        }
      }
      var explicitVisibility = false;
      if (selectHint && row.containsKey('hint')) {
        final hint = row['hint'];
        if (hint == null) {
          hintText = null;
        } else if (hint is! Map<String, dynamic>) {
          issue(VocabularyJsonIssueCode.invalidField, '$path.hint', rowNumber);
        } else {
          if (hint.containsKey('text')) {
            hintText = optionalText(
              hint['text'],
              'hint.text',
              VocabularyContent.maxHintLength,
            );
          }
          if (hint.containsKey('visibility')) {
            explicitVisibility = true;
            if (!['always', 'hidden'].contains(hint['visibility'])) {
              issue(
                VocabularyJsonIssueCode.invalidField,
                '$path.hint.visibility',
                rowNumber,
              );
            } else {
              visibility = HintVisibility.values.byName(
                hint['visibility'] as String,
              );
            }
          }
        }
      }
      if (old == null && !explicitVisibility) usesDefaultVisibility = true;
      var active = old?.active ?? true;
      if (request.schemaVersion >= 4 && row.containsKey('active')) {
        if (row['active'] is! bool) {
          issue(
            VocabularyJsonIssueCode.invalidField,
            '$path.active',
            rowNumber,
          );
        } else if (request.groups.contains(VocabularyJsonGroup.activity)) {
          active = row['active'] as bool;
        }
      }
      final content = VocabularyContent(
        examples: pairs,
        hintText: hintText,
        hintVisibility: visibility,
      );
      Map<String, Set<String>>? assignments;
      if (selectCategories && row.containsKey('categoryAssignments')) {
        assignments = {};
        final groups = row['categoryAssignments'];
        if (groups is! List) {
          issue(
            VocabularyJsonIssueCode.invalidField,
            '$path.categoryAssignments',
            rowNumber,
          );
        } else {
          for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
            final group = groups[groupIndex];
            final groupPath = '$path.categoryAssignments[$groupIndex]';
            if (group is! Map<String, dynamic>) {
              issue(VocabularyJsonIssueCode.invalidField, groupPath, rowNumber);
              continue;
            }
            final dimensionId = _uuid(group['dimensionId']);
            if (dimensionId == null) {
              issue(
                VocabularyJsonIssueCode.invalidId,
                '$groupPath.dimensionId',
                rowNumber,
              );
              continue;
            }
            if (assignments.containsKey(dimensionId)) {
              issue(
                VocabularyJsonIssueCode.duplicateId,
                '$groupPath.dimensionId',
                rowNumber,
              );
              continue;
            }
            final dimension = dimensions[dimensionId];
            final importedDimension = importedDimensions[dimensionId];
            if (dimension != null && dimension.collectionId != owner.id ||
                values.containsKey(dimensionId)) {
              issue(
                VocabularyJsonIssueCode.invalidOwnership,
                '$groupPath.dimensionId',
                rowNumber,
              );
            }
            if (dimension == null && importedDimension == null) {
              issue(
                VocabularyJsonIssueCode.unknownDimension,
                '$groupPath.dimensionId',
                rowNumber,
              );
            }
            final ids = group['valueIds'];
            final valueIds = <String>{};
            assignments[dimensionId] = valueIds;
            if (ids is! List) {
              issue(
                VocabularyJsonIssueCode.invalidField,
                '$groupPath.valueIds',
                rowNumber,
              );
              continue;
            }
            for (var valueIndex = 0; valueIndex < ids.length; valueIndex++) {
              final valuePath = '$groupPath.valueIds[$valueIndex]';
              final valueId = _uuid(ids[valueIndex]);
              if (valueId == null) {
                issue(VocabularyJsonIssueCode.invalidId, valuePath, rowNumber);
                continue;
              }
              if (!valueIds.add(valueId)) {
                issue(
                  VocabularyJsonIssueCode.duplicateId,
                  valuePath,
                  rowNumber,
                );
                continue;
              }
              final value = values[valueId];
              final importedValue = importedValues[valueId];
              if (value != null
                  ? value.dimensionId != dimensionId
                  : importedValue != null &&
                            importedValue.dimensionId != dimensionId ||
                        dimensions.containsKey(valueId)) {
                issue(
                  VocabularyJsonIssueCode.invalidOwnership,
                  valuePath,
                  rowNumber,
                );
              }
              if (value == null && importedValue == null) {
                issue(
                  VocabularyJsonIssueCode.unknownValue,
                  valuePath,
                  rowNumber,
                );
              }
              referencedValues.add(valueId);
            }
            final mode = dimension?.mode ?? importedDimension?.mode.name;
            if (mode == 'single' && valueIds.length > 1) {
              issue(
                VocabularyJsonIssueCode.cardinalityViolation,
                groupPath,
                rowNumber,
              );
            }
            if (valueIds.isNotEmpty) referencedDimensions.add(dimensionId);
          }
        }
      }
      finalPairs[id] = (
        vocabularyIdentityKey(target),
        vocabularyIdentityKey(native),
        vocabularyIdentityKey(content.hintText),
      );
      if (issues.length != startIssues ||
          request.issues.any((issue) => issue.row == rowNumber)) {
        continue;
      }
      if (assignments != null) {
        assignments = {
          for (final group in assignments.entries)
            if (group.value.isNotEmpty) group.key: group.value,
        };
      }
      final priorAssignments =
          currentAssignments[id] ?? <String, Set<String>>{};
      bool sameAssignments(Map<String, Set<String>> next) {
        final nonempty = {
          for (final entry in next.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value,
        };
        return priorAssignments.length == nonempty.length &&
            nonempty.entries.every(
              (entry) =>
                  priorAssignments[entry.key]?.length == entry.value.length &&
                  priorAssignments[entry.key]!.containsAll(entry.value),
            );
      }

      changes.add(
        _EntryChange(
          id: id,
          target: target,
          native: native,
          isNew: old == null,
          assignments: assignments,
          content: content,
          active: active,
          changed:
              old == null ||
              target != old.targetText ||
              native != old.nativeText ||
              content != priorContent ||
              active != old.active ||
              assignments != null && !sameAssignments(assignments),
        ),
      );
    }
    if (usesDefaultVisibility) {
      fingerprint = jsonEncode([
        fingerprint,
        {'hintVisibilityDefault': defaultVisibility.name},
      ]);
    }
    final pairOwners = <(String, String, String), String>{};
    final collisions = <String>{};
    for (final entry in finalPairs.entries) {
      final prior = pairOwners[entry.value];
      if (prior != null) {
        collisions.add(prior);
        collisions.add(entry.key);
      }
      pairOwners[entry.value] = entry.key;
    }
    for (var index = 0; index < request.ids.length; index++) {
      if (collisions.contains(request.ids[index])) {
        issue(
          VocabularyJsonIssueCode.duplicatePair,
          'collections[0].entries[$index]',
          index + 1,
        );
      }
    }
    final dimensionNames = {
      for (final dimension in dimensions.values.where(
        (d) => d.collectionId == owner.id,
      ))
        dimension.nameKey: dimension.id,
    };
    for (final definition in importedDimensions.values) {
      if (!referencedDimensions.contains(definition.id) ||
          dimensions.containsKey(definition.id)) {
        continue;
      }
      final key = definition.name.toLowerCase();
      if (dimensionNames.containsKey(key) &&
          dimensionNames[key] != definition.id) {
        issue(
          VocabularyJsonIssueCode.duplicateName,
          'categoryDimensions.${definition.id}.name',
        );
      }
      dimensionNames[key] = definition.id;
      newDimensions.add(definition);
    }
    final valueNames = <(String, String), String>{
      for (final value in values.values)
        (value.dimensionId, value.nameKey): value.id,
    };
    for (final value in importedValues.values) {
      if (!referencedValues.contains(value.id) ||
          values.containsKey(value.id)) {
        continue;
      }
      final key = (value.dimensionId, value.name.toLowerCase());
      if (valueNames.containsKey(key) && valueNames[key] != value.id) {
        issue(
          VocabularyJsonIssueCode.duplicateName,
          'categoryValues.${value.id}.name',
        );
      }
      valueNames[key] = value.id;
      newValues.add(value);
    }
    return result();
  }

  Future<VocabularyJsonApplyResult> _applyImport(
    VocabularyJsonPreview preview,
  ) async {
    if (preview is! _SqliteImportPreview ||
        !identical(preview.issuer, _importIssuer) ||
        !preview.canApply) {
      throw VocabularyJsonApplyFailure.invalidPreview;
    }
    if (preview.consumed) throw VocabularyJsonApplyFailure.alreadyApplied;
    if (preview.pending) throw VocabularyJsonApplyFailure.inProgress;
    preview.pending = true;
    try {
      final result = await database.transaction(() async {
        final current = await _planImport(preview.plan.request);
        if (current.issues.isNotEmpty ||
            current.fingerprint != preview.plan.fingerprint) {
          throw VocabularyJsonApplyFailure.stalePreview;
        }
        final categories = SqliteCategoriesRepository(database);
        for (final dimension in current.dimensions) {
          await categories.createDimension(
            collectionId: preview.collectionId,
            id: dimension.id,
            name: dimension.name,
            mode: dimension.mode,
          );
        }
        for (final value in current.values) {
          await categories.createValue(
            dimensionId: value.dimensionId,
            id: value.id,
            name: value.name,
          );
        }
        final changedTexts = <_EntryChange>[];
        final occupied = <(String, String, String)>{};
        for (final row
            in await (database.select(database.vocabularyEntries)..where(
                  (row) => row.collectionId.equals(preview.collectionId),
                ))
                .get()) {
          occupied.add((row.targetKey, row.nativeKey, row.hintKey));
        }
        for (final entry in current.entries) {
          occupied.add((
            vocabularyIdentityKey(entry.target),
            vocabularyIdentityKey(entry.native),
            vocabularyIdentityKey(entry.content.hintText),
          ));
          if (entry.isNew || !entry.changed) continue;
          final stored = await (database.select(
            database.vocabularyEntries,
          )..where((row) => row.id.equals(entry.id))).getSingle();
          if (stored.targetText != entry.target ||
              stored.nativeText != entry.native ||
              stored.hintKey != vocabularyIdentityKey(entry.content.hintText)) {
            changedTexts.add(entry);
          }
        }
        // Reserve temporary unique comparison pairs only inside this transaction
        // so complete final-state swaps never delete/recreate vocabulary rows.
        for (final entry in changedTexts) {
          var token = const Uuid().v4();
          while (occupied.contains((token, token, token))) {
            token = const Uuid().v4();
          }
          occupied.add((token, token, token));
          final count =
              await (database.update(
                database.vocabularyEntries,
              )..where((row) => row.id.equals(entry.id))).write(
                VocabularyEntriesCompanion(
                  targetKey: Value(token),
                  nativeKey: Value(token),
                  hintKey: Value(token),
                ),
              );
          if (count != 1) {
            throw StateError('Import vocabulary reservation failed');
          }
        }
        for (final entry in current.entries) {
          if (entry.isNew) {
            final rowId = await database.allocateVocabularyRowId();
            await database.customInsert(
              'INSERT INTO vocabulary_entries(rowid,id,collection_id,target_text,native_text,target_key,native_key,hint_key,hint_text,hint_visibility,added_at,active) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)',
              variables: [
                Variable(rowId),
                Variable(entry.id),
                Variable(preview.collectionId),
                Variable(entry.target),
                Variable(entry.native),
                Variable(vocabularyIdentityKey(entry.target)),
                Variable(vocabularyIdentityKey(entry.native)),
                Variable(vocabularyIdentityKey(entry.content.hintText)),

                Variable<String>(entry.content.hintText),
                Variable(entry.content.hintVisibility.name),
                Variable(clock.now().toUtc().toIso8601String()),
                Variable(entry.active),
              ],
              updates: {database.vocabularyEntries},
            );
            await database.createLearningItems(entry.id);
          } else if (entry.changed) {
            final count =
                await (database.update(
                  database.vocabularyEntries,
                )..where((row) => row.id.equals(entry.id))).write(
                  VocabularyEntriesCompanion(
                    targetText: Value(entry.target),
                    nativeText: Value(entry.native),
                    targetKey: Value(vocabularyIdentityKey(entry.target)),
                    nativeKey: Value(vocabularyIdentityKey(entry.native)),
                    hintKey: Value(
                      vocabularyIdentityKey(entry.content.hintText),
                    ),

                    active: Value(entry.active),
                    hintText: Value(entry.content.hintText),
                    hintVisibility: Value(entry.content.hintVisibility.name),
                  ),
                );
            if (count != 1) throw StateError('Import vocabulary update failed');
          }
          if (entry.isNew || entry.changed) {
            await SqliteVocabularyContent(
              database,
            ).replace(entry.id, entry.content);
          }
          if (entry.assignments != null && (entry.isNew || entry.changed)) {
            await categories.replaceAssignments(
              entryId: entry.id,
              assignments: entry.assignments!,
            );
          }
        }
        return VocabularyJsonApplyResult(
          newCount: current.newCount,
          updatedCount: current.updatedCount,
          unchangedCount: current.unchangedCount,
        );
      });
      preview.consumed = true;
      return result;
    } finally {
      preview.pending = false;
    }
  }
}
