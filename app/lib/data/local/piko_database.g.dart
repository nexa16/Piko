// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'piko_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionsTable extends Collections
    with TableInfo<$CollectionsTable, Collection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetLanguageMeta = const VerificationMeta(
    'targetLanguage',
  );
  @override
  late final GeneratedColumn<String> targetLanguage = GeneratedColumn<String>(
    'target_language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nativeLanguageMeta = const VerificationMeta(
    'nativeLanguage',
  );
  @override
  late final GeneratedColumn<String> nativeLanguage = GeneratedColumn<String>(
    'native_language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    targetLanguage,
    nativeLanguage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<Collection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('target_language')) {
      context.handle(
        _targetLanguageMeta,
        targetLanguage.isAcceptableOrUnknown(
          data['target_language']!,
          _targetLanguageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetLanguageMeta);
    }
    if (data.containsKey('native_language')) {
      context.handle(
        _nativeLanguageMeta,
        nativeLanguage.isAcceptableOrUnknown(
          data['native_language']!,
          _nativeLanguageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nativeLanguageMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Collection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Collection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      targetLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_language'],
      )!,
      nativeLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}native_language'],
      )!,
    );
  }

  @override
  $CollectionsTable createAlias(String alias) {
    return $CollectionsTable(attachedDatabase, alias);
  }
}

class Collection extends DataClass implements Insertable<Collection> {
  final String id;
  final String name;
  final String targetLanguage;
  final String nativeLanguage;
  const Collection({
    required this.id,
    required this.name,
    required this.targetLanguage,
    required this.nativeLanguage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['target_language'] = Variable<String>(targetLanguage);
    map['native_language'] = Variable<String>(nativeLanguage);
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      targetLanguage: Value(targetLanguage),
      nativeLanguage: Value(nativeLanguage),
    );
  }

  factory Collection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Collection(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      targetLanguage: serializer.fromJson<String>(json['targetLanguage']),
      nativeLanguage: serializer.fromJson<String>(json['nativeLanguage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'targetLanguage': serializer.toJson<String>(targetLanguage),
      'nativeLanguage': serializer.toJson<String>(nativeLanguage),
    };
  }

  Collection copyWith({
    String? id,
    String? name,
    String? targetLanguage,
    String? nativeLanguage,
  }) => Collection(
    id: id ?? this.id,
    name: name ?? this.name,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    nativeLanguage: nativeLanguage ?? this.nativeLanguage,
  );
  Collection copyWithCompanion(CollectionsCompanion data) {
    return Collection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      targetLanguage: data.targetLanguage.present
          ? data.targetLanguage.value
          : this.targetLanguage,
      nativeLanguage: data.nativeLanguage.present
          ? data.nativeLanguage.value
          : this.nativeLanguage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Collection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('targetLanguage: $targetLanguage, ')
          ..write('nativeLanguage: $nativeLanguage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, targetLanguage, nativeLanguage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Collection &&
          other.id == this.id &&
          other.name == this.name &&
          other.targetLanguage == this.targetLanguage &&
          other.nativeLanguage == this.nativeLanguage);
}

class CollectionsCompanion extends UpdateCompanion<Collection> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> targetLanguage;
  final Value<String> nativeLanguage;
  final Value<int> rowid;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.targetLanguage = const Value.absent(),
    this.nativeLanguage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionsCompanion.insert({
    required String id,
    required String name,
    required String targetLanguage,
    required String nativeLanguage,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       targetLanguage = Value(targetLanguage),
       nativeLanguage = Value(nativeLanguage);
  static Insertable<Collection> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? targetLanguage,
    Expression<String>? nativeLanguage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (targetLanguage != null) 'target_language': targetLanguage,
      if (nativeLanguage != null) 'native_language': nativeLanguage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? targetLanguage,
    Value<String>? nativeLanguage,
    Value<int>? rowid,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (targetLanguage.present) {
      map['target_language'] = Variable<String>(targetLanguage.value);
    }
    if (nativeLanguage.present) {
      map['native_language'] = Variable<String>(nativeLanguage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('targetLanguage: $targetLanguage, ')
          ..write('nativeLanguage: $nativeLanguage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VocabularyEntriesTable extends VocabularyEntries
    with TableInfo<$VocabularyEntriesTable, VocabularyEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabularyEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES collections (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _targetTextMeta = const VerificationMeta(
    'targetText',
  );
  @override
  late final GeneratedColumn<String> targetText = GeneratedColumn<String>(
    'target_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nativeTextMeta = const VerificationMeta(
    'nativeText',
  );
  @override
  late final GeneratedColumn<String> nativeText = GeneratedColumn<String>(
    'native_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetKeyMeta = const VerificationMeta(
    'targetKey',
  );
  @override
  late final GeneratedColumn<String> targetKey = GeneratedColumn<String>(
    'target_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nativeKeyMeta = const VerificationMeta(
    'nativeKey',
  );
  @override
  late final GeneratedColumn<String> nativeKey = GeneratedColumn<String>(
    'native_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collectionId,
    targetText,
    nativeText,
    targetKey,
    nativeKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocabulary_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<VocabularyEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('target_text')) {
      context.handle(
        _targetTextMeta,
        targetText.isAcceptableOrUnknown(data['target_text']!, _targetTextMeta),
      );
    } else if (isInserting) {
      context.missing(_targetTextMeta);
    }
    if (data.containsKey('native_text')) {
      context.handle(
        _nativeTextMeta,
        nativeText.isAcceptableOrUnknown(data['native_text']!, _nativeTextMeta),
      );
    } else if (isInserting) {
      context.missing(_nativeTextMeta);
    }
    if (data.containsKey('target_key')) {
      context.handle(
        _targetKeyMeta,
        targetKey.isAcceptableOrUnknown(data['target_key']!, _targetKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_targetKeyMeta);
    }
    if (data.containsKey('native_key')) {
      context.handle(
        _nativeKeyMeta,
        nativeKey.isAcceptableOrUnknown(data['native_key']!, _nativeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nativeKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VocabularyEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabularyEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      )!,
      targetText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_text'],
      )!,
      nativeText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}native_text'],
      )!,
      targetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_key'],
      )!,
      nativeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}native_key'],
      )!,
    );
  }

  @override
  $VocabularyEntriesTable createAlias(String alias) {
    return $VocabularyEntriesTable(attachedDatabase, alias);
  }
}

class VocabularyEntry extends DataClass implements Insertable<VocabularyEntry> {
  final String id;
  final String collectionId;
  final String targetText;
  final String nativeText;
  final String targetKey;
  final String nativeKey;
  const VocabularyEntry({
    required this.id,
    required this.collectionId,
    required this.targetText,
    required this.nativeText,
    required this.targetKey,
    required this.nativeKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['collection_id'] = Variable<String>(collectionId);
    map['target_text'] = Variable<String>(targetText);
    map['native_text'] = Variable<String>(nativeText);
    map['target_key'] = Variable<String>(targetKey);
    map['native_key'] = Variable<String>(nativeKey);
    return map;
  }

  VocabularyEntriesCompanion toCompanion(bool nullToAbsent) {
    return VocabularyEntriesCompanion(
      id: Value(id),
      collectionId: Value(collectionId),
      targetText: Value(targetText),
      nativeText: Value(nativeText),
      targetKey: Value(targetKey),
      nativeKey: Value(nativeKey),
    );
  }

  factory VocabularyEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabularyEntry(
      id: serializer.fromJson<String>(json['id']),
      collectionId: serializer.fromJson<String>(json['collectionId']),
      targetText: serializer.fromJson<String>(json['targetText']),
      nativeText: serializer.fromJson<String>(json['nativeText']),
      targetKey: serializer.fromJson<String>(json['targetKey']),
      nativeKey: serializer.fromJson<String>(json['nativeKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'collectionId': serializer.toJson<String>(collectionId),
      'targetText': serializer.toJson<String>(targetText),
      'nativeText': serializer.toJson<String>(nativeText),
      'targetKey': serializer.toJson<String>(targetKey),
      'nativeKey': serializer.toJson<String>(nativeKey),
    };
  }

  VocabularyEntry copyWith({
    String? id,
    String? collectionId,
    String? targetText,
    String? nativeText,
    String? targetKey,
    String? nativeKey,
  }) => VocabularyEntry(
    id: id ?? this.id,
    collectionId: collectionId ?? this.collectionId,
    targetText: targetText ?? this.targetText,
    nativeText: nativeText ?? this.nativeText,
    targetKey: targetKey ?? this.targetKey,
    nativeKey: nativeKey ?? this.nativeKey,
  );
  VocabularyEntry copyWithCompanion(VocabularyEntriesCompanion data) {
    return VocabularyEntry(
      id: data.id.present ? data.id.value : this.id,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      targetText: data.targetText.present
          ? data.targetText.value
          : this.targetText,
      nativeText: data.nativeText.present
          ? data.nativeText.value
          : this.nativeText,
      targetKey: data.targetKey.present ? data.targetKey.value : this.targetKey,
      nativeKey: data.nativeKey.present ? data.nativeKey.value : this.nativeKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyEntry(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('targetText: $targetText, ')
          ..write('nativeText: $nativeText, ')
          ..write('targetKey: $targetKey, ')
          ..write('nativeKey: $nativeKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    collectionId,
    targetText,
    nativeText,
    targetKey,
    nativeKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabularyEntry &&
          other.id == this.id &&
          other.collectionId == this.collectionId &&
          other.targetText == this.targetText &&
          other.nativeText == this.nativeText &&
          other.targetKey == this.targetKey &&
          other.nativeKey == this.nativeKey);
}

class VocabularyEntriesCompanion extends UpdateCompanion<VocabularyEntry> {
  final Value<String> id;
  final Value<String> collectionId;
  final Value<String> targetText;
  final Value<String> nativeText;
  final Value<String> targetKey;
  final Value<String> nativeKey;
  final Value<int> rowid;
  const VocabularyEntriesCompanion({
    this.id = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.targetText = const Value.absent(),
    this.nativeText = const Value.absent(),
    this.targetKey = const Value.absent(),
    this.nativeKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VocabularyEntriesCompanion.insert({
    required String id,
    required String collectionId,
    required String targetText,
    required String nativeText,
    required String targetKey,
    required String nativeKey,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       collectionId = Value(collectionId),
       targetText = Value(targetText),
       nativeText = Value(nativeText),
       targetKey = Value(targetKey),
       nativeKey = Value(nativeKey);
  static Insertable<VocabularyEntry> custom({
    Expression<String>? id,
    Expression<String>? collectionId,
    Expression<String>? targetText,
    Expression<String>? nativeText,
    Expression<String>? targetKey,
    Expression<String>? nativeKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collectionId != null) 'collection_id': collectionId,
      if (targetText != null) 'target_text': targetText,
      if (nativeText != null) 'native_text': nativeText,
      if (targetKey != null) 'target_key': targetKey,
      if (nativeKey != null) 'native_key': nativeKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VocabularyEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? collectionId,
    Value<String>? targetText,
    Value<String>? nativeText,
    Value<String>? targetKey,
    Value<String>? nativeKey,
    Value<int>? rowid,
  }) {
    return VocabularyEntriesCompanion(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      targetText: targetText ?? this.targetText,
      nativeText: nativeText ?? this.nativeText,
      targetKey: targetKey ?? this.targetKey,
      nativeKey: nativeKey ?? this.nativeKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (targetText.present) {
      map['target_text'] = Variable<String>(targetText.value);
    }
    if (nativeText.present) {
      map['native_text'] = Variable<String>(nativeText.value);
    }
    if (targetKey.present) {
      map['target_key'] = Variable<String>(targetKey.value);
    }
    if (nativeKey.present) {
      map['native_key'] = Variable<String>(nativeKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyEntriesCompanion(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('targetText: $targetText, ')
          ..write('nativeText: $nativeText, ')
          ..write('targetKey: $targetKey, ')
          ..write('nativeKey: $nativeKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningItemsTable extends LearningItems
    with TableInfo<$LearningItemsTable, LearningItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vocabulary_entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatVersionMeta = const VerificationMeta(
    'formatVersion',
  );
  @override
  late final GeneratedColumn<int> formatVersion = GeneratedColumn<int>(
    'format_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardJsonMeta = const VerificationMeta(
    'cardJson',
  );
  @override
  late final GeneratedColumn<String> cardJson = GeneratedColumn<String>(
    'card_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entryId,
    direction,
    formatVersion,
    cardJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('format_version')) {
      context.handle(
        _formatVersionMeta,
        formatVersion.isAcceptableOrUnknown(
          data['format_version']!,
          _formatVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatVersionMeta);
    }
    if (data.containsKey('card_json')) {
      context.handle(
        _cardJsonMeta,
        cardJson.isAcceptableOrUnknown(data['card_json']!, _cardJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_cardJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearningItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      formatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_version'],
      )!,
      cardJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_json'],
      )!,
    );
  }

  @override
  $LearningItemsTable createAlias(String alias) {
    return $LearningItemsTable(attachedDatabase, alias);
  }
}

class LearningItem extends DataClass implements Insertable<LearningItem> {
  final int id;
  final String entryId;
  final String direction;
  final int formatVersion;
  final String cardJson;
  const LearningItem({
    required this.id,
    required this.entryId,
    required this.direction,
    required this.formatVersion,
    required this.cardJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entry_id'] = Variable<String>(entryId);
    map['direction'] = Variable<String>(direction);
    map['format_version'] = Variable<int>(formatVersion);
    map['card_json'] = Variable<String>(cardJson);
    return map;
  }

  LearningItemsCompanion toCompanion(bool nullToAbsent) {
    return LearningItemsCompanion(
      id: Value(id),
      entryId: Value(entryId),
      direction: Value(direction),
      formatVersion: Value(formatVersion),
      cardJson: Value(cardJson),
    );
  }

  factory LearningItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningItem(
      id: serializer.fromJson<int>(json['id']),
      entryId: serializer.fromJson<String>(json['entryId']),
      direction: serializer.fromJson<String>(json['direction']),
      formatVersion: serializer.fromJson<int>(json['formatVersion']),
      cardJson: serializer.fromJson<String>(json['cardJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entryId': serializer.toJson<String>(entryId),
      'direction': serializer.toJson<String>(direction),
      'formatVersion': serializer.toJson<int>(formatVersion),
      'cardJson': serializer.toJson<String>(cardJson),
    };
  }

  LearningItem copyWith({
    int? id,
    String? entryId,
    String? direction,
    int? formatVersion,
    String? cardJson,
  }) => LearningItem(
    id: id ?? this.id,
    entryId: entryId ?? this.entryId,
    direction: direction ?? this.direction,
    formatVersion: formatVersion ?? this.formatVersion,
    cardJson: cardJson ?? this.cardJson,
  );
  LearningItem copyWithCompanion(LearningItemsCompanion data) {
    return LearningItem(
      id: data.id.present ? data.id.value : this.id,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      direction: data.direction.present ? data.direction.value : this.direction,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      cardJson: data.cardJson.present ? data.cardJson.value : this.cardJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningItem(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('direction: $direction, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('cardJson: $cardJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entryId, direction, formatVersion, cardJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningItem &&
          other.id == this.id &&
          other.entryId == this.entryId &&
          other.direction == this.direction &&
          other.formatVersion == this.formatVersion &&
          other.cardJson == this.cardJson);
}

class LearningItemsCompanion extends UpdateCompanion<LearningItem> {
  final Value<int> id;
  final Value<String> entryId;
  final Value<String> direction;
  final Value<int> formatVersion;
  final Value<String> cardJson;
  const LearningItemsCompanion({
    this.id = const Value.absent(),
    this.entryId = const Value.absent(),
    this.direction = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.cardJson = const Value.absent(),
  });
  LearningItemsCompanion.insert({
    this.id = const Value.absent(),
    required String entryId,
    required String direction,
    required int formatVersion,
    required String cardJson,
  }) : entryId = Value(entryId),
       direction = Value(direction),
       formatVersion = Value(formatVersion),
       cardJson = Value(cardJson);
  static Insertable<LearningItem> custom({
    Expression<int>? id,
    Expression<String>? entryId,
    Expression<String>? direction,
    Expression<int>? formatVersion,
    Expression<String>? cardJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      if (direction != null) 'direction': direction,
      if (formatVersion != null) 'format_version': formatVersion,
      if (cardJson != null) 'card_json': cardJson,
    });
  }

  LearningItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? entryId,
    Value<String>? direction,
    Value<int>? formatVersion,
    Value<String>? cardJson,
  }) {
    return LearningItemsCompanion(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      direction: direction ?? this.direction,
      formatVersion: formatVersion ?? this.formatVersion,
      cardJson: cardJson ?? this.cardJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (formatVersion.present) {
      map['format_version'] = Variable<int>(formatVersion.value);
    }
    if (cardJson.present) {
      map['card_json'] = Variable<String>(cardJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningItemsCompanion(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('direction: $direction, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('cardJson: $cardJson')
          ..write(')'))
        .toString();
  }
}

class $LearningIdentitySequenceTable extends LearningIdentitySequence
    with
        TableInfo<
          $LearningIdentitySequenceTable,
          LearningIdentitySequenceData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningIdentitySequenceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonMeta = const VerificationMeta(
    'singleton',
  );
  @override
  late final GeneratedColumn<int> singleton = GeneratedColumn<int>(
    'singleton',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextIdMeta = const VerificationMeta('nextId');
  @override
  late final GeneratedColumn<int> nextId = GeneratedColumn<int>(
    'next_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [singleton, nextId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_identity_sequence';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningIdentitySequenceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton')) {
      context.handle(
        _singletonMeta,
        singleton.isAcceptableOrUnknown(data['singleton']!, _singletonMeta),
      );
    }
    if (data.containsKey('next_id')) {
      context.handle(
        _nextIdMeta,
        nextId.isAcceptableOrUnknown(data['next_id']!, _nextIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nextIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singleton};
  @override
  LearningIdentitySequenceData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningIdentitySequenceData(
      singleton: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton'],
      )!,
      nextId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_id'],
      )!,
    );
  }

  @override
  $LearningIdentitySequenceTable createAlias(String alias) {
    return $LearningIdentitySequenceTable(attachedDatabase, alias);
  }
}

class LearningIdentitySequenceData extends DataClass
    implements Insertable<LearningIdentitySequenceData> {
  final int singleton;
  final int nextId;
  const LearningIdentitySequenceData({
    required this.singleton,
    required this.nextId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton'] = Variable<int>(singleton);
    map['next_id'] = Variable<int>(nextId);
    return map;
  }

  LearningIdentitySequenceCompanion toCompanion(bool nullToAbsent) {
    return LearningIdentitySequenceCompanion(
      singleton: Value(singleton),
      nextId: Value(nextId),
    );
  }

  factory LearningIdentitySequenceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningIdentitySequenceData(
      singleton: serializer.fromJson<int>(json['singleton']),
      nextId: serializer.fromJson<int>(json['nextId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singleton': serializer.toJson<int>(singleton),
      'nextId': serializer.toJson<int>(nextId),
    };
  }

  LearningIdentitySequenceData copyWith({int? singleton, int? nextId}) =>
      LearningIdentitySequenceData(
        singleton: singleton ?? this.singleton,
        nextId: nextId ?? this.nextId,
      );
  LearningIdentitySequenceData copyWithCompanion(
    LearningIdentitySequenceCompanion data,
  ) {
    return LearningIdentitySequenceData(
      singleton: data.singleton.present ? data.singleton.value : this.singleton,
      nextId: data.nextId.present ? data.nextId.value : this.nextId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningIdentitySequenceData(')
          ..write('singleton: $singleton, ')
          ..write('nextId: $nextId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(singleton, nextId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningIdentitySequenceData &&
          other.singleton == this.singleton &&
          other.nextId == this.nextId);
}

class LearningIdentitySequenceCompanion
    extends UpdateCompanion<LearningIdentitySequenceData> {
  final Value<int> singleton;
  final Value<int> nextId;
  const LearningIdentitySequenceCompanion({
    this.singleton = const Value.absent(),
    this.nextId = const Value.absent(),
  });
  LearningIdentitySequenceCompanion.insert({
    this.singleton = const Value.absent(),
    required int nextId,
  }) : nextId = Value(nextId);
  static Insertable<LearningIdentitySequenceData> custom({
    Expression<int>? singleton,
    Expression<int>? nextId,
  }) {
    return RawValuesInsertable({
      if (singleton != null) 'singleton': singleton,
      if (nextId != null) 'next_id': nextId,
    });
  }

  LearningIdentitySequenceCompanion copyWith({
    Value<int>? singleton,
    Value<int>? nextId,
  }) {
    return LearningIdentitySequenceCompanion(
      singleton: singleton ?? this.singleton,
      nextId: nextId ?? this.nextId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singleton.present) {
      map['singleton'] = Variable<int>(singleton.value);
    }
    if (nextId.present) {
      map['next_id'] = Variable<int>(nextId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningIdentitySequenceCompanion(')
          ..write('singleton: $singleton, ')
          ..write('nextId: $nextId')
          ..write(')'))
        .toString();
  }
}

abstract class _$PikoDatabase extends GeneratedDatabase {
  _$PikoDatabase(QueryExecutor e) : super(e);
  $PikoDatabaseManager get managers => $PikoDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $CollectionsTable collections = $CollectionsTable(this);
  late final $VocabularyEntriesTable vocabularyEntries =
      $VocabularyEntriesTable(this);
  late final $LearningItemsTable learningItems = $LearningItemsTable(this);
  late final $LearningIdentitySequenceTable learningIdentitySequence =
      $LearningIdentitySequenceTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    collections,
    vocabularyEntries,
    learningItems,
    learningIdentitySequence,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'collections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('vocabulary_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vocabulary_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learning_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$PikoDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$PikoDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$PikoDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$PikoDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$PikoDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$PikoDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$PikoDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$CollectionsTableCreateCompanionBuilder =
    CollectionsCompanion Function({
      required String id,
      required String name,
      required String targetLanguage,
      required String nativeLanguage,
      Value<int> rowid,
    });
typedef $$CollectionsTableUpdateCompanionBuilder =
    CollectionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> targetLanguage,
      Value<String> nativeLanguage,
      Value<int> rowid,
    });

final class $$CollectionsTableReferences
    extends BaseReferences<_$PikoDatabase, $CollectionsTable, Collection> {
  $$CollectionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VocabularyEntriesTable, List<VocabularyEntry>>
  _vocabularyEntriesRefsTable(_$PikoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.vocabularyEntries,
        aliasName: 'collections__id__vocabulary_entries__collection_id',
      );

  $$VocabularyEntriesTableProcessedTableManager get vocabularyEntriesRefs {
    final manager = $$VocabularyEntriesTableTableManager(
      $_db,
      $_db.vocabularyEntries,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _vocabularyEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CollectionsTableFilterComposer
    extends Composer<_$PikoDatabase, $CollectionsTable> {
  $$CollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetLanguage => $composableBuilder(
    column: $table.targetLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nativeLanguage => $composableBuilder(
    column: $table.nativeLanguage,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> vocabularyEntriesRefs(
    Expression<bool> Function($$VocabularyEntriesTableFilterComposer f) f,
  ) {
    final $$VocabularyEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vocabularyEntries,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabularyEntriesTableFilterComposer(
            $db: $db,
            $table: $db.vocabularyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionsTableOrderingComposer
    extends Composer<_$PikoDatabase, $CollectionsTable> {
  $$CollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetLanguage => $composableBuilder(
    column: $table.targetLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nativeLanguage => $composableBuilder(
    column: $table.nativeLanguage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionsTableAnnotationComposer
    extends Composer<_$PikoDatabase, $CollectionsTable> {
  $$CollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get targetLanguage => $composableBuilder(
    column: $table.targetLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nativeLanguage => $composableBuilder(
    column: $table.nativeLanguage,
    builder: (column) => column,
  );

  Expression<T> vocabularyEntriesRefs<T extends Object>(
    Expression<T> Function($$VocabularyEntriesTableAnnotationComposer a) f,
  ) {
    final $$VocabularyEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.vocabularyEntries,
          getReferencedColumn: (t) => t.collectionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VocabularyEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.vocabularyEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CollectionsTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $CollectionsTable,
          Collection,
          $$CollectionsTableFilterComposer,
          $$CollectionsTableOrderingComposer,
          $$CollectionsTableAnnotationComposer,
          $$CollectionsTableCreateCompanionBuilder,
          $$CollectionsTableUpdateCompanionBuilder,
          (Collection, $$CollectionsTableReferences),
          Collection,
          PrefetchHooks Function({bool vocabularyEntriesRefs})
        > {
  $$CollectionsTableTableManager(_$PikoDatabase db, $CollectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> targetLanguage = const Value.absent(),
                Value<String> nativeLanguage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion(
                id: id,
                name: name,
                targetLanguage: targetLanguage,
                nativeLanguage: nativeLanguage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String targetLanguage,
                required String nativeLanguage,
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion.insert(
                id: id,
                name: name,
                targetLanguage: targetLanguage,
                nativeLanguage: nativeLanguage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CollectionsTable, Collection>(table),
                  $$CollectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vocabularyEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (vocabularyEntriesRefs) db.vocabularyEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (vocabularyEntriesRefs)
                    await $_getPrefetchedData<
                      Collection,
                      $CollectionsTable,
                      VocabularyEntry
                    >(
                      currentTable: table,
                      referencedTable: $$CollectionsTableReferences
                          ._vocabularyEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CollectionsTableReferences(
                            db,
                            table,
                            p0,
                          ).vocabularyEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.collectionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $CollectionsTable,
      Collection,
      $$CollectionsTableFilterComposer,
      $$CollectionsTableOrderingComposer,
      $$CollectionsTableAnnotationComposer,
      $$CollectionsTableCreateCompanionBuilder,
      $$CollectionsTableUpdateCompanionBuilder,
      (Collection, $$CollectionsTableReferences),
      Collection,
      PrefetchHooks Function({bool vocabularyEntriesRefs})
    >;
typedef $$VocabularyEntriesTableCreateCompanionBuilder =
    VocabularyEntriesCompanion Function({
      required String id,
      required String collectionId,
      required String targetText,
      required String nativeText,
      required String targetKey,
      required String nativeKey,
      Value<int> rowid,
    });
typedef $$VocabularyEntriesTableUpdateCompanionBuilder =
    VocabularyEntriesCompanion Function({
      Value<String> id,
      Value<String> collectionId,
      Value<String> targetText,
      Value<String> nativeText,
      Value<String> targetKey,
      Value<String> nativeKey,
      Value<int> rowid,
    });

final class $$VocabularyEntriesTableReferences
    extends
        BaseReferences<
          _$PikoDatabase,
          $VocabularyEntriesTable,
          VocabularyEntry
        > {
  $$VocabularyEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CollectionsTable _collectionIdTable(_$PikoDatabase db) => db
      .collections
      .createAlias('vocabulary_entries__collection_id__collections__id');

  $$CollectionsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<String>('collection_id')!;

    final manager = $$CollectionsTableTableManager(
      $_db,
      $_db.collections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LearningItemsTable, List<LearningItem>>
  _learningItemsRefsTable(_$PikoDatabase db) => MultiTypedResultKey.fromTable(
    db.learningItems,
    aliasName: 'vocabulary_entries__id__learning_items__entry_id',
  );

  $$LearningItemsTableProcessedTableManager get learningItemsRefs {
    final manager = $$LearningItemsTableTableManager(
      $_db,
      $_db.learningItems,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_learningItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VocabularyEntriesTableFilterComposer
    extends Composer<_$PikoDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetText => $composableBuilder(
    column: $table.targetText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nativeText => $composableBuilder(
    column: $table.nativeText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetKey => $composableBuilder(
    column: $table.targetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nativeKey => $composableBuilder(
    column: $table.nativeKey,
    builder: (column) => ColumnFilters(column),
  );

  $$CollectionsTableFilterComposer get collectionId {
    final $$CollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableFilterComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> learningItemsRefs(
    Expression<bool> Function($$LearningItemsTableFilterComposer f) f,
  ) {
    final $$LearningItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningItems,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningItemsTableFilterComposer(
            $db: $db,
            $table: $db.learningItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VocabularyEntriesTableOrderingComposer
    extends Composer<_$PikoDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetText => $composableBuilder(
    column: $table.targetText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nativeText => $composableBuilder(
    column: $table.nativeText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetKey => $composableBuilder(
    column: $table.targetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nativeKey => $composableBuilder(
    column: $table.nativeKey,
    builder: (column) => ColumnOrderings(column),
  );

  $$CollectionsTableOrderingComposer get collectionId {
    final $$CollectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableOrderingComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VocabularyEntriesTableAnnotationComposer
    extends Composer<_$PikoDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetText => $composableBuilder(
    column: $table.targetText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nativeText => $composableBuilder(
    column: $table.nativeText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetKey =>
      $composableBuilder(column: $table.targetKey, builder: (column) => column);

  GeneratedColumn<String> get nativeKey =>
      $composableBuilder(column: $table.nativeKey, builder: (column) => column);

  $$CollectionsTableAnnotationComposer get collectionId {
    final $$CollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> learningItemsRefs<T extends Object>(
    Expression<T> Function($$LearningItemsTableAnnotationComposer a) f,
  ) {
    final $$LearningItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningItems,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.learningItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VocabularyEntriesTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $VocabularyEntriesTable,
          VocabularyEntry,
          $$VocabularyEntriesTableFilterComposer,
          $$VocabularyEntriesTableOrderingComposer,
          $$VocabularyEntriesTableAnnotationComposer,
          $$VocabularyEntriesTableCreateCompanionBuilder,
          $$VocabularyEntriesTableUpdateCompanionBuilder,
          (VocabularyEntry, $$VocabularyEntriesTableReferences),
          VocabularyEntry,
          PrefetchHooks Function({bool collectionId, bool learningItemsRefs})
        > {
  $$VocabularyEntriesTableTableManager(
    _$PikoDatabase db,
    $VocabularyEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabularyEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VocabularyEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VocabularyEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> collectionId = const Value.absent(),
                Value<String> targetText = const Value.absent(),
                Value<String> nativeText = const Value.absent(),
                Value<String> targetKey = const Value.absent(),
                Value<String> nativeKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VocabularyEntriesCompanion(
                id: id,
                collectionId: collectionId,
                targetText: targetText,
                nativeText: nativeText,
                targetKey: targetKey,
                nativeKey: nativeKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String collectionId,
                required String targetText,
                required String nativeText,
                required String targetKey,
                required String nativeKey,
                Value<int> rowid = const Value.absent(),
              }) => VocabularyEntriesCompanion.insert(
                id: id,
                collectionId: collectionId,
                targetText: targetText,
                nativeText: nativeText,
                targetKey: targetKey,
                nativeKey: nativeKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VocabularyEntriesTable, VocabularyEntry>(table),
                  $$VocabularyEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({collectionId = false, learningItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (learningItemsRefs) db.learningItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (collectionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.collectionId,
                                    referencedTable:
                                        $$VocabularyEntriesTableReferences
                                            ._collectionIdTable(db),
                                    referencedColumn:
                                        $$VocabularyEntriesTableReferences
                                            ._collectionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (learningItemsRefs)
                        await $_getPrefetchedData<
                          VocabularyEntry,
                          $VocabularyEntriesTable,
                          LearningItem
                        >(
                          currentTable: table,
                          referencedTable: $$VocabularyEntriesTableReferences
                              ._learningItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VocabularyEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).learningItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$VocabularyEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $VocabularyEntriesTable,
      VocabularyEntry,
      $$VocabularyEntriesTableFilterComposer,
      $$VocabularyEntriesTableOrderingComposer,
      $$VocabularyEntriesTableAnnotationComposer,
      $$VocabularyEntriesTableCreateCompanionBuilder,
      $$VocabularyEntriesTableUpdateCompanionBuilder,
      (VocabularyEntry, $$VocabularyEntriesTableReferences),
      VocabularyEntry,
      PrefetchHooks Function({bool collectionId, bool learningItemsRefs})
    >;
typedef $$LearningItemsTableCreateCompanionBuilder =
    LearningItemsCompanion Function({
      Value<int> id,
      required String entryId,
      required String direction,
      required int formatVersion,
      required String cardJson,
    });
typedef $$LearningItemsTableUpdateCompanionBuilder =
    LearningItemsCompanion Function({
      Value<int> id,
      Value<String> entryId,
      Value<String> direction,
      Value<int> formatVersion,
      Value<String> cardJson,
    });

final class $$LearningItemsTableReferences
    extends BaseReferences<_$PikoDatabase, $LearningItemsTable, LearningItem> {
  $$LearningItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VocabularyEntriesTable _entryIdTable(_$PikoDatabase db) => db
      .vocabularyEntries
      .createAlias('learning_items__entry_id__vocabulary_entries__id');

  $$VocabularyEntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<String>('entry_id')!;

    final manager = $$VocabularyEntriesTableTableManager(
      $_db,
      $_db.vocabularyEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningItemsTableFilterComposer
    extends Composer<_$PikoDatabase, $LearningItemsTable> {
  $$LearningItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardJson => $composableBuilder(
    column: $table.cardJson,
    builder: (column) => ColumnFilters(column),
  );

  $$VocabularyEntriesTableFilterComposer get entryId {
    final $$VocabularyEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.vocabularyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabularyEntriesTableFilterComposer(
            $db: $db,
            $table: $db.vocabularyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningItemsTableOrderingComposer
    extends Composer<_$PikoDatabase, $LearningItemsTable> {
  $$LearningItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardJson => $composableBuilder(
    column: $table.cardJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$VocabularyEntriesTableOrderingComposer get entryId {
    final $$VocabularyEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.vocabularyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabularyEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.vocabularyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningItemsTableAnnotationComposer
    extends Composer<_$PikoDatabase, $LearningItemsTable> {
  $$LearningItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardJson =>
      $composableBuilder(column: $table.cardJson, builder: (column) => column);

  $$VocabularyEntriesTableAnnotationComposer get entryId {
    final $$VocabularyEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.entryId,
          referencedTable: $db.vocabularyEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VocabularyEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.vocabularyEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LearningItemsTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $LearningItemsTable,
          LearningItem,
          $$LearningItemsTableFilterComposer,
          $$LearningItemsTableOrderingComposer,
          $$LearningItemsTableAnnotationComposer,
          $$LearningItemsTableCreateCompanionBuilder,
          $$LearningItemsTableUpdateCompanionBuilder,
          (LearningItem, $$LearningItemsTableReferences),
          LearningItem,
          PrefetchHooks Function({bool entryId})
        > {
  $$LearningItemsTableTableManager(_$PikoDatabase db, $LearningItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<int> formatVersion = const Value.absent(),
                Value<String> cardJson = const Value.absent(),
              }) => LearningItemsCompanion(
                id: id,
                entryId: entryId,
                direction: direction,
                formatVersion: formatVersion,
                cardJson: cardJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entryId,
                required String direction,
                required int formatVersion,
                required String cardJson,
              }) => LearningItemsCompanion.insert(
                id: id,
                entryId: entryId,
                direction: direction,
                formatVersion: formatVersion,
                cardJson: cardJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningItemsTable, LearningItem>(table),
                  $$LearningItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable: $$LearningItemsTableReferences
                                    ._entryIdTable(db),
                                referencedColumn: $$LearningItemsTableReferences
                                    ._entryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $LearningItemsTable,
      LearningItem,
      $$LearningItemsTableFilterComposer,
      $$LearningItemsTableOrderingComposer,
      $$LearningItemsTableAnnotationComposer,
      $$LearningItemsTableCreateCompanionBuilder,
      $$LearningItemsTableUpdateCompanionBuilder,
      (LearningItem, $$LearningItemsTableReferences),
      LearningItem,
      PrefetchHooks Function({bool entryId})
    >;
typedef $$LearningIdentitySequenceTableCreateCompanionBuilder =
    LearningIdentitySequenceCompanion Function({
      Value<int> singleton,
      required int nextId,
    });
typedef $$LearningIdentitySequenceTableUpdateCompanionBuilder =
    LearningIdentitySequenceCompanion Function({
      Value<int> singleton,
      Value<int> nextId,
    });

class $$LearningIdentitySequenceTableFilterComposer
    extends Composer<_$PikoDatabase, $LearningIdentitySequenceTable> {
  $$LearningIdentitySequenceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextId => $composableBuilder(
    column: $table.nextId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearningIdentitySequenceTableOrderingComposer
    extends Composer<_$PikoDatabase, $LearningIdentitySequenceTable> {
  $$LearningIdentitySequenceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singleton => $composableBuilder(
    column: $table.singleton,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextId => $composableBuilder(
    column: $table.nextId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearningIdentitySequenceTableAnnotationComposer
    extends Composer<_$PikoDatabase, $LearningIdentitySequenceTable> {
  $$LearningIdentitySequenceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singleton =>
      $composableBuilder(column: $table.singleton, builder: (column) => column);

  GeneratedColumn<int> get nextId =>
      $composableBuilder(column: $table.nextId, builder: (column) => column);
}

class $$LearningIdentitySequenceTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $LearningIdentitySequenceTable,
          LearningIdentitySequenceData,
          $$LearningIdentitySequenceTableFilterComposer,
          $$LearningIdentitySequenceTableOrderingComposer,
          $$LearningIdentitySequenceTableAnnotationComposer,
          $$LearningIdentitySequenceTableCreateCompanionBuilder,
          $$LearningIdentitySequenceTableUpdateCompanionBuilder,
          (
            LearningIdentitySequenceData,
            BaseReferences<
              _$PikoDatabase,
              $LearningIdentitySequenceTable,
              LearningIdentitySequenceData
            >,
          ),
          LearningIdentitySequenceData,
          PrefetchHooks Function()
        > {
  $$LearningIdentitySequenceTableTableManager(
    _$PikoDatabase db,
    $LearningIdentitySequenceTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningIdentitySequenceTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LearningIdentitySequenceTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LearningIdentitySequenceTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                Value<int> nextId = const Value.absent(),
              }) => LearningIdentitySequenceCompanion(
                singleton: singleton,
                nextId: nextId,
              ),
          createCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                required int nextId,
              }) => LearningIdentitySequenceCompanion.insert(
                singleton: singleton,
                nextId: nextId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LearningIdentitySequenceTable,
                    LearningIdentitySequenceData
                  >(table),
                  BaseReferences<
                    _$PikoDatabase,
                    $LearningIdentitySequenceTable,
                    LearningIdentitySequenceData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearningIdentitySequenceTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $LearningIdentitySequenceTable,
      LearningIdentitySequenceData,
      $$LearningIdentitySequenceTableFilterComposer,
      $$LearningIdentitySequenceTableOrderingComposer,
      $$LearningIdentitySequenceTableAnnotationComposer,
      $$LearningIdentitySequenceTableCreateCompanionBuilder,
      $$LearningIdentitySequenceTableUpdateCompanionBuilder,
      (
        LearningIdentitySequenceData,
        BaseReferences<
          _$PikoDatabase,
          $LearningIdentitySequenceTable,
          LearningIdentitySequenceData
        >,
      ),
      LearningIdentitySequenceData,
      PrefetchHooks Function()
    >;

class $PikoDatabaseManager {
  final _$PikoDatabase _db;
  $PikoDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db, _db.collections);
  $$VocabularyEntriesTableTableManager get vocabularyEntries =>
      $$VocabularyEntriesTableTableManager(_db, _db.vocabularyEntries);
  $$LearningItemsTableTableManager get learningItems =>
      $$LearningItemsTableTableManager(_db, _db.learningItems);
  $$LearningIdentitySequenceTableTableManager get learningIdentitySequence =>
      $$LearningIdentitySequenceTableTableManager(
        _db,
        _db.learningIdentitySequence,
      );
}
