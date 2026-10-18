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
  static const VerificationMeta _targetLanguageNameMeta =
      const VerificationMeta('targetLanguageName');
  @override
  late final GeneratedColumn<String> targetLanguageName =
      GeneratedColumn<String>(
        'target_language_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nativeLanguageNameMeta =
      const VerificationMeta('nativeLanguageName');
  @override
  late final GeneratedColumn<String> nativeLanguageName =
      GeneratedColumn<String>(
        'native_language_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _automaticHintDefaultMeta =
      const VerificationMeta('automaticHintDefault');
  @override
  late final GeneratedColumn<bool> automaticHintDefault = GeneratedColumn<bool>(
    'automatic_hint_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("automatic_hint_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hintDefaultOfferHandledMeta =
      const VerificationMeta('hintDefaultOfferHandled');
  @override
  late final GeneratedColumn<bool> hintDefaultOfferHandled =
      GeneratedColumn<bool>(
        'hint_default_offer_handled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("hint_default_offer_handled" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    targetLanguage,
    nativeLanguage,
    targetLanguageName,
    nativeLanguageName,
    automaticHintDefault,
    hintDefaultOfferHandled,
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
    if (data.containsKey('target_language_name')) {
      context.handle(
        _targetLanguageNameMeta,
        targetLanguageName.isAcceptableOrUnknown(
          data['target_language_name']!,
          _targetLanguageNameMeta,
        ),
      );
    }
    if (data.containsKey('native_language_name')) {
      context.handle(
        _nativeLanguageNameMeta,
        nativeLanguageName.isAcceptableOrUnknown(
          data['native_language_name']!,
          _nativeLanguageNameMeta,
        ),
      );
    }
    if (data.containsKey('automatic_hint_default')) {
      context.handle(
        _automaticHintDefaultMeta,
        automaticHintDefault.isAcceptableOrUnknown(
          data['automatic_hint_default']!,
          _automaticHintDefaultMeta,
        ),
      );
    }
    if (data.containsKey('hint_default_offer_handled')) {
      context.handle(
        _hintDefaultOfferHandledMeta,
        hintDefaultOfferHandled.isAcceptableOrUnknown(
          data['hint_default_offer_handled']!,
          _hintDefaultOfferHandledMeta,
        ),
      );
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
      targetLanguageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_language_name'],
      ),
      nativeLanguageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}native_language_name'],
      ),
      automaticHintDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}automatic_hint_default'],
      )!,
      hintDefaultOfferHandled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hint_default_offer_handled'],
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
  final String? targetLanguageName;
  final String? nativeLanguageName;
  final bool automaticHintDefault;
  final bool hintDefaultOfferHandled;
  const Collection({
    required this.id,
    required this.name,
    required this.targetLanguage,
    required this.nativeLanguage,
    this.targetLanguageName,
    this.nativeLanguageName,
    required this.automaticHintDefault,
    required this.hintDefaultOfferHandled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['target_language'] = Variable<String>(targetLanguage);
    map['native_language'] = Variable<String>(nativeLanguage);
    if (!nullToAbsent || targetLanguageName != null) {
      map['target_language_name'] = Variable<String>(targetLanguageName);
    }
    if (!nullToAbsent || nativeLanguageName != null) {
      map['native_language_name'] = Variable<String>(nativeLanguageName);
    }
    map['automatic_hint_default'] = Variable<bool>(automaticHintDefault);
    map['hint_default_offer_handled'] = Variable<bool>(hintDefaultOfferHandled);
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      targetLanguage: Value(targetLanguage),
      nativeLanguage: Value(nativeLanguage),
      targetLanguageName: targetLanguageName == null && nullToAbsent
          ? const Value.absent()
          : Value(targetLanguageName),
      nativeLanguageName: nativeLanguageName == null && nullToAbsent
          ? const Value.absent()
          : Value(nativeLanguageName),
      automaticHintDefault: Value(automaticHintDefault),
      hintDefaultOfferHandled: Value(hintDefaultOfferHandled),
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
      targetLanguageName: serializer.fromJson<String?>(
        json['targetLanguageName'],
      ),
      nativeLanguageName: serializer.fromJson<String?>(
        json['nativeLanguageName'],
      ),
      automaticHintDefault: serializer.fromJson<bool>(
        json['automaticHintDefault'],
      ),
      hintDefaultOfferHandled: serializer.fromJson<bool>(
        json['hintDefaultOfferHandled'],
      ),
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
      'targetLanguageName': serializer.toJson<String?>(targetLanguageName),
      'nativeLanguageName': serializer.toJson<String?>(nativeLanguageName),
      'automaticHintDefault': serializer.toJson<bool>(automaticHintDefault),
      'hintDefaultOfferHandled': serializer.toJson<bool>(
        hintDefaultOfferHandled,
      ),
    };
  }

  Collection copyWith({
    String? id,
    String? name,
    String? targetLanguage,
    String? nativeLanguage,
    Value<String?> targetLanguageName = const Value.absent(),
    Value<String?> nativeLanguageName = const Value.absent(),
    bool? automaticHintDefault,
    bool? hintDefaultOfferHandled,
  }) => Collection(
    id: id ?? this.id,
    name: name ?? this.name,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    nativeLanguage: nativeLanguage ?? this.nativeLanguage,
    targetLanguageName: targetLanguageName.present
        ? targetLanguageName.value
        : this.targetLanguageName,
    nativeLanguageName: nativeLanguageName.present
        ? nativeLanguageName.value
        : this.nativeLanguageName,
    automaticHintDefault: automaticHintDefault ?? this.automaticHintDefault,
    hintDefaultOfferHandled:
        hintDefaultOfferHandled ?? this.hintDefaultOfferHandled,
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
      targetLanguageName: data.targetLanguageName.present
          ? data.targetLanguageName.value
          : this.targetLanguageName,
      nativeLanguageName: data.nativeLanguageName.present
          ? data.nativeLanguageName.value
          : this.nativeLanguageName,
      automaticHintDefault: data.automaticHintDefault.present
          ? data.automaticHintDefault.value
          : this.automaticHintDefault,
      hintDefaultOfferHandled: data.hintDefaultOfferHandled.present
          ? data.hintDefaultOfferHandled.value
          : this.hintDefaultOfferHandled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Collection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('targetLanguage: $targetLanguage, ')
          ..write('nativeLanguage: $nativeLanguage, ')
          ..write('targetLanguageName: $targetLanguageName, ')
          ..write('nativeLanguageName: $nativeLanguageName, ')
          ..write('automaticHintDefault: $automaticHintDefault, ')
          ..write('hintDefaultOfferHandled: $hintDefaultOfferHandled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    targetLanguage,
    nativeLanguage,
    targetLanguageName,
    nativeLanguageName,
    automaticHintDefault,
    hintDefaultOfferHandled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Collection &&
          other.id == this.id &&
          other.name == this.name &&
          other.targetLanguage == this.targetLanguage &&
          other.nativeLanguage == this.nativeLanguage &&
          other.targetLanguageName == this.targetLanguageName &&
          other.nativeLanguageName == this.nativeLanguageName &&
          other.automaticHintDefault == this.automaticHintDefault &&
          other.hintDefaultOfferHandled == this.hintDefaultOfferHandled);
}

class CollectionsCompanion extends UpdateCompanion<Collection> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> targetLanguage;
  final Value<String> nativeLanguage;
  final Value<String?> targetLanguageName;
  final Value<String?> nativeLanguageName;
  final Value<bool> automaticHintDefault;
  final Value<bool> hintDefaultOfferHandled;
  final Value<int> rowid;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.targetLanguage = const Value.absent(),
    this.nativeLanguage = const Value.absent(),
    this.targetLanguageName = const Value.absent(),
    this.nativeLanguageName = const Value.absent(),
    this.automaticHintDefault = const Value.absent(),
    this.hintDefaultOfferHandled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionsCompanion.insert({
    required String id,
    required String name,
    required String targetLanguage,
    required String nativeLanguage,
    this.targetLanguageName = const Value.absent(),
    this.nativeLanguageName = const Value.absent(),
    this.automaticHintDefault = const Value.absent(),
    this.hintDefaultOfferHandled = const Value.absent(),
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
    Expression<String>? targetLanguageName,
    Expression<String>? nativeLanguageName,
    Expression<bool>? automaticHintDefault,
    Expression<bool>? hintDefaultOfferHandled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (targetLanguage != null) 'target_language': targetLanguage,
      if (nativeLanguage != null) 'native_language': nativeLanguage,
      if (targetLanguageName != null)
        'target_language_name': targetLanguageName,
      if (nativeLanguageName != null)
        'native_language_name': nativeLanguageName,
      if (automaticHintDefault != null)
        'automatic_hint_default': automaticHintDefault,
      if (hintDefaultOfferHandled != null)
        'hint_default_offer_handled': hintDefaultOfferHandled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? targetLanguage,
    Value<String>? nativeLanguage,
    Value<String?>? targetLanguageName,
    Value<String?>? nativeLanguageName,
    Value<bool>? automaticHintDefault,
    Value<bool>? hintDefaultOfferHandled,
    Value<int>? rowid,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      targetLanguageName: targetLanguageName ?? this.targetLanguageName,
      nativeLanguageName: nativeLanguageName ?? this.nativeLanguageName,
      automaticHintDefault: automaticHintDefault ?? this.automaticHintDefault,
      hintDefaultOfferHandled:
          hintDefaultOfferHandled ?? this.hintDefaultOfferHandled,
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
    if (targetLanguageName.present) {
      map['target_language_name'] = Variable<String>(targetLanguageName.value);
    }
    if (nativeLanguageName.present) {
      map['native_language_name'] = Variable<String>(nativeLanguageName.value);
    }
    if (automaticHintDefault.present) {
      map['automatic_hint_default'] = Variable<bool>(
        automaticHintDefault.value,
      );
    }
    if (hintDefaultOfferHandled.present) {
      map['hint_default_offer_handled'] = Variable<bool>(
        hintDefaultOfferHandled.value,
      );
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
          ..write('targetLanguageName: $targetLanguageName, ')
          ..write('nativeLanguageName: $nativeLanguageName, ')
          ..write('automaticHintDefault: $automaticHintDefault, ')
          ..write('hintDefaultOfferHandled: $hintDefaultOfferHandled, ')
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
  static const VerificationMeta _hintKeyMeta = const VerificationMeta(
    'hintKey',
  );
  @override
  late final GeneratedColumn<String> hintKey = GeneratedColumn<String>(
    'hint_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _exampleTargetTextMeta = const VerificationMeta(
    'exampleTargetText',
  );
  @override
  late final GeneratedColumn<String>
  exampleTargetText = GeneratedColumn<String>(
    'example_target_text',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      'example_target_text IS NULL OR length(example_target_text) BETWEEN 1 AND 1000',
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exampleNativeTextMeta = const VerificationMeta(
    'exampleNativeText',
  );
  @override
  late final GeneratedColumn<String>
  exampleNativeText = GeneratedColumn<String>(
    'example_native_text',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      '(example_target_text IS NULL AND example_native_text IS NULL) OR '
      '(example_target_text IS NOT NULL AND example_native_text IS NOT NULL '
      'AND length(example_native_text) BETWEEN 1 AND 1000)',
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<String> addedAt = GeneratedColumn<String>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hintTextMeta = const VerificationMeta(
    'hintText',
  );
  @override
  late final GeneratedColumn<String> hintText = GeneratedColumn<String>(
    'hint_text',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      'hint_text IS NULL OR length(hint_text) BETWEEN 1 AND 2000',
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hintVisibilityMeta = const VerificationMeta(
    'hintVisibility',
  );
  @override
  late final GeneratedColumn<String> hintVisibility = GeneratedColumn<String>(
    'hint_visibility',
    aliasedName,
    false,
    check: () =>
        const CustomExpression<bool>("hint_visibility IN ('always', 'hidden')"),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('always'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collectionId,
    targetText,
    nativeText,
    targetKey,
    nativeKey,
    hintKey,
    active,
    exampleTargetText,
    exampleNativeText,
    addedAt,
    hintText,
    hintVisibility,
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
    if (data.containsKey('hint_key')) {
      context.handle(
        _hintKeyMeta,
        hintKey.isAcceptableOrUnknown(data['hint_key']!, _hintKeyMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('example_target_text')) {
      context.handle(
        _exampleTargetTextMeta,
        exampleTargetText.isAcceptableOrUnknown(
          data['example_target_text']!,
          _exampleTargetTextMeta,
        ),
      );
    }
    if (data.containsKey('example_native_text')) {
      context.handle(
        _exampleNativeTextMeta,
        exampleNativeText.isAcceptableOrUnknown(
          data['example_native_text']!,
          _exampleNativeTextMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('hint_text')) {
      context.handle(
        _hintTextMeta,
        hintText.isAcceptableOrUnknown(data['hint_text']!, _hintTextMeta),
      );
    }
    if (data.containsKey('hint_visibility')) {
      context.handle(
        _hintVisibilityMeta,
        hintVisibility.isAcceptableOrUnknown(
          data['hint_visibility']!,
          _hintVisibilityMeta,
        ),
      );
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
      hintKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hint_key'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      exampleTargetText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_target_text'],
      ),
      exampleNativeText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_native_text'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_at'],
      ),
      hintText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hint_text'],
      ),
      hintVisibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hint_visibility'],
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
  final String hintKey;
  final bool active;
  final String? exampleTargetText;
  final String? exampleNativeText;
  final String? addedAt;
  final String? hintText;
  final String hintVisibility;
  const VocabularyEntry({
    required this.id,
    required this.collectionId,
    required this.targetText,
    required this.nativeText,
    required this.targetKey,
    required this.nativeKey,
    required this.hintKey,
    required this.active,
    this.exampleTargetText,
    this.exampleNativeText,
    this.addedAt,
    this.hintText,
    required this.hintVisibility,
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
    map['hint_key'] = Variable<String>(hintKey);
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || exampleTargetText != null) {
      map['example_target_text'] = Variable<String>(exampleTargetText);
    }
    if (!nullToAbsent || exampleNativeText != null) {
      map['example_native_text'] = Variable<String>(exampleNativeText);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<String>(addedAt);
    }
    if (!nullToAbsent || hintText != null) {
      map['hint_text'] = Variable<String>(hintText);
    }
    map['hint_visibility'] = Variable<String>(hintVisibility);
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
      hintKey: Value(hintKey),
      active: Value(active),
      exampleTargetText: exampleTargetText == null && nullToAbsent
          ? const Value.absent()
          : Value(exampleTargetText),
      exampleNativeText: exampleNativeText == null && nullToAbsent
          ? const Value.absent()
          : Value(exampleNativeText),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
      hintText: hintText == null && nullToAbsent
          ? const Value.absent()
          : Value(hintText),
      hintVisibility: Value(hintVisibility),
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
      hintKey: serializer.fromJson<String>(json['hintKey']),
      active: serializer.fromJson<bool>(json['active']),
      exampleTargetText: serializer.fromJson<String?>(
        json['exampleTargetText'],
      ),
      exampleNativeText: serializer.fromJson<String?>(
        json['exampleNativeText'],
      ),
      addedAt: serializer.fromJson<String?>(json['addedAt']),
      hintText: serializer.fromJson<String?>(json['hintText']),
      hintVisibility: serializer.fromJson<String>(json['hintVisibility']),
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
      'hintKey': serializer.toJson<String>(hintKey),
      'active': serializer.toJson<bool>(active),
      'exampleTargetText': serializer.toJson<String?>(exampleTargetText),
      'exampleNativeText': serializer.toJson<String?>(exampleNativeText),
      'addedAt': serializer.toJson<String?>(addedAt),
      'hintText': serializer.toJson<String?>(hintText),
      'hintVisibility': serializer.toJson<String>(hintVisibility),
    };
  }

  VocabularyEntry copyWith({
    String? id,
    String? collectionId,
    String? targetText,
    String? nativeText,
    String? targetKey,
    String? nativeKey,
    String? hintKey,
    bool? active,
    Value<String?> exampleTargetText = const Value.absent(),
    Value<String?> exampleNativeText = const Value.absent(),
    Value<String?> addedAt = const Value.absent(),
    Value<String?> hintText = const Value.absent(),
    String? hintVisibility,
  }) => VocabularyEntry(
    id: id ?? this.id,
    collectionId: collectionId ?? this.collectionId,
    targetText: targetText ?? this.targetText,
    nativeText: nativeText ?? this.nativeText,
    targetKey: targetKey ?? this.targetKey,
    nativeKey: nativeKey ?? this.nativeKey,
    hintKey: hintKey ?? this.hintKey,
    active: active ?? this.active,
    exampleTargetText: exampleTargetText.present
        ? exampleTargetText.value
        : this.exampleTargetText,
    exampleNativeText: exampleNativeText.present
        ? exampleNativeText.value
        : this.exampleNativeText,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
    hintText: hintText.present ? hintText.value : this.hintText,
    hintVisibility: hintVisibility ?? this.hintVisibility,
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
      hintKey: data.hintKey.present ? data.hintKey.value : this.hintKey,
      active: data.active.present ? data.active.value : this.active,
      exampleTargetText: data.exampleTargetText.present
          ? data.exampleTargetText.value
          : this.exampleTargetText,
      exampleNativeText: data.exampleNativeText.present
          ? data.exampleNativeText.value
          : this.exampleNativeText,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      hintText: data.hintText.present ? data.hintText.value : this.hintText,
      hintVisibility: data.hintVisibility.present
          ? data.hintVisibility.value
          : this.hintVisibility,
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
          ..write('nativeKey: $nativeKey, ')
          ..write('hintKey: $hintKey, ')
          ..write('active: $active, ')
          ..write('exampleTargetText: $exampleTargetText, ')
          ..write('exampleNativeText: $exampleNativeText, ')
          ..write('addedAt: $addedAt, ')
          ..write('hintText: $hintText, ')
          ..write('hintVisibility: $hintVisibility')
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
    hintKey,
    active,
    exampleTargetText,
    exampleNativeText,
    addedAt,
    hintText,
    hintVisibility,
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
          other.nativeKey == this.nativeKey &&
          other.hintKey == this.hintKey &&
          other.active == this.active &&
          other.exampleTargetText == this.exampleTargetText &&
          other.exampleNativeText == this.exampleNativeText &&
          other.addedAt == this.addedAt &&
          other.hintText == this.hintText &&
          other.hintVisibility == this.hintVisibility);
}

class VocabularyEntriesCompanion extends UpdateCompanion<VocabularyEntry> {
  final Value<String> id;
  final Value<String> collectionId;
  final Value<String> targetText;
  final Value<String> nativeText;
  final Value<String> targetKey;
  final Value<String> nativeKey;
  final Value<String> hintKey;
  final Value<bool> active;
  final Value<String?> exampleTargetText;
  final Value<String?> exampleNativeText;
  final Value<String?> addedAt;
  final Value<String?> hintText;
  final Value<String> hintVisibility;
  final Value<int> rowid;
  const VocabularyEntriesCompanion({
    this.id = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.targetText = const Value.absent(),
    this.nativeText = const Value.absent(),
    this.targetKey = const Value.absent(),
    this.nativeKey = const Value.absent(),
    this.hintKey = const Value.absent(),
    this.active = const Value.absent(),
    this.exampleTargetText = const Value.absent(),
    this.exampleNativeText = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.hintText = const Value.absent(),
    this.hintVisibility = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VocabularyEntriesCompanion.insert({
    required String id,
    required String collectionId,
    required String targetText,
    required String nativeText,
    required String targetKey,
    required String nativeKey,
    this.hintKey = const Value.absent(),
    this.active = const Value.absent(),
    this.exampleTargetText = const Value.absent(),
    this.exampleNativeText = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.hintText = const Value.absent(),
    this.hintVisibility = const Value.absent(),
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
    Expression<String>? hintKey,
    Expression<bool>? active,
    Expression<String>? exampleTargetText,
    Expression<String>? exampleNativeText,
    Expression<String>? addedAt,
    Expression<String>? hintText,
    Expression<String>? hintVisibility,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collectionId != null) 'collection_id': collectionId,
      if (targetText != null) 'target_text': targetText,
      if (nativeText != null) 'native_text': nativeText,
      if (targetKey != null) 'target_key': targetKey,
      if (nativeKey != null) 'native_key': nativeKey,
      if (hintKey != null) 'hint_key': hintKey,
      if (active != null) 'active': active,
      if (exampleTargetText != null) 'example_target_text': exampleTargetText,
      if (exampleNativeText != null) 'example_native_text': exampleNativeText,
      if (addedAt != null) 'added_at': addedAt,
      if (hintText != null) 'hint_text': hintText,
      if (hintVisibility != null) 'hint_visibility': hintVisibility,
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
    Value<String>? hintKey,
    Value<bool>? active,
    Value<String?>? exampleTargetText,
    Value<String?>? exampleNativeText,
    Value<String?>? addedAt,
    Value<String?>? hintText,
    Value<String>? hintVisibility,
    Value<int>? rowid,
  }) {
    return VocabularyEntriesCompanion(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      targetText: targetText ?? this.targetText,
      nativeText: nativeText ?? this.nativeText,
      targetKey: targetKey ?? this.targetKey,
      nativeKey: nativeKey ?? this.nativeKey,
      hintKey: hintKey ?? this.hintKey,
      active: active ?? this.active,
      exampleTargetText: exampleTargetText ?? this.exampleTargetText,
      exampleNativeText: exampleNativeText ?? this.exampleNativeText,
      addedAt: addedAt ?? this.addedAt,
      hintText: hintText ?? this.hintText,
      hintVisibility: hintVisibility ?? this.hintVisibility,
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
    if (hintKey.present) {
      map['hint_key'] = Variable<String>(hintKey.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (exampleTargetText.present) {
      map['example_target_text'] = Variable<String>(exampleTargetText.value);
    }
    if (exampleNativeText.present) {
      map['example_native_text'] = Variable<String>(exampleNativeText.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<String>(addedAt.value);
    }
    if (hintText.present) {
      map['hint_text'] = Variable<String>(hintText.value);
    }
    if (hintVisibility.present) {
      map['hint_visibility'] = Variable<String>(hintVisibility.value);
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
          ..write('hintKey: $hintKey, ')
          ..write('active: $active, ')
          ..write('exampleTargetText: $exampleTargetText, ')
          ..write('exampleNativeText: $exampleNativeText, ')
          ..write('addedAt: $addedAt, ')
          ..write('hintText: $hintText, ')
          ..write('hintVisibility: $hintVisibility, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VocabularyExamplesTable extends VocabularyExamples
    with TableInfo<$VocabularyExamplesTable, VocabularyExample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabularyExamplesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('position >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTextMeta = const VerificationMeta(
    'targetText',
  );
  @override
  late final GeneratedColumn<String> targetText = GeneratedColumn<String>(
    'target_text',
    aliasedName,
    false,
    check: () =>
        const CustomExpression<bool>('length(target_text) BETWEEN 1 AND 1000'),
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
    check: () =>
        const CustomExpression<bool>('length(native_text) BETWEEN 1 AND 1000'),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    position,
    targetText,
    nativeText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocabulary_examples';
  @override
  VerificationContext validateIntegrity(
    Insertable<VocabularyExample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, position};
  @override
  VocabularyExample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabularyExample(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      targetText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_text'],
      )!,
      nativeText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}native_text'],
      )!,
    );
  }

  @override
  $VocabularyExamplesTable createAlias(String alias) {
    return $VocabularyExamplesTable(attachedDatabase, alias);
  }
}

class VocabularyExample extends DataClass
    implements Insertable<VocabularyExample> {
  final String entryId;
  final int position;
  final String targetText;
  final String nativeText;
  const VocabularyExample({
    required this.entryId,
    required this.position,
    required this.targetText,
    required this.nativeText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['position'] = Variable<int>(position);
    map['target_text'] = Variable<String>(targetText);
    map['native_text'] = Variable<String>(nativeText);
    return map;
  }

  VocabularyExamplesCompanion toCompanion(bool nullToAbsent) {
    return VocabularyExamplesCompanion(
      entryId: Value(entryId),
      position: Value(position),
      targetText: Value(targetText),
      nativeText: Value(nativeText),
    );
  }

  factory VocabularyExample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabularyExample(
      entryId: serializer.fromJson<String>(json['entryId']),
      position: serializer.fromJson<int>(json['position']),
      targetText: serializer.fromJson<String>(json['targetText']),
      nativeText: serializer.fromJson<String>(json['nativeText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'position': serializer.toJson<int>(position),
      'targetText': serializer.toJson<String>(targetText),
      'nativeText': serializer.toJson<String>(nativeText),
    };
  }

  VocabularyExample copyWith({
    String? entryId,
    int? position,
    String? targetText,
    String? nativeText,
  }) => VocabularyExample(
    entryId: entryId ?? this.entryId,
    position: position ?? this.position,
    targetText: targetText ?? this.targetText,
    nativeText: nativeText ?? this.nativeText,
  );
  VocabularyExample copyWithCompanion(VocabularyExamplesCompanion data) {
    return VocabularyExample(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      position: data.position.present ? data.position.value : this.position,
      targetText: data.targetText.present
          ? data.targetText.value
          : this.targetText,
      nativeText: data.nativeText.present
          ? data.nativeText.value
          : this.nativeText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyExample(')
          ..write('entryId: $entryId, ')
          ..write('position: $position, ')
          ..write('targetText: $targetText, ')
          ..write('nativeText: $nativeText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryId, position, targetText, nativeText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabularyExample &&
          other.entryId == this.entryId &&
          other.position == this.position &&
          other.targetText == this.targetText &&
          other.nativeText == this.nativeText);
}

class VocabularyExamplesCompanion extends UpdateCompanion<VocabularyExample> {
  final Value<String> entryId;
  final Value<int> position;
  final Value<String> targetText;
  final Value<String> nativeText;
  final Value<int> rowid;
  const VocabularyExamplesCompanion({
    this.entryId = const Value.absent(),
    this.position = const Value.absent(),
    this.targetText = const Value.absent(),
    this.nativeText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VocabularyExamplesCompanion.insert({
    required String entryId,
    required int position,
    required String targetText,
    required String nativeText,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       position = Value(position),
       targetText = Value(targetText),
       nativeText = Value(nativeText);
  static Insertable<VocabularyExample> custom({
    Expression<String>? entryId,
    Expression<int>? position,
    Expression<String>? targetText,
    Expression<String>? nativeText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (position != null) 'position': position,
      if (targetText != null) 'target_text': targetText,
      if (nativeText != null) 'native_text': nativeText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VocabularyExamplesCompanion copyWith({
    Value<String>? entryId,
    Value<int>? position,
    Value<String>? targetText,
    Value<String>? nativeText,
    Value<int>? rowid,
  }) {
    return VocabularyExamplesCompanion(
      entryId: entryId ?? this.entryId,
      position: position ?? this.position,
      targetText: targetText ?? this.targetText,
      nativeText: nativeText ?? this.nativeText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (targetText.present) {
      map['target_text'] = Variable<String>(targetText.value);
    }
    if (nativeText.present) {
      map['native_text'] = Variable<String>(nativeText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyExamplesCompanion(')
          ..write('entryId: $entryId, ')
          ..write('position: $position, ')
          ..write('targetText: $targetText, ')
          ..write('nativeText: $nativeText, ')
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
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('generation >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reviewRevisionMeta = const VerificationMeta(
    'reviewRevision',
  );
  @override
  late final GeneratedColumn<int> reviewRevision = GeneratedColumn<int>(
    'review_revision',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('review_revision >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _speedCompletedMeta = const VerificationMeta(
    'speedCompleted',
  );
  @override
  late final GeneratedColumn<bool> speedCompleted = GeneratedColumn<bool>(
    'speed_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("speed_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entryId,
    direction,
    formatVersion,
    cardJson,
    generation,
    reviewRevision,
    speedCompleted,
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
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    }
    if (data.containsKey('review_revision')) {
      context.handle(
        _reviewRevisionMeta,
        reviewRevision.isAcceptableOrUnknown(
          data['review_revision']!,
          _reviewRevisionMeta,
        ),
      );
    }
    if (data.containsKey('speed_completed')) {
      context.handle(
        _speedCompletedMeta,
        speedCompleted.isAcceptableOrUnknown(
          data['speed_completed']!,
          _speedCompletedMeta,
        ),
      );
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
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
      reviewRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}review_revision'],
      )!,
      speedCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}speed_completed'],
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
  final int generation;
  final int reviewRevision;
  final bool speedCompleted;
  const LearningItem({
    required this.id,
    required this.entryId,
    required this.direction,
    required this.formatVersion,
    required this.cardJson,
    required this.generation,
    required this.reviewRevision,
    required this.speedCompleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entry_id'] = Variable<String>(entryId);
    map['direction'] = Variable<String>(direction);
    map['format_version'] = Variable<int>(formatVersion);
    map['card_json'] = Variable<String>(cardJson);
    map['generation'] = Variable<int>(generation);
    map['review_revision'] = Variable<int>(reviewRevision);
    map['speed_completed'] = Variable<bool>(speedCompleted);
    return map;
  }

  LearningItemsCompanion toCompanion(bool nullToAbsent) {
    return LearningItemsCompanion(
      id: Value(id),
      entryId: Value(entryId),
      direction: Value(direction),
      formatVersion: Value(formatVersion),
      cardJson: Value(cardJson),
      generation: Value(generation),
      reviewRevision: Value(reviewRevision),
      speedCompleted: Value(speedCompleted),
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
      generation: serializer.fromJson<int>(json['generation']),
      reviewRevision: serializer.fromJson<int>(json['reviewRevision']),
      speedCompleted: serializer.fromJson<bool>(json['speedCompleted']),
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
      'generation': serializer.toJson<int>(generation),
      'reviewRevision': serializer.toJson<int>(reviewRevision),
      'speedCompleted': serializer.toJson<bool>(speedCompleted),
    };
  }

  LearningItem copyWith({
    int? id,
    String? entryId,
    String? direction,
    int? formatVersion,
    String? cardJson,
    int? generation,
    int? reviewRevision,
    bool? speedCompleted,
  }) => LearningItem(
    id: id ?? this.id,
    entryId: entryId ?? this.entryId,
    direction: direction ?? this.direction,
    formatVersion: formatVersion ?? this.formatVersion,
    cardJson: cardJson ?? this.cardJson,
    generation: generation ?? this.generation,
    reviewRevision: reviewRevision ?? this.reviewRevision,
    speedCompleted: speedCompleted ?? this.speedCompleted,
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
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      reviewRevision: data.reviewRevision.present
          ? data.reviewRevision.value
          : this.reviewRevision,
      speedCompleted: data.speedCompleted.present
          ? data.speedCompleted.value
          : this.speedCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningItem(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('direction: $direction, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('cardJson: $cardJson, ')
          ..write('generation: $generation, ')
          ..write('reviewRevision: $reviewRevision, ')
          ..write('speedCompleted: $speedCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entryId,
    direction,
    formatVersion,
    cardJson,
    generation,
    reviewRevision,
    speedCompleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningItem &&
          other.id == this.id &&
          other.entryId == this.entryId &&
          other.direction == this.direction &&
          other.formatVersion == this.formatVersion &&
          other.cardJson == this.cardJson &&
          other.generation == this.generation &&
          other.reviewRevision == this.reviewRevision &&
          other.speedCompleted == this.speedCompleted);
}

class LearningItemsCompanion extends UpdateCompanion<LearningItem> {
  final Value<int> id;
  final Value<String> entryId;
  final Value<String> direction;
  final Value<int> formatVersion;
  final Value<String> cardJson;
  final Value<int> generation;
  final Value<int> reviewRevision;
  final Value<bool> speedCompleted;
  const LearningItemsCompanion({
    this.id = const Value.absent(),
    this.entryId = const Value.absent(),
    this.direction = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.cardJson = const Value.absent(),
    this.generation = const Value.absent(),
    this.reviewRevision = const Value.absent(),
    this.speedCompleted = const Value.absent(),
  });
  LearningItemsCompanion.insert({
    this.id = const Value.absent(),
    required String entryId,
    required String direction,
    required int formatVersion,
    required String cardJson,
    this.generation = const Value.absent(),
    this.reviewRevision = const Value.absent(),
    this.speedCompleted = const Value.absent(),
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
    Expression<int>? generation,
    Expression<int>? reviewRevision,
    Expression<bool>? speedCompleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      if (direction != null) 'direction': direction,
      if (formatVersion != null) 'format_version': formatVersion,
      if (cardJson != null) 'card_json': cardJson,
      if (generation != null) 'generation': generation,
      if (reviewRevision != null) 'review_revision': reviewRevision,
      if (speedCompleted != null) 'speed_completed': speedCompleted,
    });
  }

  LearningItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? entryId,
    Value<String>? direction,
    Value<int>? formatVersion,
    Value<String>? cardJson,
    Value<int>? generation,
    Value<int>? reviewRevision,
    Value<bool>? speedCompleted,
  }) {
    return LearningItemsCompanion(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      direction: direction ?? this.direction,
      formatVersion: formatVersion ?? this.formatVersion,
      cardJson: cardJson ?? this.cardJson,
      generation: generation ?? this.generation,
      reviewRevision: reviewRevision ?? this.reviewRevision,
      speedCompleted: speedCompleted ?? this.speedCompleted,
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
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (reviewRevision.present) {
      map['review_revision'] = Variable<int>(reviewRevision.value);
    }
    if (speedCompleted.present) {
      map['speed_completed'] = Variable<bool>(speedCompleted.value);
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
          ..write('cardJson: $cardJson, ')
          ..write('generation: $generation, ')
          ..write('reviewRevision: $reviewRevision, ')
          ..write('speedCompleted: $speedCompleted')
          ..write(')'))
        .toString();
  }
}

class $RegularReviewsTable extends RegularReviews
    with TableInfo<$RegularReviewsTable, RegularReview> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegularReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<String> reviewedAt = GeneratedColumn<String>(
    'reviewed_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    generation,
    reviewedAt,
    rating,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'regular_reviews';
  @override
  VerificationContext validateIntegrity(
    Insertable<RegularReview> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    } else if (isInserting) {
      context.missing(_generationMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RegularReview map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegularReview(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewed_at'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating'],
      )!,
    );
  }

  @override
  $RegularReviewsTable createAlias(String alias) {
    return $RegularReviewsTable(attachedDatabase, alias);
  }
}

class RegularReview extends DataClass implements Insertable<RegularReview> {
  final String id;
  final int itemId;
  final int generation;

  /// ISO UTC text retains subsecond precision independent of Drift date mapping.
  final String reviewedAt;
  final String rating;
  const RegularReview({
    required this.id,
    required this.itemId,
    required this.generation,
    required this.reviewedAt,
    required this.rating,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<int>(itemId);
    map['generation'] = Variable<int>(generation);
    map['reviewed_at'] = Variable<String>(reviewedAt);
    map['rating'] = Variable<String>(rating);
    return map;
  }

  RegularReviewsCompanion toCompanion(bool nullToAbsent) {
    return RegularReviewsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      generation: Value(generation),
      reviewedAt: Value(reviewedAt),
      rating: Value(rating),
    );
  }

  factory RegularReview.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegularReview(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<int>(json['itemId']),
      generation: serializer.fromJson<int>(json['generation']),
      reviewedAt: serializer.fromJson<String>(json['reviewedAt']),
      rating: serializer.fromJson<String>(json['rating']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<int>(itemId),
      'generation': serializer.toJson<int>(generation),
      'reviewedAt': serializer.toJson<String>(reviewedAt),
      'rating': serializer.toJson<String>(rating),
    };
  }

  RegularReview copyWith({
    String? id,
    int? itemId,
    int? generation,
    String? reviewedAt,
    String? rating,
  }) => RegularReview(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    generation: generation ?? this.generation,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    rating: rating ?? this.rating,
  );
  RegularReview copyWithCompanion(RegularReviewsCompanion data) {
    return RegularReview(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
      rating: data.rating.present ? data.rating.value : this.rating,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegularReview(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('generation: $generation, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rating: $rating')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, generation, reviewedAt, rating);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegularReview &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.generation == this.generation &&
          other.reviewedAt == this.reviewedAt &&
          other.rating == this.rating);
}

class RegularReviewsCompanion extends UpdateCompanion<RegularReview> {
  final Value<String> id;
  final Value<int> itemId;
  final Value<int> generation;
  final Value<String> reviewedAt;
  final Value<String> rating;
  final Value<int> rowid;
  const RegularReviewsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.generation = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.rating = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RegularReviewsCompanion.insert({
    required String id,
    required int itemId,
    required int generation,
    required String reviewedAt,
    required String rating,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       generation = Value(generation),
       reviewedAt = Value(reviewedAt),
       rating = Value(rating);
  static Insertable<RegularReview> custom({
    Expression<String>? id,
    Expression<int>? itemId,
    Expression<int>? generation,
    Expression<String>? reviewedAt,
    Expression<String>? rating,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (generation != null) 'generation': generation,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (rating != null) 'rating': rating,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RegularReviewsCompanion copyWith({
    Value<String>? id,
    Value<int>? itemId,
    Value<int>? generation,
    Value<String>? reviewedAt,
    Value<String>? rating,
    Value<int>? rowid,
  }) {
    return RegularReviewsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      generation: generation ?? this.generation,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rating: rating ?? this.rating,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<String>(reviewedAt.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegularReviewsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('generation: $generation, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rating: $rating, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RetryObligationsTable extends RetryObligations
    with TableInfo<$RetryObligationsTable, StoredRetryObligation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RetryObligationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _originReviewIdMeta = const VerificationMeta(
    'originReviewId',
  );
  @override
  late final GeneratedColumn<String> originReviewId = GeneratedColumn<String>(
    'origin_review_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES regular_reviews (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<String> expiresAt = GeneratedColumn<String>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _waitEligibleAtMeta = const VerificationMeta(
    'waitEligibleAt',
  );
  @override
  late final GeneratedColumn<String> waitEligibleAt = GeneratedColumn<String>(
    'wait_eligible_at',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      "wait_eligible_at IS NULL OR substr(wait_eligible_at, -1) = 'Z'",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCountMeta = const VerificationMeta(
    'errorCount',
  );
  @override
  late final GeneratedColumn<int> errorCount = GeneratedColumn<int>(
    'error_count',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('error_count >= 1'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _dueOrdinalMeta = const VerificationMeta(
    'dueOrdinal',
  );
  @override
  late final GeneratedColumn<int> dueOrdinal = GeneratedColumn<int>(
    'due_ordinal',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('due_ordinal >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    generation,
    revision,
    originReviewId,
    createdAt,
    expiresAt,
    waitEligibleAt,
    errorCount,
    dueOrdinal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'retry_obligations';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredRetryObligation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    } else if (isInserting) {
      context.missing(_generationMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('origin_review_id')) {
      context.handle(
        _originReviewIdMeta,
        originReviewId.isAcceptableOrUnknown(
          data['origin_review_id']!,
          _originReviewIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originReviewIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('wait_eligible_at')) {
      context.handle(
        _waitEligibleAtMeta,
        waitEligibleAt.isAcceptableOrUnknown(
          data['wait_eligible_at']!,
          _waitEligibleAtMeta,
        ),
      );
    }
    if (data.containsKey('error_count')) {
      context.handle(
        _errorCountMeta,
        errorCount.isAcceptableOrUnknown(data['error_count']!, _errorCountMeta),
      );
    }
    if (data.containsKey('due_ordinal')) {
      context.handle(
        _dueOrdinalMeta,
        dueOrdinal.isAcceptableOrUnknown(data['due_ordinal']!, _dueOrdinalMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredRetryObligation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredRetryObligation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      originReviewId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_review_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expires_at'],
      )!,
      waitEligibleAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wait_eligible_at'],
      ),
      errorCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}error_count'],
      )!,
      dueOrdinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_ordinal'],
      )!,
    );
  }

  @override
  $RetryObligationsTable createAlias(String alias) {
    return $RetryObligationsTable(attachedDatabase, alias);
  }
}

class StoredRetryObligation extends DataClass
    implements Insertable<StoredRetryObligation> {
  final String id;
  final int itemId;
  final int generation;
  final int revision;
  final String originReviewId;
  final String createdAt;
  final String expiresAt;
  final String? waitEligibleAt;
  final int errorCount;
  final int dueOrdinal;
  const StoredRetryObligation({
    required this.id,
    required this.itemId,
    required this.generation,
    required this.revision,
    required this.originReviewId,
    required this.createdAt,
    required this.expiresAt,
    this.waitEligibleAt,
    required this.errorCount,
    required this.dueOrdinal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<int>(itemId);
    map['generation'] = Variable<int>(generation);
    map['revision'] = Variable<int>(revision);
    map['origin_review_id'] = Variable<String>(originReviewId);
    map['created_at'] = Variable<String>(createdAt);
    map['expires_at'] = Variable<String>(expiresAt);
    if (!nullToAbsent || waitEligibleAt != null) {
      map['wait_eligible_at'] = Variable<String>(waitEligibleAt);
    }
    map['error_count'] = Variable<int>(errorCount);
    map['due_ordinal'] = Variable<int>(dueOrdinal);
    return map;
  }

  RetryObligationsCompanion toCompanion(bool nullToAbsent) {
    return RetryObligationsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      generation: Value(generation),
      revision: Value(revision),
      originReviewId: Value(originReviewId),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
      waitEligibleAt: waitEligibleAt == null && nullToAbsent
          ? const Value.absent()
          : Value(waitEligibleAt),
      errorCount: Value(errorCount),
      dueOrdinal: Value(dueOrdinal),
    );
  }

  factory StoredRetryObligation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredRetryObligation(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<int>(json['itemId']),
      generation: serializer.fromJson<int>(json['generation']),
      revision: serializer.fromJson<int>(json['revision']),
      originReviewId: serializer.fromJson<String>(json['originReviewId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      expiresAt: serializer.fromJson<String>(json['expiresAt']),
      waitEligibleAt: serializer.fromJson<String?>(json['waitEligibleAt']),
      errorCount: serializer.fromJson<int>(json['errorCount']),
      dueOrdinal: serializer.fromJson<int>(json['dueOrdinal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<int>(itemId),
      'generation': serializer.toJson<int>(generation),
      'revision': serializer.toJson<int>(revision),
      'originReviewId': serializer.toJson<String>(originReviewId),
      'createdAt': serializer.toJson<String>(createdAt),
      'expiresAt': serializer.toJson<String>(expiresAt),
      'waitEligibleAt': serializer.toJson<String?>(waitEligibleAt),
      'errorCount': serializer.toJson<int>(errorCount),
      'dueOrdinal': serializer.toJson<int>(dueOrdinal),
    };
  }

  StoredRetryObligation copyWith({
    String? id,
    int? itemId,
    int? generation,
    int? revision,
    String? originReviewId,
    String? createdAt,
    String? expiresAt,
    Value<String?> waitEligibleAt = const Value.absent(),
    int? errorCount,
    int? dueOrdinal,
  }) => StoredRetryObligation(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    generation: generation ?? this.generation,
    revision: revision ?? this.revision,
    originReviewId: originReviewId ?? this.originReviewId,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    waitEligibleAt: waitEligibleAt.present
        ? waitEligibleAt.value
        : this.waitEligibleAt,
    errorCount: errorCount ?? this.errorCount,
    dueOrdinal: dueOrdinal ?? this.dueOrdinal,
  );
  StoredRetryObligation copyWithCompanion(RetryObligationsCompanion data) {
    return StoredRetryObligation(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      revision: data.revision.present ? data.revision.value : this.revision,
      originReviewId: data.originReviewId.present
          ? data.originReviewId.value
          : this.originReviewId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      waitEligibleAt: data.waitEligibleAt.present
          ? data.waitEligibleAt.value
          : this.waitEligibleAt,
      errorCount: data.errorCount.present
          ? data.errorCount.value
          : this.errorCount,
      dueOrdinal: data.dueOrdinal.present
          ? data.dueOrdinal.value
          : this.dueOrdinal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredRetryObligation(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('generation: $generation, ')
          ..write('revision: $revision, ')
          ..write('originReviewId: $originReviewId, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('waitEligibleAt: $waitEligibleAt, ')
          ..write('errorCount: $errorCount, ')
          ..write('dueOrdinal: $dueOrdinal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    generation,
    revision,
    originReviewId,
    createdAt,
    expiresAt,
    waitEligibleAt,
    errorCount,
    dueOrdinal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredRetryObligation &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.generation == this.generation &&
          other.revision == this.revision &&
          other.originReviewId == this.originReviewId &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.waitEligibleAt == this.waitEligibleAt &&
          other.errorCount == this.errorCount &&
          other.dueOrdinal == this.dueOrdinal);
}

class RetryObligationsCompanion extends UpdateCompanion<StoredRetryObligation> {
  final Value<String> id;
  final Value<int> itemId;
  final Value<int> generation;
  final Value<int> revision;
  final Value<String> originReviewId;
  final Value<String> createdAt;
  final Value<String> expiresAt;
  final Value<String?> waitEligibleAt;
  final Value<int> errorCount;
  final Value<int> dueOrdinal;
  final Value<int> rowid;
  const RetryObligationsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.generation = const Value.absent(),
    this.revision = const Value.absent(),
    this.originReviewId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.waitEligibleAt = const Value.absent(),
    this.errorCount = const Value.absent(),
    this.dueOrdinal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RetryObligationsCompanion.insert({
    required String id,
    required int itemId,
    required int generation,
    this.revision = const Value.absent(),
    required String originReviewId,
    required String createdAt,
    required String expiresAt,
    this.waitEligibleAt = const Value.absent(),
    this.errorCount = const Value.absent(),
    this.dueOrdinal = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       generation = Value(generation),
       originReviewId = Value(originReviewId),
       createdAt = Value(createdAt),
       expiresAt = Value(expiresAt);
  static Insertable<StoredRetryObligation> custom({
    Expression<String>? id,
    Expression<int>? itemId,
    Expression<int>? generation,
    Expression<int>? revision,
    Expression<String>? originReviewId,
    Expression<String>? createdAt,
    Expression<String>? expiresAt,
    Expression<String>? waitEligibleAt,
    Expression<int>? errorCount,
    Expression<int>? dueOrdinal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (generation != null) 'generation': generation,
      if (revision != null) 'revision': revision,
      if (originReviewId != null) 'origin_review_id': originReviewId,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (waitEligibleAt != null) 'wait_eligible_at': waitEligibleAt,
      if (errorCount != null) 'error_count': errorCount,
      if (dueOrdinal != null) 'due_ordinal': dueOrdinal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RetryObligationsCompanion copyWith({
    Value<String>? id,
    Value<int>? itemId,
    Value<int>? generation,
    Value<int>? revision,
    Value<String>? originReviewId,
    Value<String>? createdAt,
    Value<String>? expiresAt,
    Value<String?>? waitEligibleAt,
    Value<int>? errorCount,
    Value<int>? dueOrdinal,
    Value<int>? rowid,
  }) {
    return RetryObligationsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      generation: generation ?? this.generation,
      revision: revision ?? this.revision,
      originReviewId: originReviewId ?? this.originReviewId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      waitEligibleAt: waitEligibleAt ?? this.waitEligibleAt,
      errorCount: errorCount ?? this.errorCount,
      dueOrdinal: dueOrdinal ?? this.dueOrdinal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (originReviewId.present) {
      map['origin_review_id'] = Variable<String>(originReviewId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<String>(expiresAt.value);
    }
    if (waitEligibleAt.present) {
      map['wait_eligible_at'] = Variable<String>(waitEligibleAt.value);
    }
    if (errorCount.present) {
      map['error_count'] = Variable<int>(errorCount.value);
    }
    if (dueOrdinal.present) {
      map['due_ordinal'] = Variable<int>(dueOrdinal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RetryObligationsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('generation: $generation, ')
          ..write('revision: $revision, ')
          ..write('originReviewId: $originReviewId, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('waitEligibleAt: $waitEligibleAt, ')
          ..write('errorCount: $errorCount, ')
          ..write('dueOrdinal: $dueOrdinal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScopeAnswerOrdinalsTable extends ScopeAnswerOrdinals
    with TableInfo<$ScopeAnswerOrdinalsTable, ScopeAnswerOrdinal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScopeAnswerOrdinalsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    collectionId,
    direction,
    ordinal,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scope_answer_ordinals';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScopeAnswerOrdinal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId, direction};
  @override
  ScopeAnswerOrdinal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScopeAnswerOrdinal(
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $ScopeAnswerOrdinalsTable createAlias(String alias) {
    return $ScopeAnswerOrdinalsTable(attachedDatabase, alias);
  }
}

class ScopeAnswerOrdinal extends DataClass
    implements Insertable<ScopeAnswerOrdinal> {
  final String collectionId;
  final String direction;
  final int ordinal;
  final int revision;
  const ScopeAnswerOrdinal({
    required this.collectionId,
    required this.direction,
    required this.ordinal,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<String>(collectionId);
    map['direction'] = Variable<String>(direction);
    map['ordinal'] = Variable<int>(ordinal);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  ScopeAnswerOrdinalsCompanion toCompanion(bool nullToAbsent) {
    return ScopeAnswerOrdinalsCompanion(
      collectionId: Value(collectionId),
      direction: Value(direction),
      ordinal: Value(ordinal),
      revision: Value(revision),
    );
  }

  factory ScopeAnswerOrdinal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScopeAnswerOrdinal(
      collectionId: serializer.fromJson<String>(json['collectionId']),
      direction: serializer.fromJson<String>(json['direction']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<String>(collectionId),
      'direction': serializer.toJson<String>(direction),
      'ordinal': serializer.toJson<int>(ordinal),
      'revision': serializer.toJson<int>(revision),
    };
  }

  ScopeAnswerOrdinal copyWith({
    String? collectionId,
    String? direction,
    int? ordinal,
    int? revision,
  }) => ScopeAnswerOrdinal(
    collectionId: collectionId ?? this.collectionId,
    direction: direction ?? this.direction,
    ordinal: ordinal ?? this.ordinal,
    revision: revision ?? this.revision,
  );
  ScopeAnswerOrdinal copyWithCompanion(ScopeAnswerOrdinalsCompanion data) {
    return ScopeAnswerOrdinal(
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      direction: data.direction.present ? data.direction.value : this.direction,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScopeAnswerOrdinal(')
          ..write('collectionId: $collectionId, ')
          ..write('direction: $direction, ')
          ..write('ordinal: $ordinal, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collectionId, direction, ordinal, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScopeAnswerOrdinal &&
          other.collectionId == this.collectionId &&
          other.direction == this.direction &&
          other.ordinal == this.ordinal &&
          other.revision == this.revision);
}

class ScopeAnswerOrdinalsCompanion extends UpdateCompanion<ScopeAnswerOrdinal> {
  final Value<String> collectionId;
  final Value<String> direction;
  final Value<int> ordinal;
  final Value<int> revision;
  final Value<int> rowid;
  const ScopeAnswerOrdinalsCompanion({
    this.collectionId = const Value.absent(),
    this.direction = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScopeAnswerOrdinalsCompanion.insert({
    required String collectionId,
    required String direction,
    required int ordinal,
    required int revision,
    this.rowid = const Value.absent(),
  }) : collectionId = Value(collectionId),
       direction = Value(direction),
       ordinal = Value(ordinal),
       revision = Value(revision);
  static Insertable<ScopeAnswerOrdinal> custom({
    Expression<String>? collectionId,
    Expression<String>? direction,
    Expression<int>? ordinal,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (direction != null) 'direction': direction,
      if (ordinal != null) 'ordinal': ordinal,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScopeAnswerOrdinalsCompanion copyWith({
    Value<String>? collectionId,
    Value<String>? direction,
    Value<int>? ordinal,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return ScopeAnswerOrdinalsCompanion(
      collectionId: collectionId ?? this.collectionId,
      direction: direction ?? this.direction,
      ordinal: ordinal ?? this.ordinal,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScopeAnswerOrdinalsCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('direction: $direction, ')
          ..write('ordinal: $ordinal, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
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

class $VocabularyOrderSequenceTable extends VocabularyOrderSequence
    with TableInfo<$VocabularyOrderSequenceTable, VocabularyOrderSequenceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabularyOrderSequenceTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nextRowIdMeta = const VerificationMeta(
    'nextRowId',
  );
  @override
  late final GeneratedColumn<int> nextRowId = GeneratedColumn<int>(
    'next_row_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [singleton, nextRowId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocabulary_order_sequence';
  @override
  VerificationContext validateIntegrity(
    Insertable<VocabularyOrderSequenceData> instance, {
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
    if (data.containsKey('next_row_id')) {
      context.handle(
        _nextRowIdMeta,
        nextRowId.isAcceptableOrUnknown(data['next_row_id']!, _nextRowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nextRowIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singleton};
  @override
  VocabularyOrderSequenceData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabularyOrderSequenceData(
      singleton: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton'],
      )!,
      nextRowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_row_id'],
      )!,
    );
  }

  @override
  $VocabularyOrderSequenceTable createAlias(String alias) {
    return $VocabularyOrderSequenceTable(attachedDatabase, alias);
  }
}

class VocabularyOrderSequenceData extends DataClass
    implements Insertable<VocabularyOrderSequenceData> {
  final int singleton;
  final int nextRowId;
  const VocabularyOrderSequenceData({
    required this.singleton,
    required this.nextRowId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton'] = Variable<int>(singleton);
    map['next_row_id'] = Variable<int>(nextRowId);
    return map;
  }

  VocabularyOrderSequenceCompanion toCompanion(bool nullToAbsent) {
    return VocabularyOrderSequenceCompanion(
      singleton: Value(singleton),
      nextRowId: Value(nextRowId),
    );
  }

  factory VocabularyOrderSequenceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabularyOrderSequenceData(
      singleton: serializer.fromJson<int>(json['singleton']),
      nextRowId: serializer.fromJson<int>(json['nextRowId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singleton': serializer.toJson<int>(singleton),
      'nextRowId': serializer.toJson<int>(nextRowId),
    };
  }

  VocabularyOrderSequenceData copyWith({int? singleton, int? nextRowId}) =>
      VocabularyOrderSequenceData(
        singleton: singleton ?? this.singleton,
        nextRowId: nextRowId ?? this.nextRowId,
      );
  VocabularyOrderSequenceData copyWithCompanion(
    VocabularyOrderSequenceCompanion data,
  ) {
    return VocabularyOrderSequenceData(
      singleton: data.singleton.present ? data.singleton.value : this.singleton,
      nextRowId: data.nextRowId.present ? data.nextRowId.value : this.nextRowId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyOrderSequenceData(')
          ..write('singleton: $singleton, ')
          ..write('nextRowId: $nextRowId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(singleton, nextRowId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabularyOrderSequenceData &&
          other.singleton == this.singleton &&
          other.nextRowId == this.nextRowId);
}

class VocabularyOrderSequenceCompanion
    extends UpdateCompanion<VocabularyOrderSequenceData> {
  final Value<int> singleton;
  final Value<int> nextRowId;
  const VocabularyOrderSequenceCompanion({
    this.singleton = const Value.absent(),
    this.nextRowId = const Value.absent(),
  });
  VocabularyOrderSequenceCompanion.insert({
    this.singleton = const Value.absent(),
    required int nextRowId,
  }) : nextRowId = Value(nextRowId);
  static Insertable<VocabularyOrderSequenceData> custom({
    Expression<int>? singleton,
    Expression<int>? nextRowId,
  }) {
    return RawValuesInsertable({
      if (singleton != null) 'singleton': singleton,
      if (nextRowId != null) 'next_row_id': nextRowId,
    });
  }

  VocabularyOrderSequenceCompanion copyWith({
    Value<int>? singleton,
    Value<int>? nextRowId,
  }) {
    return VocabularyOrderSequenceCompanion(
      singleton: singleton ?? this.singleton,
      nextRowId: nextRowId ?? this.nextRowId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singleton.present) {
      map['singleton'] = Variable<int>(singleton.value);
    }
    if (nextRowId.present) {
      map['next_row_id'] = Variable<int>(nextRowId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyOrderSequenceCompanion(')
          ..write('singleton: $singleton, ')
          ..write('nextRowId: $nextRowId')
          ..write(')'))
        .toString();
  }
}

class $CategoryDimensionsTable extends CategoryDimensions
    with TableInfo<$CategoryDimensionsTable, StoredCategoryDimension> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryDimensionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameKeyMeta = const VerificationMeta(
    'nameKey',
  );
  @override
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
    'name_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collectionId,
    name,
    nameKey,
    mode,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_dimensions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredCategoryDimension> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_key')) {
      context.handle(
        _nameKeyMeta,
        nameKey.isAcceptableOrUnknown(data['name_key']!, _nameKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nameKeyMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredCategoryDimension map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredCategoryDimension(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_key'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $CategoryDimensionsTable createAlias(String alias) {
    return $CategoryDimensionsTable(attachedDatabase, alias);
  }
}

class StoredCategoryDimension extends DataClass
    implements Insertable<StoredCategoryDimension> {
  final String id;
  final String collectionId;
  final String name;
  final String nameKey;
  final String mode;
  final int position;
  const StoredCategoryDimension({
    required this.id,
    required this.collectionId,
    required this.name,
    required this.nameKey,
    required this.mode,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['collection_id'] = Variable<String>(collectionId);
    map['name'] = Variable<String>(name);
    map['name_key'] = Variable<String>(nameKey);
    map['mode'] = Variable<String>(mode);
    map['position'] = Variable<int>(position);
    return map;
  }

  CategoryDimensionsCompanion toCompanion(bool nullToAbsent) {
    return CategoryDimensionsCompanion(
      id: Value(id),
      collectionId: Value(collectionId),
      name: Value(name),
      nameKey: Value(nameKey),
      mode: Value(mode),
      position: Value(position),
    );
  }

  factory StoredCategoryDimension.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredCategoryDimension(
      id: serializer.fromJson<String>(json['id']),
      collectionId: serializer.fromJson<String>(json['collectionId']),
      name: serializer.fromJson<String>(json['name']),
      nameKey: serializer.fromJson<String>(json['nameKey']),
      mode: serializer.fromJson<String>(json['mode']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'collectionId': serializer.toJson<String>(collectionId),
      'name': serializer.toJson<String>(name),
      'nameKey': serializer.toJson<String>(nameKey),
      'mode': serializer.toJson<String>(mode),
      'position': serializer.toJson<int>(position),
    };
  }

  StoredCategoryDimension copyWith({
    String? id,
    String? collectionId,
    String? name,
    String? nameKey,
    String? mode,
    int? position,
  }) => StoredCategoryDimension(
    id: id ?? this.id,
    collectionId: collectionId ?? this.collectionId,
    name: name ?? this.name,
    nameKey: nameKey ?? this.nameKey,
    mode: mode ?? this.mode,
    position: position ?? this.position,
  );
  StoredCategoryDimension copyWithCompanion(CategoryDimensionsCompanion data) {
    return StoredCategoryDimension(
      id: data.id.present ? data.id.value : this.id,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      name: data.name.present ? data.name.value : this.name,
      nameKey: data.nameKey.present ? data.nameKey.value : this.nameKey,
      mode: data.mode.present ? data.mode.value : this.mode,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredCategoryDimension(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('name: $name, ')
          ..write('nameKey: $nameKey, ')
          ..write('mode: $mode, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, collectionId, name, nameKey, mode, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredCategoryDimension &&
          other.id == this.id &&
          other.collectionId == this.collectionId &&
          other.name == this.name &&
          other.nameKey == this.nameKey &&
          other.mode == this.mode &&
          other.position == this.position);
}

class CategoryDimensionsCompanion
    extends UpdateCompanion<StoredCategoryDimension> {
  final Value<String> id;
  final Value<String> collectionId;
  final Value<String> name;
  final Value<String> nameKey;
  final Value<String> mode;
  final Value<int> position;
  final Value<int> rowid;
  const CategoryDimensionsCompanion({
    this.id = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.name = const Value.absent(),
    this.nameKey = const Value.absent(),
    this.mode = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryDimensionsCompanion.insert({
    required String id,
    required String collectionId,
    required String name,
    required String nameKey,
    required String mode,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       collectionId = Value(collectionId),
       name = Value(name),
       nameKey = Value(nameKey),
       mode = Value(mode),
       position = Value(position);
  static Insertable<StoredCategoryDimension> custom({
    Expression<String>? id,
    Expression<String>? collectionId,
    Expression<String>? name,
    Expression<String>? nameKey,
    Expression<String>? mode,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collectionId != null) 'collection_id': collectionId,
      if (name != null) 'name': name,
      if (nameKey != null) 'name_key': nameKey,
      if (mode != null) 'mode': mode,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryDimensionsCompanion copyWith({
    Value<String>? id,
    Value<String>? collectionId,
    Value<String>? name,
    Value<String>? nameKey,
    Value<String>? mode,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return CategoryDimensionsCompanion(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      name: name ?? this.name,
      nameKey: nameKey ?? this.nameKey,
      mode: mode ?? this.mode,
      position: position ?? this.position,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameKey.present) {
      map['name_key'] = Variable<String>(nameKey.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryDimensionsCompanion(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('name: $name, ')
          ..write('nameKey: $nameKey, ')
          ..write('mode: $mode, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryValuesTable extends CategoryValues
    with TableInfo<$CategoryValuesTable, StoredCategoryValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimensionIdMeta = const VerificationMeta(
    'dimensionId',
  );
  @override
  late final GeneratedColumn<String> dimensionId = GeneratedColumn<String>(
    'dimension_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES category_dimensions (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _nameKeyMeta = const VerificationMeta(
    'nameKey',
  );
  @override
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
    'name_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dimensionId,
    name,
    nameKey,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredCategoryValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dimension_id')) {
      context.handle(
        _dimensionIdMeta,
        dimensionId.isAcceptableOrUnknown(
          data['dimension_id']!,
          _dimensionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dimensionIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_key')) {
      context.handle(
        _nameKeyMeta,
        nameKey.isAcceptableOrUnknown(data['name_key']!, _nameKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nameKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredCategoryValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredCategoryValue(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dimensionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dimension_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $CategoryValuesTable createAlias(String alias) {
    return $CategoryValuesTable(attachedDatabase, alias);
  }
}

class StoredCategoryValue extends DataClass
    implements Insertable<StoredCategoryValue> {
  final String id;
  final String dimensionId;
  final String name;
  final String nameKey;
  final int position;
  const StoredCategoryValue({
    required this.id,
    required this.dimensionId,
    required this.name,
    required this.nameKey,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dimension_id'] = Variable<String>(dimensionId);
    map['name'] = Variable<String>(name);
    map['name_key'] = Variable<String>(nameKey);
    map['position'] = Variable<int>(position);
    return map;
  }

  CategoryValuesCompanion toCompanion(bool nullToAbsent) {
    return CategoryValuesCompanion(
      id: Value(id),
      dimensionId: Value(dimensionId),
      name: Value(name),
      nameKey: Value(nameKey),
      position: Value(position),
    );
  }

  factory StoredCategoryValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredCategoryValue(
      id: serializer.fromJson<String>(json['id']),
      dimensionId: serializer.fromJson<String>(json['dimensionId']),
      name: serializer.fromJson<String>(json['name']),
      nameKey: serializer.fromJson<String>(json['nameKey']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dimensionId': serializer.toJson<String>(dimensionId),
      'name': serializer.toJson<String>(name),
      'nameKey': serializer.toJson<String>(nameKey),
      'position': serializer.toJson<int>(position),
    };
  }

  StoredCategoryValue copyWith({
    String? id,
    String? dimensionId,
    String? name,
    String? nameKey,
    int? position,
  }) => StoredCategoryValue(
    id: id ?? this.id,
    dimensionId: dimensionId ?? this.dimensionId,
    name: name ?? this.name,
    nameKey: nameKey ?? this.nameKey,
    position: position ?? this.position,
  );
  StoredCategoryValue copyWithCompanion(CategoryValuesCompanion data) {
    return StoredCategoryValue(
      id: data.id.present ? data.id.value : this.id,
      dimensionId: data.dimensionId.present
          ? data.dimensionId.value
          : this.dimensionId,
      name: data.name.present ? data.name.value : this.name,
      nameKey: data.nameKey.present ? data.nameKey.value : this.nameKey,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredCategoryValue(')
          ..write('id: $id, ')
          ..write('dimensionId: $dimensionId, ')
          ..write('name: $name, ')
          ..write('nameKey: $nameKey, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dimensionId, name, nameKey, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredCategoryValue &&
          other.id == this.id &&
          other.dimensionId == this.dimensionId &&
          other.name == this.name &&
          other.nameKey == this.nameKey &&
          other.position == this.position);
}

class CategoryValuesCompanion extends UpdateCompanion<StoredCategoryValue> {
  final Value<String> id;
  final Value<String> dimensionId;
  final Value<String> name;
  final Value<String> nameKey;
  final Value<int> position;
  final Value<int> rowid;
  const CategoryValuesCompanion({
    this.id = const Value.absent(),
    this.dimensionId = const Value.absent(),
    this.name = const Value.absent(),
    this.nameKey = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryValuesCompanion.insert({
    required String id,
    required String dimensionId,
    required String name,
    required String nameKey,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dimensionId = Value(dimensionId),
       name = Value(name),
       nameKey = Value(nameKey),
       position = Value(position);
  static Insertable<StoredCategoryValue> custom({
    Expression<String>? id,
    Expression<String>? dimensionId,
    Expression<String>? name,
    Expression<String>? nameKey,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dimensionId != null) 'dimension_id': dimensionId,
      if (name != null) 'name': name,
      if (nameKey != null) 'name_key': nameKey,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryValuesCompanion copyWith({
    Value<String>? id,
    Value<String>? dimensionId,
    Value<String>? name,
    Value<String>? nameKey,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return CategoryValuesCompanion(
      id: id ?? this.id,
      dimensionId: dimensionId ?? this.dimensionId,
      name: name ?? this.name,
      nameKey: nameKey ?? this.nameKey,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dimensionId.present) {
      map['dimension_id'] = Variable<String>(dimensionId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameKey.present) {
      map['name_key'] = Variable<String>(nameKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryValuesCompanion(')
          ..write('id: $id, ')
          ..write('dimensionId: $dimensionId, ')
          ..write('name: $name, ')
          ..write('nameKey: $nameKey, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryGroupPreferencesTable extends CategoryGroupPreferences
    with TableInfo<$CategoryGroupPreferencesTable, CategoryGroupPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryGroupPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagColorRoleMeta = const VerificationMeta(
    'tagColorRole',
  );
  @override
  late final GeneratedColumn<String> tagColorRole = GeneratedColumn<String>(
    'tag_color_role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dimensionIdMeta = const VerificationMeta(
    'dimensionId',
  );
  @override
  late final GeneratedColumn<String> dimensionId = GeneratedColumn<String>(
    'dimension_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES category_dimensions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _customValueOrderMeta = const VerificationMeta(
    'customValueOrder',
  );
  @override
  late final GeneratedColumn<bool> customValueOrder = GeneratedColumn<bool>(
    'custom_value_order',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("custom_value_order" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _carryOverMeta = const VerificationMeta(
    'carryOver',
  );
  @override
  late final GeneratedColumn<bool> carryOver = GeneratedColumn<bool>(
    'carry_over',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("carry_over" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _acquisitionSourceMeta = const VerificationMeta(
    'acquisitionSource',
  );
  @override
  late final GeneratedColumn<bool> acquisitionSource = GeneratedColumn<bool>(
    'acquisition_source',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("acquisition_source" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    tagColorRole,
    dimensionId,
    customValueOrder,
    carryOver,
    acquisitionSource,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_group_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryGroupPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag_color_role')) {
      context.handle(
        _tagColorRoleMeta,
        tagColorRole.isAcceptableOrUnknown(
          data['tag_color_role']!,
          _tagColorRoleMeta,
        ),
      );
    }
    if (data.containsKey('dimension_id')) {
      context.handle(
        _dimensionIdMeta,
        dimensionId.isAcceptableOrUnknown(
          data['dimension_id']!,
          _dimensionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dimensionIdMeta);
    }
    if (data.containsKey('custom_value_order')) {
      context.handle(
        _customValueOrderMeta,
        customValueOrder.isAcceptableOrUnknown(
          data['custom_value_order']!,
          _customValueOrderMeta,
        ),
      );
    }
    if (data.containsKey('carry_over')) {
      context.handle(
        _carryOverMeta,
        carryOver.isAcceptableOrUnknown(data['carry_over']!, _carryOverMeta),
      );
    }
    if (data.containsKey('acquisition_source')) {
      context.handle(
        _acquisitionSourceMeta,
        acquisitionSource.isAcceptableOrUnknown(
          data['acquisition_source']!,
          _acquisitionSourceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dimensionId};
  @override
  CategoryGroupPreference map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryGroupPreference(
      tagColorRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_color_role'],
      ),
      dimensionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dimension_id'],
      )!,
      customValueOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}custom_value_order'],
      )!,
      carryOver: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}carry_over'],
      )!,
      acquisitionSource: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}acquisition_source'],
      )!,
    );
  }

  @override
  $CategoryGroupPreferencesTable createAlias(String alias) {
    return $CategoryGroupPreferencesTable(attachedDatabase, alias);
  }
}

class CategoryGroupPreference extends DataClass
    implements Insertable<CategoryGroupPreference> {
  final String? tagColorRole;
  final String dimensionId;
  final bool customValueOrder;
  final bool carryOver;
  final bool acquisitionSource;
  const CategoryGroupPreference({
    this.tagColorRole,
    required this.dimensionId,
    required this.customValueOrder,
    required this.carryOver,
    required this.acquisitionSource,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || tagColorRole != null) {
      map['tag_color_role'] = Variable<String>(tagColorRole);
    }
    map['dimension_id'] = Variable<String>(dimensionId);
    map['custom_value_order'] = Variable<bool>(customValueOrder);
    map['carry_over'] = Variable<bool>(carryOver);
    map['acquisition_source'] = Variable<bool>(acquisitionSource);
    return map;
  }

  CategoryGroupPreferencesCompanion toCompanion(bool nullToAbsent) {
    return CategoryGroupPreferencesCompanion(
      tagColorRole: tagColorRole == null && nullToAbsent
          ? const Value.absent()
          : Value(tagColorRole),
      dimensionId: Value(dimensionId),
      customValueOrder: Value(customValueOrder),
      carryOver: Value(carryOver),
      acquisitionSource: Value(acquisitionSource),
    );
  }

  factory CategoryGroupPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryGroupPreference(
      tagColorRole: serializer.fromJson<String?>(json['tagColorRole']),
      dimensionId: serializer.fromJson<String>(json['dimensionId']),
      customValueOrder: serializer.fromJson<bool>(json['customValueOrder']),
      carryOver: serializer.fromJson<bool>(json['carryOver']),
      acquisitionSource: serializer.fromJson<bool>(json['acquisitionSource']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tagColorRole': serializer.toJson<String?>(tagColorRole),
      'dimensionId': serializer.toJson<String>(dimensionId),
      'customValueOrder': serializer.toJson<bool>(customValueOrder),
      'carryOver': serializer.toJson<bool>(carryOver),
      'acquisitionSource': serializer.toJson<bool>(acquisitionSource),
    };
  }

  CategoryGroupPreference copyWith({
    Value<String?> tagColorRole = const Value.absent(),
    String? dimensionId,
    bool? customValueOrder,
    bool? carryOver,
    bool? acquisitionSource,
  }) => CategoryGroupPreference(
    tagColorRole: tagColorRole.present ? tagColorRole.value : this.tagColorRole,
    dimensionId: dimensionId ?? this.dimensionId,
    customValueOrder: customValueOrder ?? this.customValueOrder,
    carryOver: carryOver ?? this.carryOver,
    acquisitionSource: acquisitionSource ?? this.acquisitionSource,
  );
  CategoryGroupPreference copyWithCompanion(
    CategoryGroupPreferencesCompanion data,
  ) {
    return CategoryGroupPreference(
      tagColorRole: data.tagColorRole.present
          ? data.tagColorRole.value
          : this.tagColorRole,
      dimensionId: data.dimensionId.present
          ? data.dimensionId.value
          : this.dimensionId,
      customValueOrder: data.customValueOrder.present
          ? data.customValueOrder.value
          : this.customValueOrder,
      carryOver: data.carryOver.present ? data.carryOver.value : this.carryOver,
      acquisitionSource: data.acquisitionSource.present
          ? data.acquisitionSource.value
          : this.acquisitionSource,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryGroupPreference(')
          ..write('tagColorRole: $tagColorRole, ')
          ..write('dimensionId: $dimensionId, ')
          ..write('customValueOrder: $customValueOrder, ')
          ..write('carryOver: $carryOver, ')
          ..write('acquisitionSource: $acquisitionSource')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tagColorRole,
    dimensionId,
    customValueOrder,
    carryOver,
    acquisitionSource,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryGroupPreference &&
          other.tagColorRole == this.tagColorRole &&
          other.dimensionId == this.dimensionId &&
          other.customValueOrder == this.customValueOrder &&
          other.carryOver == this.carryOver &&
          other.acquisitionSource == this.acquisitionSource);
}

class CategoryGroupPreferencesCompanion
    extends UpdateCompanion<CategoryGroupPreference> {
  final Value<String?> tagColorRole;
  final Value<String> dimensionId;
  final Value<bool> customValueOrder;
  final Value<bool> carryOver;
  final Value<bool> acquisitionSource;
  final Value<int> rowid;
  const CategoryGroupPreferencesCompanion({
    this.tagColorRole = const Value.absent(),
    this.dimensionId = const Value.absent(),
    this.customValueOrder = const Value.absent(),
    this.carryOver = const Value.absent(),
    this.acquisitionSource = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryGroupPreferencesCompanion.insert({
    this.tagColorRole = const Value.absent(),
    required String dimensionId,
    this.customValueOrder = const Value.absent(),
    this.carryOver = const Value.absent(),
    this.acquisitionSource = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dimensionId = Value(dimensionId);
  static Insertable<CategoryGroupPreference> custom({
    Expression<String>? tagColorRole,
    Expression<String>? dimensionId,
    Expression<bool>? customValueOrder,
    Expression<bool>? carryOver,
    Expression<bool>? acquisitionSource,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tagColorRole != null) 'tag_color_role': tagColorRole,
      if (dimensionId != null) 'dimension_id': dimensionId,
      if (customValueOrder != null) 'custom_value_order': customValueOrder,
      if (carryOver != null) 'carry_over': carryOver,
      if (acquisitionSource != null) 'acquisition_source': acquisitionSource,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryGroupPreferencesCompanion copyWith({
    Value<String?>? tagColorRole,
    Value<String>? dimensionId,
    Value<bool>? customValueOrder,
    Value<bool>? carryOver,
    Value<bool>? acquisitionSource,
    Value<int>? rowid,
  }) {
    return CategoryGroupPreferencesCompanion(
      tagColorRole: tagColorRole ?? this.tagColorRole,
      dimensionId: dimensionId ?? this.dimensionId,
      customValueOrder: customValueOrder ?? this.customValueOrder,
      carryOver: carryOver ?? this.carryOver,
      acquisitionSource: acquisitionSource ?? this.acquisitionSource,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tagColorRole.present) {
      map['tag_color_role'] = Variable<String>(tagColorRole.value);
    }
    if (dimensionId.present) {
      map['dimension_id'] = Variable<String>(dimensionId.value);
    }
    if (customValueOrder.present) {
      map['custom_value_order'] = Variable<bool>(customValueOrder.value);
    }
    if (carryOver.present) {
      map['carry_over'] = Variable<bool>(carryOver.value);
    }
    if (acquisitionSource.present) {
      map['acquisition_source'] = Variable<bool>(acquisitionSource.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryGroupPreferencesCompanion(')
          ..write('tagColorRole: $tagColorRole, ')
          ..write('dimensionId: $dimensionId, ')
          ..write('customValueOrder: $customValueOrder, ')
          ..write('carryOver: $carryOver, ')
          ..write('acquisitionSource: $acquisitionSource, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VocabularyCategoryAssignmentsTable extends VocabularyCategoryAssignments
    with
        TableInfo<
          $VocabularyCategoryAssignmentsTable,
          StoredCategoryAssignment
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabularyCategoryAssignmentsTable(this.attachedDatabase, [this._alias]);
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
  );
  static const VerificationMeta _dimensionIdMeta = const VerificationMeta(
    'dimensionId',
  );
  @override
  late final GeneratedColumn<String> dimensionId = GeneratedColumn<String>(
    'dimension_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueIdMeta = const VerificationMeta(
    'valueId',
  );
  @override
  late final GeneratedColumn<String> valueId = GeneratedColumn<String>(
    'value_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    collectionId,
    dimensionId,
    valueId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocabulary_category_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredCategoryAssignment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
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
    if (data.containsKey('dimension_id')) {
      context.handle(
        _dimensionIdMeta,
        dimensionId.isAcceptableOrUnknown(
          data['dimension_id']!,
          _dimensionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dimensionIdMeta);
    }
    if (data.containsKey('value_id')) {
      context.handle(
        _valueIdMeta,
        valueId.isAcceptableOrUnknown(data['value_id']!, _valueIdMeta),
      );
    } else if (isInserting) {
      context.missing(_valueIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, valueId};
  @override
  StoredCategoryAssignment map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredCategoryAssignment(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      )!,
      dimensionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dimension_id'],
      )!,
      valueId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_id'],
      )!,
    );
  }

  @override
  $VocabularyCategoryAssignmentsTable createAlias(String alias) {
    return $VocabularyCategoryAssignmentsTable(attachedDatabase, alias);
  }
}

class StoredCategoryAssignment extends DataClass
    implements Insertable<StoredCategoryAssignment> {
  final String entryId;
  final String collectionId;
  final String dimensionId;
  final String valueId;
  const StoredCategoryAssignment({
    required this.entryId,
    required this.collectionId,
    required this.dimensionId,
    required this.valueId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['collection_id'] = Variable<String>(collectionId);
    map['dimension_id'] = Variable<String>(dimensionId);
    map['value_id'] = Variable<String>(valueId);
    return map;
  }

  VocabularyCategoryAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return VocabularyCategoryAssignmentsCompanion(
      entryId: Value(entryId),
      collectionId: Value(collectionId),
      dimensionId: Value(dimensionId),
      valueId: Value(valueId),
    );
  }

  factory StoredCategoryAssignment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredCategoryAssignment(
      entryId: serializer.fromJson<String>(json['entryId']),
      collectionId: serializer.fromJson<String>(json['collectionId']),
      dimensionId: serializer.fromJson<String>(json['dimensionId']),
      valueId: serializer.fromJson<String>(json['valueId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'collectionId': serializer.toJson<String>(collectionId),
      'dimensionId': serializer.toJson<String>(dimensionId),
      'valueId': serializer.toJson<String>(valueId),
    };
  }

  StoredCategoryAssignment copyWith({
    String? entryId,
    String? collectionId,
    String? dimensionId,
    String? valueId,
  }) => StoredCategoryAssignment(
    entryId: entryId ?? this.entryId,
    collectionId: collectionId ?? this.collectionId,
    dimensionId: dimensionId ?? this.dimensionId,
    valueId: valueId ?? this.valueId,
  );
  StoredCategoryAssignment copyWithCompanion(
    VocabularyCategoryAssignmentsCompanion data,
  ) {
    return StoredCategoryAssignment(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      dimensionId: data.dimensionId.present
          ? data.dimensionId.value
          : this.dimensionId,
      valueId: data.valueId.present ? data.valueId.value : this.valueId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredCategoryAssignment(')
          ..write('entryId: $entryId, ')
          ..write('collectionId: $collectionId, ')
          ..write('dimensionId: $dimensionId, ')
          ..write('valueId: $valueId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryId, collectionId, dimensionId, valueId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredCategoryAssignment &&
          other.entryId == this.entryId &&
          other.collectionId == this.collectionId &&
          other.dimensionId == this.dimensionId &&
          other.valueId == this.valueId);
}

class VocabularyCategoryAssignmentsCompanion
    extends UpdateCompanion<StoredCategoryAssignment> {
  final Value<String> entryId;
  final Value<String> collectionId;
  final Value<String> dimensionId;
  final Value<String> valueId;
  final Value<int> rowid;
  const VocabularyCategoryAssignmentsCompanion({
    this.entryId = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.dimensionId = const Value.absent(),
    this.valueId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VocabularyCategoryAssignmentsCompanion.insert({
    required String entryId,
    required String collectionId,
    required String dimensionId,
    required String valueId,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       collectionId = Value(collectionId),
       dimensionId = Value(dimensionId),
       valueId = Value(valueId);
  static Insertable<StoredCategoryAssignment> custom({
    Expression<String>? entryId,
    Expression<String>? collectionId,
    Expression<String>? dimensionId,
    Expression<String>? valueId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (collectionId != null) 'collection_id': collectionId,
      if (dimensionId != null) 'dimension_id': dimensionId,
      if (valueId != null) 'value_id': valueId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VocabularyCategoryAssignmentsCompanion copyWith({
    Value<String>? entryId,
    Value<String>? collectionId,
    Value<String>? dimensionId,
    Value<String>? valueId,
    Value<int>? rowid,
  }) {
    return VocabularyCategoryAssignmentsCompanion(
      entryId: entryId ?? this.entryId,
      collectionId: collectionId ?? this.collectionId,
      dimensionId: dimensionId ?? this.dimensionId,
      valueId: valueId ?? this.valueId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (dimensionId.present) {
      map['dimension_id'] = Variable<String>(dimensionId.value);
    }
    if (valueId.present) {
      map['value_id'] = Variable<String>(valueId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyCategoryAssignmentsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('collectionId: $collectionId, ')
          ..write('dimensionId: $dimensionId, ')
          ..write('valueId: $valueId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StatisticsOriginsTable extends StatisticsOrigins
    with TableInfo<$StatisticsOriginsTable, StatisticsOrigin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StatisticsOriginsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonMeta = const VerificationMeta(
    'singleton',
  );
  @override
  late final GeneratedColumn<int> singleton = GeneratedColumn<int>(
    'singleton',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('singleton = 1'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
    'started_at',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>("substr(started_at, -1) = 'Z'"),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _learningDateMeta = const VerificationMeta(
    'learningDate',
  );
  @override
  late final GeneratedColumn<String> learningDate = GeneratedColumn<String>(
    'learning_date',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('length(learning_date) = 10'),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [singleton, startedAt, learningDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'statistics_origins';
  @override
  VerificationContext validateIntegrity(
    Insertable<StatisticsOrigin> instance, {
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
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('learning_date')) {
      context.handle(
        _learningDateMeta,
        learningDate.isAcceptableOrUnknown(
          data['learning_date']!,
          _learningDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_learningDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singleton};
  @override
  StatisticsOrigin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StatisticsOrigin(
      singleton: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_at'],
      )!,
      learningDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning_date'],
      )!,
    );
  }

  @override
  $StatisticsOriginsTable createAlias(String alias) {
    return $StatisticsOriginsTable(attachedDatabase, alias);
  }
}

class StatisticsOrigin extends DataClass
    implements Insertable<StatisticsOrigin> {
  final int singleton;
  final String startedAt;
  final String learningDate;
  const StatisticsOrigin({
    required this.singleton,
    required this.startedAt,
    required this.learningDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton'] = Variable<int>(singleton);
    map['started_at'] = Variable<String>(startedAt);
    map['learning_date'] = Variable<String>(learningDate);
    return map;
  }

  StatisticsOriginsCompanion toCompanion(bool nullToAbsent) {
    return StatisticsOriginsCompanion(
      singleton: Value(singleton),
      startedAt: Value(startedAt),
      learningDate: Value(learningDate),
    );
  }

  factory StatisticsOrigin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StatisticsOrigin(
      singleton: serializer.fromJson<int>(json['singleton']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      learningDate: serializer.fromJson<String>(json['learningDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singleton': serializer.toJson<int>(singleton),
      'startedAt': serializer.toJson<String>(startedAt),
      'learningDate': serializer.toJson<String>(learningDate),
    };
  }

  StatisticsOrigin copyWith({
    int? singleton,
    String? startedAt,
    String? learningDate,
  }) => StatisticsOrigin(
    singleton: singleton ?? this.singleton,
    startedAt: startedAt ?? this.startedAt,
    learningDate: learningDate ?? this.learningDate,
  );
  StatisticsOrigin copyWithCompanion(StatisticsOriginsCompanion data) {
    return StatisticsOrigin(
      singleton: data.singleton.present ? data.singleton.value : this.singleton,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      learningDate: data.learningDate.present
          ? data.learningDate.value
          : this.learningDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StatisticsOrigin(')
          ..write('singleton: $singleton, ')
          ..write('startedAt: $startedAt, ')
          ..write('learningDate: $learningDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(singleton, startedAt, learningDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatisticsOrigin &&
          other.singleton == this.singleton &&
          other.startedAt == this.startedAt &&
          other.learningDate == this.learningDate);
}

class StatisticsOriginsCompanion extends UpdateCompanion<StatisticsOrigin> {
  final Value<int> singleton;
  final Value<String> startedAt;
  final Value<String> learningDate;
  const StatisticsOriginsCompanion({
    this.singleton = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.learningDate = const Value.absent(),
  });
  StatisticsOriginsCompanion.insert({
    this.singleton = const Value.absent(),
    required String startedAt,
    required String learningDate,
  }) : startedAt = Value(startedAt),
       learningDate = Value(learningDate);
  static Insertable<StatisticsOrigin> custom({
    Expression<int>? singleton,
    Expression<String>? startedAt,
    Expression<String>? learningDate,
  }) {
    return RawValuesInsertable({
      if (singleton != null) 'singleton': singleton,
      if (startedAt != null) 'started_at': startedAt,
      if (learningDate != null) 'learning_date': learningDate,
    });
  }

  StatisticsOriginsCompanion copyWith({
    Value<int>? singleton,
    Value<String>? startedAt,
    Value<String>? learningDate,
  }) {
    return StatisticsOriginsCompanion(
      singleton: singleton ?? this.singleton,
      startedAt: startedAt ?? this.startedAt,
      learningDate: learningDate ?? this.learningDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singleton.present) {
      map['singleton'] = Variable<int>(singleton.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (learningDate.present) {
      map['learning_date'] = Variable<String>(learningDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StatisticsOriginsCompanion(')
          ..write('singleton: $singleton, ')
          ..write('startedAt: $startedAt, ')
          ..write('learningDate: $learningDate')
          ..write(')'))
        .toString();
  }
}

class $StatisticsActivityTable extends StatisticsActivity
    with TableInfo<$StatisticsActivityTable, StatisticsActivityData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StatisticsActivityTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _creditKeyMeta = const VerificationMeta(
    'creditKey',
  );
  @override
  late final GeneratedColumn<String> creditKey = GeneratedColumn<String>(
    'credit_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>("mode IN ('regular', 'speed')"),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>("substr(occurred_at, -1) = 'Z'"),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _learningDateMeta = const VerificationMeta(
    'learningDate',
  );
  @override
  late final GeneratedColumn<String> learningDate = GeneratedColumn<String>(
    'learning_date',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('length(learning_date) = 10'),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    creditKey,
    mode,
    occurredAt,
    learningDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'statistics_activity';
  @override
  VerificationContext validateIntegrity(
    Insertable<StatisticsActivityData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('credit_key')) {
      context.handle(
        _creditKeyMeta,
        creditKey.isAcceptableOrUnknown(data['credit_key']!, _creditKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_creditKeyMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('learning_date')) {
      context.handle(
        _learningDateMeta,
        learningDate.isAcceptableOrUnknown(
          data['learning_date']!,
          _learningDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_learningDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {creditKey};
  @override
  StatisticsActivityData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StatisticsActivityData(
      creditKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credit_key'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      )!,
      learningDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning_date'],
      )!,
    );
  }

  @override
  $StatisticsActivityTable createAlias(String alias) {
    return $StatisticsActivityTable(attachedDatabase, alias);
  }
}

class StatisticsActivityData extends DataClass
    implements Insertable<StatisticsActivityData> {
  final String creditKey;
  final String mode;
  final String occurredAt;
  final String learningDate;
  const StatisticsActivityData({
    required this.creditKey,
    required this.mode,
    required this.occurredAt,
    required this.learningDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['credit_key'] = Variable<String>(creditKey);
    map['mode'] = Variable<String>(mode);
    map['occurred_at'] = Variable<String>(occurredAt);
    map['learning_date'] = Variable<String>(learningDate);
    return map;
  }

  StatisticsActivityCompanion toCompanion(bool nullToAbsent) {
    return StatisticsActivityCompanion(
      creditKey: Value(creditKey),
      mode: Value(mode),
      occurredAt: Value(occurredAt),
      learningDate: Value(learningDate),
    );
  }

  factory StatisticsActivityData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StatisticsActivityData(
      creditKey: serializer.fromJson<String>(json['creditKey']),
      mode: serializer.fromJson<String>(json['mode']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      learningDate: serializer.fromJson<String>(json['learningDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'creditKey': serializer.toJson<String>(creditKey),
      'mode': serializer.toJson<String>(mode),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'learningDate': serializer.toJson<String>(learningDate),
    };
  }

  StatisticsActivityData copyWith({
    String? creditKey,
    String? mode,
    String? occurredAt,
    String? learningDate,
  }) => StatisticsActivityData(
    creditKey: creditKey ?? this.creditKey,
    mode: mode ?? this.mode,
    occurredAt: occurredAt ?? this.occurredAt,
    learningDate: learningDate ?? this.learningDate,
  );
  StatisticsActivityData copyWithCompanion(StatisticsActivityCompanion data) {
    return StatisticsActivityData(
      creditKey: data.creditKey.present ? data.creditKey.value : this.creditKey,
      mode: data.mode.present ? data.mode.value : this.mode,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      learningDate: data.learningDate.present
          ? data.learningDate.value
          : this.learningDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StatisticsActivityData(')
          ..write('creditKey: $creditKey, ')
          ..write('mode: $mode, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('learningDate: $learningDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(creditKey, mode, occurredAt, learningDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatisticsActivityData &&
          other.creditKey == this.creditKey &&
          other.mode == this.mode &&
          other.occurredAt == this.occurredAt &&
          other.learningDate == this.learningDate);
}

class StatisticsActivityCompanion
    extends UpdateCompanion<StatisticsActivityData> {
  final Value<String> creditKey;
  final Value<String> mode;
  final Value<String> occurredAt;
  final Value<String> learningDate;
  final Value<int> rowid;
  const StatisticsActivityCompanion({
    this.creditKey = const Value.absent(),
    this.mode = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.learningDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StatisticsActivityCompanion.insert({
    required String creditKey,
    required String mode,
    required String occurredAt,
    required String learningDate,
    this.rowid = const Value.absent(),
  }) : creditKey = Value(creditKey),
       mode = Value(mode),
       occurredAt = Value(occurredAt),
       learningDate = Value(learningDate);
  static Insertable<StatisticsActivityData> custom({
    Expression<String>? creditKey,
    Expression<String>? mode,
    Expression<String>? occurredAt,
    Expression<String>? learningDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (creditKey != null) 'credit_key': creditKey,
      if (mode != null) 'mode': mode,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (learningDate != null) 'learning_date': learningDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StatisticsActivityCompanion copyWith({
    Value<String>? creditKey,
    Value<String>? mode,
    Value<String>? occurredAt,
    Value<String>? learningDate,
    Value<int>? rowid,
  }) {
    return StatisticsActivityCompanion(
      creditKey: creditKey ?? this.creditKey,
      mode: mode ?? this.mode,
      occurredAt: occurredAt ?? this.occurredAt,
      learningDate: learningDate ?? this.learningDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (creditKey.present) {
      map['credit_key'] = Variable<String>(creditKey.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (learningDate.present) {
      map['learning_date'] = Variable<String>(learningDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StatisticsActivityCompanion(')
          ..write('creditKey: $creditKey, ')
          ..write('mode: $mode, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('learningDate: $learningDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpeedCompletionReceiptsTable extends SpeedCompletionReceipts
    with TableInfo<$SpeedCompletionReceiptsTable, SpeedCompletionReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeedCompletionReceiptsTable(this.attachedDatabase, [this._alias]);
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
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "direction IN ('targetToNative', 'nativeToTarget')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>("substr(completed_at, -1) = 'Z'"),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _learningDateMeta = const VerificationMeta(
    'learningDate',
  );
  @override
  late final GeneratedColumn<String> learningDate = GeneratedColumn<String>(
    'learning_date',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('length(learning_date) = 10'),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    direction,
    completedAt,
    learningDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'speed_completion_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpeedCompletionReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('learning_date')) {
      context.handle(
        _learningDateMeta,
        learningDate.isAcceptableOrUnknown(
          data['learning_date']!,
          _learningDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_learningDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, direction, completedAt};
  @override
  SpeedCompletionReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpeedCompletionReceipt(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      )!,
      learningDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning_date'],
      )!,
    );
  }

  @override
  $SpeedCompletionReceiptsTable createAlias(String alias) {
    return $SpeedCompletionReceiptsTable(attachedDatabase, alias);
  }
}

class SpeedCompletionReceipt extends DataClass
    implements Insertable<SpeedCompletionReceipt> {
  final String entryId;
  final String direction;
  final String completedAt;
  final String learningDate;
  const SpeedCompletionReceipt({
    required this.entryId,
    required this.direction,
    required this.completedAt,
    required this.learningDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['direction'] = Variable<String>(direction);
    map['completed_at'] = Variable<String>(completedAt);
    map['learning_date'] = Variable<String>(learningDate);
    return map;
  }

  SpeedCompletionReceiptsCompanion toCompanion(bool nullToAbsent) {
    return SpeedCompletionReceiptsCompanion(
      entryId: Value(entryId),
      direction: Value(direction),
      completedAt: Value(completedAt),
      learningDate: Value(learningDate),
    );
  }

  factory SpeedCompletionReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpeedCompletionReceipt(
      entryId: serializer.fromJson<String>(json['entryId']),
      direction: serializer.fromJson<String>(json['direction']),
      completedAt: serializer.fromJson<String>(json['completedAt']),
      learningDate: serializer.fromJson<String>(json['learningDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'direction': serializer.toJson<String>(direction),
      'completedAt': serializer.toJson<String>(completedAt),
      'learningDate': serializer.toJson<String>(learningDate),
    };
  }

  SpeedCompletionReceipt copyWith({
    String? entryId,
    String? direction,
    String? completedAt,
    String? learningDate,
  }) => SpeedCompletionReceipt(
    entryId: entryId ?? this.entryId,
    direction: direction ?? this.direction,
    completedAt: completedAt ?? this.completedAt,
    learningDate: learningDate ?? this.learningDate,
  );
  SpeedCompletionReceipt copyWithCompanion(
    SpeedCompletionReceiptsCompanion data,
  ) {
    return SpeedCompletionReceipt(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      direction: data.direction.present ? data.direction.value : this.direction,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      learningDate: data.learningDate.present
          ? data.learningDate.value
          : this.learningDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpeedCompletionReceipt(')
          ..write('entryId: $entryId, ')
          ..write('direction: $direction, ')
          ..write('completedAt: $completedAt, ')
          ..write('learningDate: $learningDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(entryId, direction, completedAt, learningDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpeedCompletionReceipt &&
          other.entryId == this.entryId &&
          other.direction == this.direction &&
          other.completedAt == this.completedAt &&
          other.learningDate == this.learningDate);
}

class SpeedCompletionReceiptsCompanion
    extends UpdateCompanion<SpeedCompletionReceipt> {
  final Value<String> entryId;
  final Value<String> direction;
  final Value<String> completedAt;
  final Value<String> learningDate;
  final Value<int> rowid;
  const SpeedCompletionReceiptsCompanion({
    this.entryId = const Value.absent(),
    this.direction = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.learningDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeedCompletionReceiptsCompanion.insert({
    required String entryId,
    required String direction,
    required String completedAt,
    required String learningDate,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       direction = Value(direction),
       completedAt = Value(completedAt),
       learningDate = Value(learningDate);
  static Insertable<SpeedCompletionReceipt> custom({
    Expression<String>? entryId,
    Expression<String>? direction,
    Expression<String>? completedAt,
    Expression<String>? learningDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (direction != null) 'direction': direction,
      if (completedAt != null) 'completed_at': completedAt,
      if (learningDate != null) 'learning_date': learningDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeedCompletionReceiptsCompanion copyWith({
    Value<String>? entryId,
    Value<String>? direction,
    Value<String>? completedAt,
    Value<String>? learningDate,
    Value<int>? rowid,
  }) {
    return SpeedCompletionReceiptsCompanion(
      entryId: entryId ?? this.entryId,
      direction: direction ?? this.direction,
      completedAt: completedAt ?? this.completedAt,
      learningDate: learningDate ?? this.learningDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (learningDate.present) {
      map['learning_date'] = Variable<String>(learningDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeedCompletionReceiptsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('direction: $direction, ')
          ..write('completedAt: $completedAt, ')
          ..write('learningDate: $learningDate, ')
          ..write('rowid: $rowid')
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
  late final $VocabularyExamplesTable vocabularyExamples =
      $VocabularyExamplesTable(this);
  late final $LearningItemsTable learningItems = $LearningItemsTable(this);
  late final $RegularReviewsTable regularReviews = $RegularReviewsTable(this);
  late final $RetryObligationsTable retryObligations = $RetryObligationsTable(
    this,
  );
  late final $ScopeAnswerOrdinalsTable scopeAnswerOrdinals =
      $ScopeAnswerOrdinalsTable(this);
  late final $LearningIdentitySequenceTable learningIdentitySequence =
      $LearningIdentitySequenceTable(this);
  late final $VocabularyOrderSequenceTable vocabularyOrderSequence =
      $VocabularyOrderSequenceTable(this);
  late final $CategoryDimensionsTable categoryDimensions =
      $CategoryDimensionsTable(this);
  late final $CategoryValuesTable categoryValues = $CategoryValuesTable(this);
  late final $CategoryGroupPreferencesTable categoryGroupPreferences =
      $CategoryGroupPreferencesTable(this);
  late final $VocabularyCategoryAssignmentsTable vocabularyCategoryAssignments =
      $VocabularyCategoryAssignmentsTable(this);
  late final $StatisticsOriginsTable statisticsOrigins =
      $StatisticsOriginsTable(this);
  late final $StatisticsActivityTable statisticsActivity =
      $StatisticsActivityTable(this);
  late final $SpeedCompletionReceiptsTable speedCompletionReceipts =
      $SpeedCompletionReceiptsTable(this);
  late final Index vocabularyEntryOwnership = Index(
    'vocabulary_entry_ownership',
    'CREATE UNIQUE INDEX vocabulary_entry_ownership ON vocabulary_entries (id, collection_id)',
  );
  late final Index statisticsActivityDate = Index(
    'statistics_activity_date',
    'CREATE INDEX statistics_activity_date ON statistics_activity (learning_date, mode)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    collections,
    vocabularyEntries,
    vocabularyExamples,
    learningItems,
    regularReviews,
    retryObligations,
    scopeAnswerOrdinals,
    learningIdentitySequence,
    vocabularyOrderSequence,
    categoryDimensions,
    categoryValues,
    categoryGroupPreferences,
    vocabularyCategoryAssignments,
    statisticsOrigins,
    statisticsActivity,
    speedCompletionReceipts,
    vocabularyEntryOwnership,
    statisticsActivityDate,
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
      result: [TableUpdate('vocabulary_examples', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vocabulary_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learning_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learning_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('regular_reviews', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learning_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('retry_obligations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'regular_reviews',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('retry_obligations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'collections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scope_answer_ordinals', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'collections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('category_dimensions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'category_dimensions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('category_values', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'category_dimensions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('category_group_preferences', kind: UpdateKind.delete),
      ],
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
      Value<String?> targetLanguageName,
      Value<String?> nativeLanguageName,
      Value<bool> automaticHintDefault,
      Value<bool> hintDefaultOfferHandled,
      Value<int> rowid,
    });
typedef $$CollectionsTableUpdateCompanionBuilder =
    CollectionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> targetLanguage,
      Value<String> nativeLanguage,
      Value<String?> targetLanguageName,
      Value<String?> nativeLanguageName,
      Value<bool> automaticHintDefault,
      Value<bool> hintDefaultOfferHandled,
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

  static MultiTypedResultKey<
    $ScopeAnswerOrdinalsTable,
    List<ScopeAnswerOrdinal>
  >
  _scopeAnswerOrdinalsRefsTable(_$PikoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scopeAnswerOrdinals,
        aliasName: 'collections__id__scope_answer_ordinals__collection_id',
      );

  $$ScopeAnswerOrdinalsTableProcessedTableManager get scopeAnswerOrdinalsRefs {
    final manager = $$ScopeAnswerOrdinalsTableTableManager(
      $_db,
      $_db.scopeAnswerOrdinals,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scopeAnswerOrdinalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CategoryDimensionsTable,
    List<StoredCategoryDimension>
  >
  _categoryDimensionsRefsTable(_$PikoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.categoryDimensions,
        aliasName: 'collections__id__category_dimensions__collection_id',
      );

  $$CategoryDimensionsTableProcessedTableManager get categoryDimensionsRefs {
    final manager = $$CategoryDimensionsTableTableManager(
      $_db,
      $_db.categoryDimensions,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _categoryDimensionsRefsTable($_db),
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

  ColumnFilters<String> get targetLanguageName => $composableBuilder(
    column: $table.targetLanguageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nativeLanguageName => $composableBuilder(
    column: $table.nativeLanguageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get automaticHintDefault => $composableBuilder(
    column: $table.automaticHintDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hintDefaultOfferHandled => $composableBuilder(
    column: $table.hintDefaultOfferHandled,
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

  Expression<bool> scopeAnswerOrdinalsRefs(
    Expression<bool> Function($$ScopeAnswerOrdinalsTableFilterComposer f) f,
  ) {
    final $$ScopeAnswerOrdinalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scopeAnswerOrdinals,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScopeAnswerOrdinalsTableFilterComposer(
            $db: $db,
            $table: $db.scopeAnswerOrdinals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> categoryDimensionsRefs(
    Expression<bool> Function($$CategoryDimensionsTableFilterComposer f) f,
  ) {
    final $$CategoryDimensionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryDimensions,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryDimensionsTableFilterComposer(
            $db: $db,
            $table: $db.categoryDimensions,
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

  ColumnOrderings<String> get targetLanguageName => $composableBuilder(
    column: $table.targetLanguageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nativeLanguageName => $composableBuilder(
    column: $table.nativeLanguageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get automaticHintDefault => $composableBuilder(
    column: $table.automaticHintDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hintDefaultOfferHandled => $composableBuilder(
    column: $table.hintDefaultOfferHandled,
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

  GeneratedColumn<String> get targetLanguageName => $composableBuilder(
    column: $table.targetLanguageName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nativeLanguageName => $composableBuilder(
    column: $table.nativeLanguageName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get automaticHintDefault => $composableBuilder(
    column: $table.automaticHintDefault,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hintDefaultOfferHandled => $composableBuilder(
    column: $table.hintDefaultOfferHandled,
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

  Expression<T> scopeAnswerOrdinalsRefs<T extends Object>(
    Expression<T> Function($$ScopeAnswerOrdinalsTableAnnotationComposer a) f,
  ) {
    final $$ScopeAnswerOrdinalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scopeAnswerOrdinals,
          getReferencedColumn: (t) => t.collectionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScopeAnswerOrdinalsTableAnnotationComposer(
                $db: $db,
                $table: $db.scopeAnswerOrdinals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> categoryDimensionsRefs<T extends Object>(
    Expression<T> Function($$CategoryDimensionsTableAnnotationComposer a) f,
  ) {
    final $$CategoryDimensionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.categoryDimensions,
          getReferencedColumn: (t) => t.collectionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CategoryDimensionsTableAnnotationComposer(
                $db: $db,
                $table: $db.categoryDimensions,
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
          PrefetchHooks Function({
            bool vocabularyEntriesRefs,
            bool scopeAnswerOrdinalsRefs,
            bool categoryDimensionsRefs,
          })
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
                Value<String?> targetLanguageName = const Value.absent(),
                Value<String?> nativeLanguageName = const Value.absent(),
                Value<bool> automaticHintDefault = const Value.absent(),
                Value<bool> hintDefaultOfferHandled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion(
                id: id,
                name: name,
                targetLanguage: targetLanguage,
                nativeLanguage: nativeLanguage,
                targetLanguageName: targetLanguageName,
                nativeLanguageName: nativeLanguageName,
                automaticHintDefault: automaticHintDefault,
                hintDefaultOfferHandled: hintDefaultOfferHandled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String targetLanguage,
                required String nativeLanguage,
                Value<String?> targetLanguageName = const Value.absent(),
                Value<String?> nativeLanguageName = const Value.absent(),
                Value<bool> automaticHintDefault = const Value.absent(),
                Value<bool> hintDefaultOfferHandled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion.insert(
                id: id,
                name: name,
                targetLanguage: targetLanguage,
                nativeLanguage: nativeLanguage,
                targetLanguageName: targetLanguageName,
                nativeLanguageName: nativeLanguageName,
                automaticHintDefault: automaticHintDefault,
                hintDefaultOfferHandled: hintDefaultOfferHandled,
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
          prefetchHooksCallback:
              ({
                vocabularyEntriesRefs = false,
                scopeAnswerOrdinalsRefs = false,
                categoryDimensionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (vocabularyEntriesRefs) db.vocabularyEntries,
                    if (scopeAnswerOrdinalsRefs) db.scopeAnswerOrdinals,
                    if (categoryDimensionsRefs) db.categoryDimensions,
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
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.collectionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scopeAnswerOrdinalsRefs)
                        await $_getPrefetchedData<
                          Collection,
                          $CollectionsTable,
                          ScopeAnswerOrdinal
                        >(
                          currentTable: table,
                          referencedTable: $$CollectionsTableReferences
                              ._scopeAnswerOrdinalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CollectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).scopeAnswerOrdinalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.collectionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (categoryDimensionsRefs)
                        await $_getPrefetchedData<
                          Collection,
                          $CollectionsTable,
                          StoredCategoryDimension
                        >(
                          currentTable: table,
                          referencedTable: $$CollectionsTableReferences
                              ._categoryDimensionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CollectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).categoryDimensionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
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
      PrefetchHooks Function({
        bool vocabularyEntriesRefs,
        bool scopeAnswerOrdinalsRefs,
        bool categoryDimensionsRefs,
      })
    >;
typedef $$VocabularyEntriesTableCreateCompanionBuilder =
    VocabularyEntriesCompanion Function({
      required String id,
      required String collectionId,
      required String targetText,
      required String nativeText,
      required String targetKey,
      required String nativeKey,
      Value<String> hintKey,
      Value<bool> active,
      Value<String?> exampleTargetText,
      Value<String?> exampleNativeText,
      Value<String?> addedAt,
      Value<String?> hintText,
      Value<String> hintVisibility,
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
      Value<String> hintKey,
      Value<bool> active,
      Value<String?> exampleTargetText,
      Value<String?> exampleNativeText,
      Value<String?> addedAt,
      Value<String?> hintText,
      Value<String> hintVisibility,
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

  static MultiTypedResultKey<$VocabularyExamplesTable, List<VocabularyExample>>
  _vocabularyExamplesRefsTable(_$PikoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.vocabularyExamples,
        aliasName: 'vocabulary_entries__id__vocabulary_examples__entry_id',
      );

  $$VocabularyExamplesTableProcessedTableManager get vocabularyExamplesRefs {
    final manager = $$VocabularyExamplesTableTableManager(
      $_db,
      $_db.vocabularyExamples,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _vocabularyExamplesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
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

  ColumnFilters<String> get hintKey => $composableBuilder(
    column: $table.hintKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleTargetText => $composableBuilder(
    column: $table.exampleTargetText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleNativeText => $composableBuilder(
    column: $table.exampleNativeText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hintText => $composableBuilder(
    column: $table.hintText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hintVisibility => $composableBuilder(
    column: $table.hintVisibility,
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

  Expression<bool> vocabularyExamplesRefs(
    Expression<bool> Function($$VocabularyExamplesTableFilterComposer f) f,
  ) {
    final $$VocabularyExamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vocabularyExamples,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VocabularyExamplesTableFilterComposer(
            $db: $db,
            $table: $db.vocabularyExamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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

  ColumnOrderings<String> get hintKey => $composableBuilder(
    column: $table.hintKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleTargetText => $composableBuilder(
    column: $table.exampleTargetText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleNativeText => $composableBuilder(
    column: $table.exampleNativeText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hintText => $composableBuilder(
    column: $table.hintText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hintVisibility => $composableBuilder(
    column: $table.hintVisibility,
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

  GeneratedColumn<String> get hintKey =>
      $composableBuilder(column: $table.hintKey, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<String> get exampleTargetText => $composableBuilder(
    column: $table.exampleTargetText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exampleNativeText => $composableBuilder(
    column: $table.exampleNativeText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get hintText =>
      $composableBuilder(column: $table.hintText, builder: (column) => column);

  GeneratedColumn<String> get hintVisibility => $composableBuilder(
    column: $table.hintVisibility,
    builder: (column) => column,
  );

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

  Expression<T> vocabularyExamplesRefs<T extends Object>(
    Expression<T> Function($$VocabularyExamplesTableAnnotationComposer a) f,
  ) {
    final $$VocabularyExamplesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.vocabularyExamples,
          getReferencedColumn: (t) => t.entryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VocabularyExamplesTableAnnotationComposer(
                $db: $db,
                $table: $db.vocabularyExamples,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
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
          PrefetchHooks Function({
            bool collectionId,
            bool vocabularyExamplesRefs,
            bool learningItemsRefs,
          })
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
                Value<String> hintKey = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> exampleTargetText = const Value.absent(),
                Value<String?> exampleNativeText = const Value.absent(),
                Value<String?> addedAt = const Value.absent(),
                Value<String?> hintText = const Value.absent(),
                Value<String> hintVisibility = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VocabularyEntriesCompanion(
                id: id,
                collectionId: collectionId,
                targetText: targetText,
                nativeText: nativeText,
                targetKey: targetKey,
                nativeKey: nativeKey,
                hintKey: hintKey,
                active: active,
                exampleTargetText: exampleTargetText,
                exampleNativeText: exampleNativeText,
                addedAt: addedAt,
                hintText: hintText,
                hintVisibility: hintVisibility,
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
                Value<String> hintKey = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String?> exampleTargetText = const Value.absent(),
                Value<String?> exampleNativeText = const Value.absent(),
                Value<String?> addedAt = const Value.absent(),
                Value<String?> hintText = const Value.absent(),
                Value<String> hintVisibility = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VocabularyEntriesCompanion.insert(
                id: id,
                collectionId: collectionId,
                targetText: targetText,
                nativeText: nativeText,
                targetKey: targetKey,
                nativeKey: nativeKey,
                hintKey: hintKey,
                active: active,
                exampleTargetText: exampleTargetText,
                exampleNativeText: exampleNativeText,
                addedAt: addedAt,
                hintText: hintText,
                hintVisibility: hintVisibility,
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
              ({
                collectionId = false,
                vocabularyExamplesRefs = false,
                learningItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (vocabularyExamplesRefs) db.vocabularyExamples,
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
                      if (vocabularyExamplesRefs)
                        await $_getPrefetchedData<
                          VocabularyEntry,
                          $VocabularyEntriesTable,
                          VocabularyExample
                        >(
                          currentTable: table,
                          referencedTable: $$VocabularyEntriesTableReferences
                              ._vocabularyExamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VocabularyEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).vocabularyExamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
                              ),
                          typedResults: items,
                        ),
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
      PrefetchHooks Function({
        bool collectionId,
        bool vocabularyExamplesRefs,
        bool learningItemsRefs,
      })
    >;
typedef $$VocabularyExamplesTableCreateCompanionBuilder =
    VocabularyExamplesCompanion Function({
      required String entryId,
      required int position,
      required String targetText,
      required String nativeText,
      Value<int> rowid,
    });
typedef $$VocabularyExamplesTableUpdateCompanionBuilder =
    VocabularyExamplesCompanion Function({
      Value<String> entryId,
      Value<int> position,
      Value<String> targetText,
      Value<String> nativeText,
      Value<int> rowid,
    });

final class $$VocabularyExamplesTableReferences
    extends
        BaseReferences<
          _$PikoDatabase,
          $VocabularyExamplesTable,
          VocabularyExample
        > {
  $$VocabularyExamplesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VocabularyEntriesTable _entryIdTable(_$PikoDatabase db) => db
      .vocabularyEntries
      .createAlias('vocabulary_examples__entry_id__vocabulary_entries__id');

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

class $$VocabularyExamplesTableFilterComposer
    extends Composer<_$PikoDatabase, $VocabularyExamplesTable> {
  $$VocabularyExamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
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

class $$VocabularyExamplesTableOrderingComposer
    extends Composer<_$PikoDatabase, $VocabularyExamplesTable> {
  $$VocabularyExamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
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

class $$VocabularyExamplesTableAnnotationComposer
    extends Composer<_$PikoDatabase, $VocabularyExamplesTable> {
  $$VocabularyExamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get targetText => $composableBuilder(
    column: $table.targetText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nativeText => $composableBuilder(
    column: $table.nativeText,
    builder: (column) => column,
  );

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

class $$VocabularyExamplesTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $VocabularyExamplesTable,
          VocabularyExample,
          $$VocabularyExamplesTableFilterComposer,
          $$VocabularyExamplesTableOrderingComposer,
          $$VocabularyExamplesTableAnnotationComposer,
          $$VocabularyExamplesTableCreateCompanionBuilder,
          $$VocabularyExamplesTableUpdateCompanionBuilder,
          (VocabularyExample, $$VocabularyExamplesTableReferences),
          VocabularyExample,
          PrefetchHooks Function({bool entryId})
        > {
  $$VocabularyExamplesTableTableManager(
    _$PikoDatabase db,
    $VocabularyExamplesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabularyExamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VocabularyExamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VocabularyExamplesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> targetText = const Value.absent(),
                Value<String> nativeText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VocabularyExamplesCompanion(
                entryId: entryId,
                position: position,
                targetText: targetText,
                nativeText: nativeText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required int position,
                required String targetText,
                required String nativeText,
                Value<int> rowid = const Value.absent(),
              }) => VocabularyExamplesCompanion.insert(
                entryId: entryId,
                position: position,
                targetText: targetText,
                nativeText: nativeText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VocabularyExamplesTable, VocabularyExample>(
                    table,
                  ),
                  $$VocabularyExamplesTableReferences(db, table, e),
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
                                referencedTable:
                                    $$VocabularyExamplesTableReferences
                                        ._entryIdTable(db),
                                referencedColumn:
                                    $$VocabularyExamplesTableReferences
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

typedef $$VocabularyExamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $VocabularyExamplesTable,
      VocabularyExample,
      $$VocabularyExamplesTableFilterComposer,
      $$VocabularyExamplesTableOrderingComposer,
      $$VocabularyExamplesTableAnnotationComposer,
      $$VocabularyExamplesTableCreateCompanionBuilder,
      $$VocabularyExamplesTableUpdateCompanionBuilder,
      (VocabularyExample, $$VocabularyExamplesTableReferences),
      VocabularyExample,
      PrefetchHooks Function({bool entryId})
    >;
typedef $$LearningItemsTableCreateCompanionBuilder =
    LearningItemsCompanion Function({
      Value<int> id,
      required String entryId,
      required String direction,
      required int formatVersion,
      required String cardJson,
      Value<int> generation,
      Value<int> reviewRevision,
      Value<bool> speedCompleted,
    });
typedef $$LearningItemsTableUpdateCompanionBuilder =
    LearningItemsCompanion Function({
      Value<int> id,
      Value<String> entryId,
      Value<String> direction,
      Value<int> formatVersion,
      Value<String> cardJson,
      Value<int> generation,
      Value<int> reviewRevision,
      Value<bool> speedCompleted,
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

  static MultiTypedResultKey<$RegularReviewsTable, List<RegularReview>>
  _regularReviewsRefsTable(_$PikoDatabase db) => MultiTypedResultKey.fromTable(
    db.regularReviews,
    aliasName: 'learning_items__id__regular_reviews__item_id',
  );

  $$RegularReviewsTableProcessedTableManager get regularReviewsRefs {
    final manager = $$RegularReviewsTableTableManager(
      $_db,
      $_db.regularReviews,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_regularReviewsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $RetryObligationsTable,
    List<StoredRetryObligation>
  >
  _retryObligationsRefsTable(_$PikoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.retryObligations,
        aliasName: 'learning_items__id__retry_obligations__item_id',
      );

  $$RetryObligationsTableProcessedTableManager get retryObligationsRefs {
    final manager = $$RetryObligationsTableTableManager(
      $_db,
      $_db.retryObligations,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _retryObligationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
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

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reviewRevision => $composableBuilder(
    column: $table.reviewRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get speedCompleted => $composableBuilder(
    column: $table.speedCompleted,
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

  Expression<bool> regularReviewsRefs(
    Expression<bool> Function($$RegularReviewsTableFilterComposer f) f,
  ) {
    final $$RegularReviewsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.regularReviews,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegularReviewsTableFilterComposer(
            $db: $db,
            $table: $db.regularReviews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> retryObligationsRefs(
    Expression<bool> Function($$RetryObligationsTableFilterComposer f) f,
  ) {
    final $$RetryObligationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.retryObligations,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RetryObligationsTableFilterComposer(
            $db: $db,
            $table: $db.retryObligations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reviewRevision => $composableBuilder(
    column: $table.reviewRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get speedCompleted => $composableBuilder(
    column: $table.speedCompleted,
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

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reviewRevision => $composableBuilder(
    column: $table.reviewRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get speedCompleted => $composableBuilder(
    column: $table.speedCompleted,
    builder: (column) => column,
  );

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

  Expression<T> regularReviewsRefs<T extends Object>(
    Expression<T> Function($$RegularReviewsTableAnnotationComposer a) f,
  ) {
    final $$RegularReviewsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.regularReviews,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegularReviewsTableAnnotationComposer(
            $db: $db,
            $table: $db.regularReviews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> retryObligationsRefs<T extends Object>(
    Expression<T> Function($$RetryObligationsTableAnnotationComposer a) f,
  ) {
    final $$RetryObligationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.retryObligations,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RetryObligationsTableAnnotationComposer(
            $db: $db,
            $table: $db.retryObligations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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
          PrefetchHooks Function({
            bool entryId,
            bool regularReviewsRefs,
            bool retryObligationsRefs,
          })
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
                Value<int> generation = const Value.absent(),
                Value<int> reviewRevision = const Value.absent(),
                Value<bool> speedCompleted = const Value.absent(),
              }) => LearningItemsCompanion(
                id: id,
                entryId: entryId,
                direction: direction,
                formatVersion: formatVersion,
                cardJson: cardJson,
                generation: generation,
                reviewRevision: reviewRevision,
                speedCompleted: speedCompleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entryId,
                required String direction,
                required int formatVersion,
                required String cardJson,
                Value<int> generation = const Value.absent(),
                Value<int> reviewRevision = const Value.absent(),
                Value<bool> speedCompleted = const Value.absent(),
              }) => LearningItemsCompanion.insert(
                id: id,
                entryId: entryId,
                direction: direction,
                formatVersion: formatVersion,
                cardJson: cardJson,
                generation: generation,
                reviewRevision: reviewRevision,
                speedCompleted: speedCompleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningItemsTable, LearningItem>(table),
                  $$LearningItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                entryId = false,
                regularReviewsRefs = false,
                retryObligationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (regularReviewsRefs) db.regularReviews,
                    if (retryObligationsRefs) db.retryObligations,
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
                        if (entryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.entryId,
                                    referencedTable:
                                        $$LearningItemsTableReferences
                                            ._entryIdTable(db),
                                    referencedColumn:
                                        $$LearningItemsTableReferences
                                            ._entryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (regularReviewsRefs)
                        await $_getPrefetchedData<
                          LearningItem,
                          $LearningItemsTable,
                          RegularReview
                        >(
                          currentTable: table,
                          referencedTable: $$LearningItemsTableReferences
                              ._regularReviewsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).regularReviewsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (retryObligationsRefs)
                        await $_getPrefetchedData<
                          LearningItem,
                          $LearningItemsTable,
                          StoredRetryObligation
                        >(
                          currentTable: table,
                          referencedTable: $$LearningItemsTableReferences
                              ._retryObligationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).retryObligationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
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
      PrefetchHooks Function({
        bool entryId,
        bool regularReviewsRefs,
        bool retryObligationsRefs,
      })
    >;
typedef $$RegularReviewsTableCreateCompanionBuilder =
    RegularReviewsCompanion Function({
      required String id,
      required int itemId,
      required int generation,
      required String reviewedAt,
      required String rating,
      Value<int> rowid,
    });
typedef $$RegularReviewsTableUpdateCompanionBuilder =
    RegularReviewsCompanion Function({
      Value<String> id,
      Value<int> itemId,
      Value<int> generation,
      Value<String> reviewedAt,
      Value<String> rating,
      Value<int> rowid,
    });

final class $$RegularReviewsTableReferences
    extends
        BaseReferences<_$PikoDatabase, $RegularReviewsTable, RegularReview> {
  $$RegularReviewsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningItemsTable _itemIdTable(_$PikoDatabase db) => db.learningItems
      .createAlias('regular_reviews__item_id__learning_items__id');

  $$LearningItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<int>('item_id')!;

    final manager = $$LearningItemsTableTableManager(
      $_db,
      $_db.learningItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $RetryObligationsTable,
    List<StoredRetryObligation>
  >
  _retryObligationsRefsTable(_$PikoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.retryObligations,
        aliasName: 'regular_reviews__id__retry_obligations__origin_review_id',
      );

  $$RetryObligationsTableProcessedTableManager get retryObligationsRefs {
    final manager = $$RetryObligationsTableTableManager(
      $_db,
      $_db.retryObligations,
    ).filter((f) => f.originReviewId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _retryObligationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RegularReviewsTableFilterComposer
    extends Composer<_$PikoDatabase, $RegularReviewsTable> {
  $$RegularReviewsTableFilterComposer({
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

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningItemsTableFilterComposer get itemId {
    final $$LearningItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.learningItems,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }

  Expression<bool> retryObligationsRefs(
    Expression<bool> Function($$RetryObligationsTableFilterComposer f) f,
  ) {
    final $$RetryObligationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.retryObligations,
      getReferencedColumn: (t) => t.originReviewId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RetryObligationsTableFilterComposer(
            $db: $db,
            $table: $db.retryObligations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RegularReviewsTableOrderingComposer
    extends Composer<_$PikoDatabase, $RegularReviewsTable> {
  $$RegularReviewsTableOrderingComposer({
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

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningItemsTableOrderingComposer get itemId {
    final $$LearningItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.learningItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningItemsTableOrderingComposer(
            $db: $db,
            $table: $db.learningItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RegularReviewsTableAnnotationComposer
    extends Composer<_$PikoDatabase, $RegularReviewsTable> {
  $$RegularReviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  $$LearningItemsTableAnnotationComposer get itemId {
    final $$LearningItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.learningItems,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }

  Expression<T> retryObligationsRefs<T extends Object>(
    Expression<T> Function($$RetryObligationsTableAnnotationComposer a) f,
  ) {
    final $$RetryObligationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.retryObligations,
      getReferencedColumn: (t) => t.originReviewId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RetryObligationsTableAnnotationComposer(
            $db: $db,
            $table: $db.retryObligations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RegularReviewsTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $RegularReviewsTable,
          RegularReview,
          $$RegularReviewsTableFilterComposer,
          $$RegularReviewsTableOrderingComposer,
          $$RegularReviewsTableAnnotationComposer,
          $$RegularReviewsTableCreateCompanionBuilder,
          $$RegularReviewsTableUpdateCompanionBuilder,
          (RegularReview, $$RegularReviewsTableReferences),
          RegularReview,
          PrefetchHooks Function({bool itemId, bool retryObligationsRefs})
        > {
  $$RegularReviewsTableTableManager(
    _$PikoDatabase db,
    $RegularReviewsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RegularReviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RegularReviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RegularReviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> itemId = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<String> reviewedAt = const Value.absent(),
                Value<String> rating = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegularReviewsCompanion(
                id: id,
                itemId: itemId,
                generation: generation,
                reviewedAt: reviewedAt,
                rating: rating,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int itemId,
                required int generation,
                required String reviewedAt,
                required String rating,
                Value<int> rowid = const Value.absent(),
              }) => RegularReviewsCompanion.insert(
                id: id,
                itemId: itemId,
                generation: generation,
                reviewedAt: reviewedAt,
                rating: rating,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RegularReviewsTable, RegularReview>(table),
                  $$RegularReviewsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({itemId = false, retryObligationsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (retryObligationsRefs) db.retryObligations,
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
                        if (itemId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.itemId,
                                    referencedTable:
                                        $$RegularReviewsTableReferences
                                            ._itemIdTable(db),
                                    referencedColumn:
                                        $$RegularReviewsTableReferences
                                            ._itemIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (retryObligationsRefs)
                        await $_getPrefetchedData<
                          RegularReview,
                          $RegularReviewsTable,
                          StoredRetryObligation
                        >(
                          currentTable: table,
                          referencedTable: $$RegularReviewsTableReferences
                              ._retryObligationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RegularReviewsTableReferences(
                                db,
                                table,
                                p0,
                              ).retryObligationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.originReviewId == item.id,
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

typedef $$RegularReviewsTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $RegularReviewsTable,
      RegularReview,
      $$RegularReviewsTableFilterComposer,
      $$RegularReviewsTableOrderingComposer,
      $$RegularReviewsTableAnnotationComposer,
      $$RegularReviewsTableCreateCompanionBuilder,
      $$RegularReviewsTableUpdateCompanionBuilder,
      (RegularReview, $$RegularReviewsTableReferences),
      RegularReview,
      PrefetchHooks Function({bool itemId, bool retryObligationsRefs})
    >;
typedef $$RetryObligationsTableCreateCompanionBuilder =
    RetryObligationsCompanion Function({
      required String id,
      required int itemId,
      required int generation,
      Value<int> revision,
      required String originReviewId,
      required String createdAt,
      required String expiresAt,
      Value<String?> waitEligibleAt,
      Value<int> errorCount,
      Value<int> dueOrdinal,
      Value<int> rowid,
    });
typedef $$RetryObligationsTableUpdateCompanionBuilder =
    RetryObligationsCompanion Function({
      Value<String> id,
      Value<int> itemId,
      Value<int> generation,
      Value<int> revision,
      Value<String> originReviewId,
      Value<String> createdAt,
      Value<String> expiresAt,
      Value<String?> waitEligibleAt,
      Value<int> errorCount,
      Value<int> dueOrdinal,
      Value<int> rowid,
    });

final class $$RetryObligationsTableReferences
    extends
        BaseReferences<
          _$PikoDatabase,
          $RetryObligationsTable,
          StoredRetryObligation
        > {
  $$RetryObligationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningItemsTable _itemIdTable(_$PikoDatabase db) => db.learningItems
      .createAlias('retry_obligations__item_id__learning_items__id');

  $$LearningItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<int>('item_id')!;

    final manager = $$LearningItemsTableTableManager(
      $_db,
      $_db.learningItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RegularReviewsTable _originReviewIdTable(_$PikoDatabase db) => db
      .regularReviews
      .createAlias('retry_obligations__origin_review_id__regular_reviews__id');

  $$RegularReviewsTableProcessedTableManager get originReviewId {
    final $_column = $_itemColumn<String>('origin_review_id')!;

    final manager = $$RegularReviewsTableTableManager(
      $_db,
      $_db.regularReviews,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_originReviewIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RetryObligationsTableFilterComposer
    extends Composer<_$PikoDatabase, $RetryObligationsTable> {
  $$RetryObligationsTableFilterComposer({
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

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get waitEligibleAt => $composableBuilder(
    column: $table.waitEligibleAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get errorCount => $composableBuilder(
    column: $table.errorCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueOrdinal => $composableBuilder(
    column: $table.dueOrdinal,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningItemsTableFilterComposer get itemId {
    final $$LearningItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.learningItems,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }

  $$RegularReviewsTableFilterComposer get originReviewId {
    final $$RegularReviewsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originReviewId,
      referencedTable: $db.regularReviews,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegularReviewsTableFilterComposer(
            $db: $db,
            $table: $db.regularReviews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RetryObligationsTableOrderingComposer
    extends Composer<_$PikoDatabase, $RetryObligationsTable> {
  $$RetryObligationsTableOrderingComposer({
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

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get waitEligibleAt => $composableBuilder(
    column: $table.waitEligibleAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get errorCount => $composableBuilder(
    column: $table.errorCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueOrdinal => $composableBuilder(
    column: $table.dueOrdinal,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningItemsTableOrderingComposer get itemId {
    final $$LearningItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.learningItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningItemsTableOrderingComposer(
            $db: $db,
            $table: $db.learningItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RegularReviewsTableOrderingComposer get originReviewId {
    final $$RegularReviewsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originReviewId,
      referencedTable: $db.regularReviews,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegularReviewsTableOrderingComposer(
            $db: $db,
            $table: $db.regularReviews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RetryObligationsTableAnnotationComposer
    extends Composer<_$PikoDatabase, $RetryObligationsTable> {
  $$RetryObligationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get waitEligibleAt => $composableBuilder(
    column: $table.waitEligibleAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get errorCount => $composableBuilder(
    column: $table.errorCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueOrdinal => $composableBuilder(
    column: $table.dueOrdinal,
    builder: (column) => column,
  );

  $$LearningItemsTableAnnotationComposer get itemId {
    final $$LearningItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.learningItems,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }

  $$RegularReviewsTableAnnotationComposer get originReviewId {
    final $$RegularReviewsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originReviewId,
      referencedTable: $db.regularReviews,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RegularReviewsTableAnnotationComposer(
            $db: $db,
            $table: $db.regularReviews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RetryObligationsTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $RetryObligationsTable,
          StoredRetryObligation,
          $$RetryObligationsTableFilterComposer,
          $$RetryObligationsTableOrderingComposer,
          $$RetryObligationsTableAnnotationComposer,
          $$RetryObligationsTableCreateCompanionBuilder,
          $$RetryObligationsTableUpdateCompanionBuilder,
          (StoredRetryObligation, $$RetryObligationsTableReferences),
          StoredRetryObligation,
          PrefetchHooks Function({bool itemId, bool originReviewId})
        > {
  $$RetryObligationsTableTableManager(
    _$PikoDatabase db,
    $RetryObligationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RetryObligationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RetryObligationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RetryObligationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> itemId = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> originReviewId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> expiresAt = const Value.absent(),
                Value<String?> waitEligibleAt = const Value.absent(),
                Value<int> errorCount = const Value.absent(),
                Value<int> dueOrdinal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RetryObligationsCompanion(
                id: id,
                itemId: itemId,
                generation: generation,
                revision: revision,
                originReviewId: originReviewId,
                createdAt: createdAt,
                expiresAt: expiresAt,
                waitEligibleAt: waitEligibleAt,
                errorCount: errorCount,
                dueOrdinal: dueOrdinal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int itemId,
                required int generation,
                Value<int> revision = const Value.absent(),
                required String originReviewId,
                required String createdAt,
                required String expiresAt,
                Value<String?> waitEligibleAt = const Value.absent(),
                Value<int> errorCount = const Value.absent(),
                Value<int> dueOrdinal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RetryObligationsCompanion.insert(
                id: id,
                itemId: itemId,
                generation: generation,
                revision: revision,
                originReviewId: originReviewId,
                createdAt: createdAt,
                expiresAt: expiresAt,
                waitEligibleAt: waitEligibleAt,
                errorCount: errorCount,
                dueOrdinal: dueOrdinal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RetryObligationsTable, StoredRetryObligation>(
                    table,
                  ),
                  $$RetryObligationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false, originReviewId = false}) {
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
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable:
                                    $$RetryObligationsTableReferences
                                        ._itemIdTable(db),
                                referencedColumn:
                                    $$RetryObligationsTableReferences
                                        ._itemIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (originReviewId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.originReviewId,
                                referencedTable:
                                    $$RetryObligationsTableReferences
                                        ._originReviewIdTable(db),
                                referencedColumn:
                                    $$RetryObligationsTableReferences
                                        ._originReviewIdTable(db)
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

typedef $$RetryObligationsTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $RetryObligationsTable,
      StoredRetryObligation,
      $$RetryObligationsTableFilterComposer,
      $$RetryObligationsTableOrderingComposer,
      $$RetryObligationsTableAnnotationComposer,
      $$RetryObligationsTableCreateCompanionBuilder,
      $$RetryObligationsTableUpdateCompanionBuilder,
      (StoredRetryObligation, $$RetryObligationsTableReferences),
      StoredRetryObligation,
      PrefetchHooks Function({bool itemId, bool originReviewId})
    >;
typedef $$ScopeAnswerOrdinalsTableCreateCompanionBuilder =
    ScopeAnswerOrdinalsCompanion Function({
      required String collectionId,
      required String direction,
      required int ordinal,
      required int revision,
      Value<int> rowid,
    });
typedef $$ScopeAnswerOrdinalsTableUpdateCompanionBuilder =
    ScopeAnswerOrdinalsCompanion Function({
      Value<String> collectionId,
      Value<String> direction,
      Value<int> ordinal,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$ScopeAnswerOrdinalsTableReferences
    extends
        BaseReferences<
          _$PikoDatabase,
          $ScopeAnswerOrdinalsTable,
          ScopeAnswerOrdinal
        > {
  $$ScopeAnswerOrdinalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CollectionsTable _collectionIdTable(_$PikoDatabase db) => db
      .collections
      .createAlias('scope_answer_ordinals__collection_id__collections__id');

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
}

class $$ScopeAnswerOrdinalsTableFilterComposer
    extends Composer<_$PikoDatabase, $ScopeAnswerOrdinalsTable> {
  $$ScopeAnswerOrdinalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
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
}

class $$ScopeAnswerOrdinalsTableOrderingComposer
    extends Composer<_$PikoDatabase, $ScopeAnswerOrdinalsTable> {
  $$ScopeAnswerOrdinalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
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

class $$ScopeAnswerOrdinalsTableAnnotationComposer
    extends Composer<_$PikoDatabase, $ScopeAnswerOrdinalsTable> {
  $$ScopeAnswerOrdinalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

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
}

class $$ScopeAnswerOrdinalsTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $ScopeAnswerOrdinalsTable,
          ScopeAnswerOrdinal,
          $$ScopeAnswerOrdinalsTableFilterComposer,
          $$ScopeAnswerOrdinalsTableOrderingComposer,
          $$ScopeAnswerOrdinalsTableAnnotationComposer,
          $$ScopeAnswerOrdinalsTableCreateCompanionBuilder,
          $$ScopeAnswerOrdinalsTableUpdateCompanionBuilder,
          (ScopeAnswerOrdinal, $$ScopeAnswerOrdinalsTableReferences),
          ScopeAnswerOrdinal,
          PrefetchHooks Function({bool collectionId})
        > {
  $$ScopeAnswerOrdinalsTableTableManager(
    _$PikoDatabase db,
    $ScopeAnswerOrdinalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScopeAnswerOrdinalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScopeAnswerOrdinalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScopeAnswerOrdinalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> collectionId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScopeAnswerOrdinalsCompanion(
                collectionId: collectionId,
                direction: direction,
                ordinal: ordinal,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collectionId,
                required String direction,
                required int ordinal,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => ScopeAnswerOrdinalsCompanion.insert(
                collectionId: collectionId,
                direction: direction,
                ordinal: ordinal,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScopeAnswerOrdinalsTable, ScopeAnswerOrdinal>(
                    table,
                  ),
                  $$ScopeAnswerOrdinalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionId = false}) {
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
                    if (collectionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.collectionId,
                                referencedTable:
                                    $$ScopeAnswerOrdinalsTableReferences
                                        ._collectionIdTable(db),
                                referencedColumn:
                                    $$ScopeAnswerOrdinalsTableReferences
                                        ._collectionIdTable(db)
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

typedef $$ScopeAnswerOrdinalsTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $ScopeAnswerOrdinalsTable,
      ScopeAnswerOrdinal,
      $$ScopeAnswerOrdinalsTableFilterComposer,
      $$ScopeAnswerOrdinalsTableOrderingComposer,
      $$ScopeAnswerOrdinalsTableAnnotationComposer,
      $$ScopeAnswerOrdinalsTableCreateCompanionBuilder,
      $$ScopeAnswerOrdinalsTableUpdateCompanionBuilder,
      (ScopeAnswerOrdinal, $$ScopeAnswerOrdinalsTableReferences),
      ScopeAnswerOrdinal,
      PrefetchHooks Function({bool collectionId})
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
typedef $$VocabularyOrderSequenceTableCreateCompanionBuilder =
    VocabularyOrderSequenceCompanion Function({
      Value<int> singleton,
      required int nextRowId,
    });
typedef $$VocabularyOrderSequenceTableUpdateCompanionBuilder =
    VocabularyOrderSequenceCompanion Function({
      Value<int> singleton,
      Value<int> nextRowId,
    });

class $$VocabularyOrderSequenceTableFilterComposer
    extends Composer<_$PikoDatabase, $VocabularyOrderSequenceTable> {
  $$VocabularyOrderSequenceTableFilterComposer({
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

  ColumnFilters<int> get nextRowId => $composableBuilder(
    column: $table.nextRowId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VocabularyOrderSequenceTableOrderingComposer
    extends Composer<_$PikoDatabase, $VocabularyOrderSequenceTable> {
  $$VocabularyOrderSequenceTableOrderingComposer({
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

  ColumnOrderings<int> get nextRowId => $composableBuilder(
    column: $table.nextRowId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VocabularyOrderSequenceTableAnnotationComposer
    extends Composer<_$PikoDatabase, $VocabularyOrderSequenceTable> {
  $$VocabularyOrderSequenceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singleton =>
      $composableBuilder(column: $table.singleton, builder: (column) => column);

  GeneratedColumn<int> get nextRowId =>
      $composableBuilder(column: $table.nextRowId, builder: (column) => column);
}

class $$VocabularyOrderSequenceTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $VocabularyOrderSequenceTable,
          VocabularyOrderSequenceData,
          $$VocabularyOrderSequenceTableFilterComposer,
          $$VocabularyOrderSequenceTableOrderingComposer,
          $$VocabularyOrderSequenceTableAnnotationComposer,
          $$VocabularyOrderSequenceTableCreateCompanionBuilder,
          $$VocabularyOrderSequenceTableUpdateCompanionBuilder,
          (
            VocabularyOrderSequenceData,
            BaseReferences<
              _$PikoDatabase,
              $VocabularyOrderSequenceTable,
              VocabularyOrderSequenceData
            >,
          ),
          VocabularyOrderSequenceData,
          PrefetchHooks Function()
        > {
  $$VocabularyOrderSequenceTableTableManager(
    _$PikoDatabase db,
    $VocabularyOrderSequenceTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabularyOrderSequenceTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$VocabularyOrderSequenceTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$VocabularyOrderSequenceTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                Value<int> nextRowId = const Value.absent(),
              }) => VocabularyOrderSequenceCompanion(
                singleton: singleton,
                nextRowId: nextRowId,
              ),
          createCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                required int nextRowId,
              }) => VocabularyOrderSequenceCompanion.insert(
                singleton: singleton,
                nextRowId: nextRowId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $VocabularyOrderSequenceTable,
                    VocabularyOrderSequenceData
                  >(table),
                  BaseReferences<
                    _$PikoDatabase,
                    $VocabularyOrderSequenceTable,
                    VocabularyOrderSequenceData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VocabularyOrderSequenceTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $VocabularyOrderSequenceTable,
      VocabularyOrderSequenceData,
      $$VocabularyOrderSequenceTableFilterComposer,
      $$VocabularyOrderSequenceTableOrderingComposer,
      $$VocabularyOrderSequenceTableAnnotationComposer,
      $$VocabularyOrderSequenceTableCreateCompanionBuilder,
      $$VocabularyOrderSequenceTableUpdateCompanionBuilder,
      (
        VocabularyOrderSequenceData,
        BaseReferences<
          _$PikoDatabase,
          $VocabularyOrderSequenceTable,
          VocabularyOrderSequenceData
        >,
      ),
      VocabularyOrderSequenceData,
      PrefetchHooks Function()
    >;
typedef $$CategoryDimensionsTableCreateCompanionBuilder =
    CategoryDimensionsCompanion Function({
      required String id,
      required String collectionId,
      required String name,
      required String nameKey,
      required String mode,
      required int position,
      Value<int> rowid,
    });
typedef $$CategoryDimensionsTableUpdateCompanionBuilder =
    CategoryDimensionsCompanion Function({
      Value<String> id,
      Value<String> collectionId,
      Value<String> name,
      Value<String> nameKey,
      Value<String> mode,
      Value<int> position,
      Value<int> rowid,
    });

final class $$CategoryDimensionsTableReferences
    extends
        BaseReferences<
          _$PikoDatabase,
          $CategoryDimensionsTable,
          StoredCategoryDimension
        > {
  $$CategoryDimensionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CollectionsTable _collectionIdTable(_$PikoDatabase db) => db
      .collections
      .createAlias('category_dimensions__collection_id__collections__id');

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

  static MultiTypedResultKey<$CategoryValuesTable, List<StoredCategoryValue>>
  _categoryValuesRefsTable(_$PikoDatabase db) => MultiTypedResultKey.fromTable(
    db.categoryValues,
    aliasName: 'category_dimensions__id__category_values__dimension_id',
  );

  $$CategoryValuesTableProcessedTableManager get categoryValuesRefs {
    final manager = $$CategoryValuesTableTableManager(
      $_db,
      $_db.categoryValues,
    ).filter((f) => f.dimensionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_categoryValuesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CategoryGroupPreferencesTable,
    List<CategoryGroupPreference>
  >
  _categoryGroupPreferencesRefsTable(_$PikoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.categoryGroupPreferences,
        aliasName:
            'category_dimensions__id__category_group_preferences__dimension_id',
      );

  $$CategoryGroupPreferencesTableProcessedTableManager
  get categoryGroupPreferencesRefs {
    final manager = $$CategoryGroupPreferencesTableTableManager(
      $_db,
      $_db.categoryGroupPreferences,
    ).filter((f) => f.dimensionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _categoryGroupPreferencesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoryDimensionsTableFilterComposer
    extends Composer<_$PikoDatabase, $CategoryDimensionsTable> {
  $$CategoryDimensionsTableFilterComposer({
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

  ColumnFilters<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
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

  Expression<bool> categoryValuesRefs(
    Expression<bool> Function($$CategoryValuesTableFilterComposer f) f,
  ) {
    final $$CategoryValuesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryValues,
      getReferencedColumn: (t) => t.dimensionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryValuesTableFilterComposer(
            $db: $db,
            $table: $db.categoryValues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> categoryGroupPreferencesRefs(
    Expression<bool> Function($$CategoryGroupPreferencesTableFilterComposer f)
    f,
  ) {
    final $$CategoryGroupPreferencesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.categoryGroupPreferences,
          getReferencedColumn: (t) => t.dimensionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CategoryGroupPreferencesTableFilterComposer(
                $db: $db,
                $table: $db.categoryGroupPreferences,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoryDimensionsTableOrderingComposer
    extends Composer<_$PikoDatabase, $CategoryDimensionsTable> {
  $$CategoryDimensionsTableOrderingComposer({
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

  ColumnOrderings<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
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

class $$CategoryDimensionsTableAnnotationComposer
    extends Composer<_$PikoDatabase, $CategoryDimensionsTable> {
  $$CategoryDimensionsTableAnnotationComposer({
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

  GeneratedColumn<String> get nameKey =>
      $composableBuilder(column: $table.nameKey, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

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

  Expression<T> categoryValuesRefs<T extends Object>(
    Expression<T> Function($$CategoryValuesTableAnnotationComposer a) f,
  ) {
    final $$CategoryValuesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryValues,
      getReferencedColumn: (t) => t.dimensionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryValuesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryValues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> categoryGroupPreferencesRefs<T extends Object>(
    Expression<T> Function($$CategoryGroupPreferencesTableAnnotationComposer a)
    f,
  ) {
    final $$CategoryGroupPreferencesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.categoryGroupPreferences,
          getReferencedColumn: (t) => t.dimensionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CategoryGroupPreferencesTableAnnotationComposer(
                $db: $db,
                $table: $db.categoryGroupPreferences,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoryDimensionsTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $CategoryDimensionsTable,
          StoredCategoryDimension,
          $$CategoryDimensionsTableFilterComposer,
          $$CategoryDimensionsTableOrderingComposer,
          $$CategoryDimensionsTableAnnotationComposer,
          $$CategoryDimensionsTableCreateCompanionBuilder,
          $$CategoryDimensionsTableUpdateCompanionBuilder,
          (StoredCategoryDimension, $$CategoryDimensionsTableReferences),
          StoredCategoryDimension,
          PrefetchHooks Function({
            bool collectionId,
            bool categoryValuesRefs,
            bool categoryGroupPreferencesRefs,
          })
        > {
  $$CategoryDimensionsTableTableManager(
    _$PikoDatabase db,
    $CategoryDimensionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryDimensionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryDimensionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryDimensionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> collectionId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameKey = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryDimensionsCompanion(
                id: id,
                collectionId: collectionId,
                name: name,
                nameKey: nameKey,
                mode: mode,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String collectionId,
                required String name,
                required String nameKey,
                required String mode,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => CategoryDimensionsCompanion.insert(
                id: id,
                collectionId: collectionId,
                name: name,
                nameKey: nameKey,
                mode: mode,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $CategoryDimensionsTable,
                    StoredCategoryDimension
                  >(table),
                  $$CategoryDimensionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                collectionId = false,
                categoryValuesRefs = false,
                categoryGroupPreferencesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (categoryValuesRefs) db.categoryValues,
                    if (categoryGroupPreferencesRefs)
                      db.categoryGroupPreferences,
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
                                        $$CategoryDimensionsTableReferences
                                            ._collectionIdTable(db),
                                    referencedColumn:
                                        $$CategoryDimensionsTableReferences
                                            ._collectionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (categoryValuesRefs)
                        await $_getPrefetchedData<
                          StoredCategoryDimension,
                          $CategoryDimensionsTable,
                          StoredCategoryValue
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryDimensionsTableReferences
                              ._categoryValuesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryDimensionsTableReferences(
                                db,
                                table,
                                p0,
                              ).categoryValuesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.dimensionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (categoryGroupPreferencesRefs)
                        await $_getPrefetchedData<
                          StoredCategoryDimension,
                          $CategoryDimensionsTable,
                          CategoryGroupPreference
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryDimensionsTableReferences
                              ._categoryGroupPreferencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryDimensionsTableReferences(
                                db,
                                table,
                                p0,
                              ).categoryGroupPreferencesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.dimensionId == item.id,
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

typedef $$CategoryDimensionsTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $CategoryDimensionsTable,
      StoredCategoryDimension,
      $$CategoryDimensionsTableFilterComposer,
      $$CategoryDimensionsTableOrderingComposer,
      $$CategoryDimensionsTableAnnotationComposer,
      $$CategoryDimensionsTableCreateCompanionBuilder,
      $$CategoryDimensionsTableUpdateCompanionBuilder,
      (StoredCategoryDimension, $$CategoryDimensionsTableReferences),
      StoredCategoryDimension,
      PrefetchHooks Function({
        bool collectionId,
        bool categoryValuesRefs,
        bool categoryGroupPreferencesRefs,
      })
    >;
typedef $$CategoryValuesTableCreateCompanionBuilder =
    CategoryValuesCompanion Function({
      required String id,
      required String dimensionId,
      required String name,
      required String nameKey,
      required int position,
      Value<int> rowid,
    });
typedef $$CategoryValuesTableUpdateCompanionBuilder =
    CategoryValuesCompanion Function({
      Value<String> id,
      Value<String> dimensionId,
      Value<String> name,
      Value<String> nameKey,
      Value<int> position,
      Value<int> rowid,
    });

final class $$CategoryValuesTableReferences
    extends
        BaseReferences<
          _$PikoDatabase,
          $CategoryValuesTable,
          StoredCategoryValue
        > {
  $$CategoryValuesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoryDimensionsTable _dimensionIdTable(_$PikoDatabase db) => db
      .categoryDimensions
      .createAlias('category_values__dimension_id__category_dimensions__id');

  $$CategoryDimensionsTableProcessedTableManager get dimensionId {
    final $_column = $_itemColumn<String>('dimension_id')!;

    final manager = $$CategoryDimensionsTableTableManager(
      $_db,
      $_db.categoryDimensions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dimensionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CategoryValuesTableFilterComposer
    extends Composer<_$PikoDatabase, $CategoryValuesTable> {
  $$CategoryValuesTableFilterComposer({
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

  ColumnFilters<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryDimensionsTableFilterComposer get dimensionId {
    final $$CategoryDimensionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dimensionId,
      referencedTable: $db.categoryDimensions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryDimensionsTableFilterComposer(
            $db: $db,
            $table: $db.categoryDimensions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryValuesTableOrderingComposer
    extends Composer<_$PikoDatabase, $CategoryValuesTable> {
  $$CategoryValuesTableOrderingComposer({
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

  ColumnOrderings<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryDimensionsTableOrderingComposer get dimensionId {
    final $$CategoryDimensionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dimensionId,
      referencedTable: $db.categoryDimensions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryDimensionsTableOrderingComposer(
            $db: $db,
            $table: $db.categoryDimensions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryValuesTableAnnotationComposer
    extends Composer<_$PikoDatabase, $CategoryValuesTable> {
  $$CategoryValuesTableAnnotationComposer({
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

  GeneratedColumn<String> get nameKey =>
      $composableBuilder(column: $table.nameKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$CategoryDimensionsTableAnnotationComposer get dimensionId {
    final $$CategoryDimensionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.dimensionId,
          referencedTable: $db.categoryDimensions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CategoryDimensionsTableAnnotationComposer(
                $db: $db,
                $table: $db.categoryDimensions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$CategoryValuesTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $CategoryValuesTable,
          StoredCategoryValue,
          $$CategoryValuesTableFilterComposer,
          $$CategoryValuesTableOrderingComposer,
          $$CategoryValuesTableAnnotationComposer,
          $$CategoryValuesTableCreateCompanionBuilder,
          $$CategoryValuesTableUpdateCompanionBuilder,
          (StoredCategoryValue, $$CategoryValuesTableReferences),
          StoredCategoryValue,
          PrefetchHooks Function({bool dimensionId})
        > {
  $$CategoryValuesTableTableManager(
    _$PikoDatabase db,
    $CategoryValuesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dimensionId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryValuesCompanion(
                id: id,
                dimensionId: dimensionId,
                name: name,
                nameKey: nameKey,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dimensionId,
                required String name,
                required String nameKey,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => CategoryValuesCompanion.insert(
                id: id,
                dimensionId: dimensionId,
                name: name,
                nameKey: nameKey,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryValuesTable, StoredCategoryValue>(table),
                  $$CategoryValuesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({dimensionId = false}) {
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
                    if (dimensionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.dimensionId,
                                referencedTable: $$CategoryValuesTableReferences
                                    ._dimensionIdTable(db),
                                referencedColumn:
                                    $$CategoryValuesTableReferences
                                        ._dimensionIdTable(db)
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

typedef $$CategoryValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $CategoryValuesTable,
      StoredCategoryValue,
      $$CategoryValuesTableFilterComposer,
      $$CategoryValuesTableOrderingComposer,
      $$CategoryValuesTableAnnotationComposer,
      $$CategoryValuesTableCreateCompanionBuilder,
      $$CategoryValuesTableUpdateCompanionBuilder,
      (StoredCategoryValue, $$CategoryValuesTableReferences),
      StoredCategoryValue,
      PrefetchHooks Function({bool dimensionId})
    >;
typedef $$CategoryGroupPreferencesTableCreateCompanionBuilder =
    CategoryGroupPreferencesCompanion Function({
      Value<String?> tagColorRole,
      required String dimensionId,
      Value<bool> customValueOrder,
      Value<bool> carryOver,
      Value<bool> acquisitionSource,
      Value<int> rowid,
    });
typedef $$CategoryGroupPreferencesTableUpdateCompanionBuilder =
    CategoryGroupPreferencesCompanion Function({
      Value<String?> tagColorRole,
      Value<String> dimensionId,
      Value<bool> customValueOrder,
      Value<bool> carryOver,
      Value<bool> acquisitionSource,
      Value<int> rowid,
    });

final class $$CategoryGroupPreferencesTableReferences
    extends
        BaseReferences<
          _$PikoDatabase,
          $CategoryGroupPreferencesTable,
          CategoryGroupPreference
        > {
  $$CategoryGroupPreferencesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoryDimensionsTable _dimensionIdTable(_$PikoDatabase db) =>
      db.categoryDimensions.createAlias(
        'category_group_preferences__dimension_id__category_dimensions__id',
      );

  $$CategoryDimensionsTableProcessedTableManager get dimensionId {
    final $_column = $_itemColumn<String>('dimension_id')!;

    final manager = $$CategoryDimensionsTableTableManager(
      $_db,
      $_db.categoryDimensions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dimensionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CategoryGroupPreferencesTableFilterComposer
    extends Composer<_$PikoDatabase, $CategoryGroupPreferencesTable> {
  $$CategoryGroupPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tagColorRole => $composableBuilder(
    column: $table.tagColorRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get customValueOrder => $composableBuilder(
    column: $table.customValueOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get carryOver => $composableBuilder(
    column: $table.carryOver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get acquisitionSource => $composableBuilder(
    column: $table.acquisitionSource,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryDimensionsTableFilterComposer get dimensionId {
    final $$CategoryDimensionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dimensionId,
      referencedTable: $db.categoryDimensions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryDimensionsTableFilterComposer(
            $db: $db,
            $table: $db.categoryDimensions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryGroupPreferencesTableOrderingComposer
    extends Composer<_$PikoDatabase, $CategoryGroupPreferencesTable> {
  $$CategoryGroupPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tagColorRole => $composableBuilder(
    column: $table.tagColorRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get customValueOrder => $composableBuilder(
    column: $table.customValueOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get carryOver => $composableBuilder(
    column: $table.carryOver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get acquisitionSource => $composableBuilder(
    column: $table.acquisitionSource,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryDimensionsTableOrderingComposer get dimensionId {
    final $$CategoryDimensionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dimensionId,
      referencedTable: $db.categoryDimensions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryDimensionsTableOrderingComposer(
            $db: $db,
            $table: $db.categoryDimensions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryGroupPreferencesTableAnnotationComposer
    extends Composer<_$PikoDatabase, $CategoryGroupPreferencesTable> {
  $$CategoryGroupPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tagColorRole => $composableBuilder(
    column: $table.tagColorRole,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get customValueOrder => $composableBuilder(
    column: $table.customValueOrder,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get carryOver =>
      $composableBuilder(column: $table.carryOver, builder: (column) => column);

  GeneratedColumn<bool> get acquisitionSource => $composableBuilder(
    column: $table.acquisitionSource,
    builder: (column) => column,
  );

  $$CategoryDimensionsTableAnnotationComposer get dimensionId {
    final $$CategoryDimensionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.dimensionId,
          referencedTable: $db.categoryDimensions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CategoryDimensionsTableAnnotationComposer(
                $db: $db,
                $table: $db.categoryDimensions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$CategoryGroupPreferencesTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $CategoryGroupPreferencesTable,
          CategoryGroupPreference,
          $$CategoryGroupPreferencesTableFilterComposer,
          $$CategoryGroupPreferencesTableOrderingComposer,
          $$CategoryGroupPreferencesTableAnnotationComposer,
          $$CategoryGroupPreferencesTableCreateCompanionBuilder,
          $$CategoryGroupPreferencesTableUpdateCompanionBuilder,
          (CategoryGroupPreference, $$CategoryGroupPreferencesTableReferences),
          CategoryGroupPreference,
          PrefetchHooks Function({bool dimensionId})
        > {
  $$CategoryGroupPreferencesTableTableManager(
    _$PikoDatabase db,
    $CategoryGroupPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryGroupPreferencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CategoryGroupPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CategoryGroupPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String?> tagColorRole = const Value.absent(),
                Value<String> dimensionId = const Value.absent(),
                Value<bool> customValueOrder = const Value.absent(),
                Value<bool> carryOver = const Value.absent(),
                Value<bool> acquisitionSource = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryGroupPreferencesCompanion(
                tagColorRole: tagColorRole,
                dimensionId: dimensionId,
                customValueOrder: customValueOrder,
                carryOver: carryOver,
                acquisitionSource: acquisitionSource,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> tagColorRole = const Value.absent(),
                required String dimensionId,
                Value<bool> customValueOrder = const Value.absent(),
                Value<bool> carryOver = const Value.absent(),
                Value<bool> acquisitionSource = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryGroupPreferencesCompanion.insert(
                tagColorRole: tagColorRole,
                dimensionId: dimensionId,
                customValueOrder: customValueOrder,
                carryOver: carryOver,
                acquisitionSource: acquisitionSource,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $CategoryGroupPreferencesTable,
                    CategoryGroupPreference
                  >(table),
                  $$CategoryGroupPreferencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({dimensionId = false}) {
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
                    if (dimensionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.dimensionId,
                                referencedTable:
                                    $$CategoryGroupPreferencesTableReferences
                                        ._dimensionIdTable(db),
                                referencedColumn:
                                    $$CategoryGroupPreferencesTableReferences
                                        ._dimensionIdTable(db)
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

typedef $$CategoryGroupPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $CategoryGroupPreferencesTable,
      CategoryGroupPreference,
      $$CategoryGroupPreferencesTableFilterComposer,
      $$CategoryGroupPreferencesTableOrderingComposer,
      $$CategoryGroupPreferencesTableAnnotationComposer,
      $$CategoryGroupPreferencesTableCreateCompanionBuilder,
      $$CategoryGroupPreferencesTableUpdateCompanionBuilder,
      (CategoryGroupPreference, $$CategoryGroupPreferencesTableReferences),
      CategoryGroupPreference,
      PrefetchHooks Function({bool dimensionId})
    >;
typedef $$VocabularyCategoryAssignmentsTableCreateCompanionBuilder =
    VocabularyCategoryAssignmentsCompanion Function({
      required String entryId,
      required String collectionId,
      required String dimensionId,
      required String valueId,
      Value<int> rowid,
    });
typedef $$VocabularyCategoryAssignmentsTableUpdateCompanionBuilder =
    VocabularyCategoryAssignmentsCompanion Function({
      Value<String> entryId,
      Value<String> collectionId,
      Value<String> dimensionId,
      Value<String> valueId,
      Value<int> rowid,
    });

class $$VocabularyCategoryAssignmentsTableFilterComposer
    extends Composer<_$PikoDatabase, $VocabularyCategoryAssignmentsTable> {
  $$VocabularyCategoryAssignmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dimensionId => $composableBuilder(
    column: $table.dimensionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueId => $composableBuilder(
    column: $table.valueId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VocabularyCategoryAssignmentsTableOrderingComposer
    extends Composer<_$PikoDatabase, $VocabularyCategoryAssignmentsTable> {
  $$VocabularyCategoryAssignmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dimensionId => $composableBuilder(
    column: $table.dimensionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueId => $composableBuilder(
    column: $table.valueId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VocabularyCategoryAssignmentsTableAnnotationComposer
    extends Composer<_$PikoDatabase, $VocabularyCategoryAssignmentsTable> {
  $$VocabularyCategoryAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dimensionId => $composableBuilder(
    column: $table.dimensionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valueId =>
      $composableBuilder(column: $table.valueId, builder: (column) => column);
}

class $$VocabularyCategoryAssignmentsTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $VocabularyCategoryAssignmentsTable,
          StoredCategoryAssignment,
          $$VocabularyCategoryAssignmentsTableFilterComposer,
          $$VocabularyCategoryAssignmentsTableOrderingComposer,
          $$VocabularyCategoryAssignmentsTableAnnotationComposer,
          $$VocabularyCategoryAssignmentsTableCreateCompanionBuilder,
          $$VocabularyCategoryAssignmentsTableUpdateCompanionBuilder,
          (
            StoredCategoryAssignment,
            BaseReferences<
              _$PikoDatabase,
              $VocabularyCategoryAssignmentsTable,
              StoredCategoryAssignment
            >,
          ),
          StoredCategoryAssignment,
          PrefetchHooks Function()
        > {
  $$VocabularyCategoryAssignmentsTableTableManager(
    _$PikoDatabase db,
    $VocabularyCategoryAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabularyCategoryAssignmentsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$VocabularyCategoryAssignmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$VocabularyCategoryAssignmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> collectionId = const Value.absent(),
                Value<String> dimensionId = const Value.absent(),
                Value<String> valueId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VocabularyCategoryAssignmentsCompanion(
                entryId: entryId,
                collectionId: collectionId,
                dimensionId: dimensionId,
                valueId: valueId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String collectionId,
                required String dimensionId,
                required String valueId,
                Value<int> rowid = const Value.absent(),
              }) => VocabularyCategoryAssignmentsCompanion.insert(
                entryId: entryId,
                collectionId: collectionId,
                dimensionId: dimensionId,
                valueId: valueId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $VocabularyCategoryAssignmentsTable,
                    StoredCategoryAssignment
                  >(table),
                  BaseReferences<
                    _$PikoDatabase,
                    $VocabularyCategoryAssignmentsTable,
                    StoredCategoryAssignment
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VocabularyCategoryAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $VocabularyCategoryAssignmentsTable,
      StoredCategoryAssignment,
      $$VocabularyCategoryAssignmentsTableFilterComposer,
      $$VocabularyCategoryAssignmentsTableOrderingComposer,
      $$VocabularyCategoryAssignmentsTableAnnotationComposer,
      $$VocabularyCategoryAssignmentsTableCreateCompanionBuilder,
      $$VocabularyCategoryAssignmentsTableUpdateCompanionBuilder,
      (
        StoredCategoryAssignment,
        BaseReferences<
          _$PikoDatabase,
          $VocabularyCategoryAssignmentsTable,
          StoredCategoryAssignment
        >,
      ),
      StoredCategoryAssignment,
      PrefetchHooks Function()
    >;
typedef $$StatisticsOriginsTableCreateCompanionBuilder =
    StatisticsOriginsCompanion Function({
      Value<int> singleton,
      required String startedAt,
      required String learningDate,
    });
typedef $$StatisticsOriginsTableUpdateCompanionBuilder =
    StatisticsOriginsCompanion Function({
      Value<int> singleton,
      Value<String> startedAt,
      Value<String> learningDate,
    });

class $$StatisticsOriginsTableFilterComposer
    extends Composer<_$PikoDatabase, $StatisticsOriginsTable> {
  $$StatisticsOriginsTableFilterComposer({
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

  ColumnFilters<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learningDate => $composableBuilder(
    column: $table.learningDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StatisticsOriginsTableOrderingComposer
    extends Composer<_$PikoDatabase, $StatisticsOriginsTable> {
  $$StatisticsOriginsTableOrderingComposer({
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

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learningDate => $composableBuilder(
    column: $table.learningDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StatisticsOriginsTableAnnotationComposer
    extends Composer<_$PikoDatabase, $StatisticsOriginsTable> {
  $$StatisticsOriginsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singleton =>
      $composableBuilder(column: $table.singleton, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get learningDate => $composableBuilder(
    column: $table.learningDate,
    builder: (column) => column,
  );
}

class $$StatisticsOriginsTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $StatisticsOriginsTable,
          StatisticsOrigin,
          $$StatisticsOriginsTableFilterComposer,
          $$StatisticsOriginsTableOrderingComposer,
          $$StatisticsOriginsTableAnnotationComposer,
          $$StatisticsOriginsTableCreateCompanionBuilder,
          $$StatisticsOriginsTableUpdateCompanionBuilder,
          (
            StatisticsOrigin,
            BaseReferences<
              _$PikoDatabase,
              $StatisticsOriginsTable,
              StatisticsOrigin
            >,
          ),
          StatisticsOrigin,
          PrefetchHooks Function()
        > {
  $$StatisticsOriginsTableTableManager(
    _$PikoDatabase db,
    $StatisticsOriginsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StatisticsOriginsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StatisticsOriginsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StatisticsOriginsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                Value<String> startedAt = const Value.absent(),
                Value<String> learningDate = const Value.absent(),
              }) => StatisticsOriginsCompanion(
                singleton: singleton,
                startedAt: startedAt,
                learningDate: learningDate,
              ),
          createCompanionCallback:
              ({
                Value<int> singleton = const Value.absent(),
                required String startedAt,
                required String learningDate,
              }) => StatisticsOriginsCompanion.insert(
                singleton: singleton,
                startedAt: startedAt,
                learningDate: learningDate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StatisticsOriginsTable, StatisticsOrigin>(table),
                  BaseReferences<
                    _$PikoDatabase,
                    $StatisticsOriginsTable,
                    StatisticsOrigin
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StatisticsOriginsTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $StatisticsOriginsTable,
      StatisticsOrigin,
      $$StatisticsOriginsTableFilterComposer,
      $$StatisticsOriginsTableOrderingComposer,
      $$StatisticsOriginsTableAnnotationComposer,
      $$StatisticsOriginsTableCreateCompanionBuilder,
      $$StatisticsOriginsTableUpdateCompanionBuilder,
      (
        StatisticsOrigin,
        BaseReferences<
          _$PikoDatabase,
          $StatisticsOriginsTable,
          StatisticsOrigin
        >,
      ),
      StatisticsOrigin,
      PrefetchHooks Function()
    >;
typedef $$StatisticsActivityTableCreateCompanionBuilder =
    StatisticsActivityCompanion Function({
      required String creditKey,
      required String mode,
      required String occurredAt,
      required String learningDate,
      Value<int> rowid,
    });
typedef $$StatisticsActivityTableUpdateCompanionBuilder =
    StatisticsActivityCompanion Function({
      Value<String> creditKey,
      Value<String> mode,
      Value<String> occurredAt,
      Value<String> learningDate,
      Value<int> rowid,
    });

class $$StatisticsActivityTableFilterComposer
    extends Composer<_$PikoDatabase, $StatisticsActivityTable> {
  $$StatisticsActivityTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get creditKey => $composableBuilder(
    column: $table.creditKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learningDate => $composableBuilder(
    column: $table.learningDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StatisticsActivityTableOrderingComposer
    extends Composer<_$PikoDatabase, $StatisticsActivityTable> {
  $$StatisticsActivityTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get creditKey => $composableBuilder(
    column: $table.creditKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learningDate => $composableBuilder(
    column: $table.learningDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StatisticsActivityTableAnnotationComposer
    extends Composer<_$PikoDatabase, $StatisticsActivityTable> {
  $$StatisticsActivityTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get creditKey =>
      $composableBuilder(column: $table.creditKey, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get learningDate => $composableBuilder(
    column: $table.learningDate,
    builder: (column) => column,
  );
}

class $$StatisticsActivityTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $StatisticsActivityTable,
          StatisticsActivityData,
          $$StatisticsActivityTableFilterComposer,
          $$StatisticsActivityTableOrderingComposer,
          $$StatisticsActivityTableAnnotationComposer,
          $$StatisticsActivityTableCreateCompanionBuilder,
          $$StatisticsActivityTableUpdateCompanionBuilder,
          (
            StatisticsActivityData,
            BaseReferences<
              _$PikoDatabase,
              $StatisticsActivityTable,
              StatisticsActivityData
            >,
          ),
          StatisticsActivityData,
          PrefetchHooks Function()
        > {
  $$StatisticsActivityTableTableManager(
    _$PikoDatabase db,
    $StatisticsActivityTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StatisticsActivityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StatisticsActivityTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StatisticsActivityTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> creditKey = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> occurredAt = const Value.absent(),
                Value<String> learningDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StatisticsActivityCompanion(
                creditKey: creditKey,
                mode: mode,
                occurredAt: occurredAt,
                learningDate: learningDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String creditKey,
                required String mode,
                required String occurredAt,
                required String learningDate,
                Value<int> rowid = const Value.absent(),
              }) => StatisticsActivityCompanion.insert(
                creditKey: creditKey,
                mode: mode,
                occurredAt: occurredAt,
                learningDate: learningDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StatisticsActivityTable, StatisticsActivityData>(
                    table,
                  ),
                  BaseReferences<
                    _$PikoDatabase,
                    $StatisticsActivityTable,
                    StatisticsActivityData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StatisticsActivityTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $StatisticsActivityTable,
      StatisticsActivityData,
      $$StatisticsActivityTableFilterComposer,
      $$StatisticsActivityTableOrderingComposer,
      $$StatisticsActivityTableAnnotationComposer,
      $$StatisticsActivityTableCreateCompanionBuilder,
      $$StatisticsActivityTableUpdateCompanionBuilder,
      (
        StatisticsActivityData,
        BaseReferences<
          _$PikoDatabase,
          $StatisticsActivityTable,
          StatisticsActivityData
        >,
      ),
      StatisticsActivityData,
      PrefetchHooks Function()
    >;
typedef $$SpeedCompletionReceiptsTableCreateCompanionBuilder =
    SpeedCompletionReceiptsCompanion Function({
      required String entryId,
      required String direction,
      required String completedAt,
      required String learningDate,
      Value<int> rowid,
    });
typedef $$SpeedCompletionReceiptsTableUpdateCompanionBuilder =
    SpeedCompletionReceiptsCompanion Function({
      Value<String> entryId,
      Value<String> direction,
      Value<String> completedAt,
      Value<String> learningDate,
      Value<int> rowid,
    });

class $$SpeedCompletionReceiptsTableFilterComposer
    extends Composer<_$PikoDatabase, $SpeedCompletionReceiptsTable> {
  $$SpeedCompletionReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learningDate => $composableBuilder(
    column: $table.learningDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpeedCompletionReceiptsTableOrderingComposer
    extends Composer<_$PikoDatabase, $SpeedCompletionReceiptsTable> {
  $$SpeedCompletionReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learningDate => $composableBuilder(
    column: $table.learningDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpeedCompletionReceiptsTableAnnotationComposer
    extends Composer<_$PikoDatabase, $SpeedCompletionReceiptsTable> {
  $$SpeedCompletionReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get learningDate => $composableBuilder(
    column: $table.learningDate,
    builder: (column) => column,
  );
}

class $$SpeedCompletionReceiptsTableTableManager
    extends
        RootTableManager<
          _$PikoDatabase,
          $SpeedCompletionReceiptsTable,
          SpeedCompletionReceipt,
          $$SpeedCompletionReceiptsTableFilterComposer,
          $$SpeedCompletionReceiptsTableOrderingComposer,
          $$SpeedCompletionReceiptsTableAnnotationComposer,
          $$SpeedCompletionReceiptsTableCreateCompanionBuilder,
          $$SpeedCompletionReceiptsTableUpdateCompanionBuilder,
          (
            SpeedCompletionReceipt,
            BaseReferences<
              _$PikoDatabase,
              $SpeedCompletionReceiptsTable,
              SpeedCompletionReceipt
            >,
          ),
          SpeedCompletionReceipt,
          PrefetchHooks Function()
        > {
  $$SpeedCompletionReceiptsTableTableManager(
    _$PikoDatabase db,
    $SpeedCompletionReceiptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeedCompletionReceiptsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SpeedCompletionReceiptsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SpeedCompletionReceiptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> completedAt = const Value.absent(),
                Value<String> learningDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeedCompletionReceiptsCompanion(
                entryId: entryId,
                direction: direction,
                completedAt: completedAt,
                learningDate: learningDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String direction,
                required String completedAt,
                required String learningDate,
                Value<int> rowid = const Value.absent(),
              }) => SpeedCompletionReceiptsCompanion.insert(
                entryId: entryId,
                direction: direction,
                completedAt: completedAt,
                learningDate: learningDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SpeedCompletionReceiptsTable,
                    SpeedCompletionReceipt
                  >(table),
                  BaseReferences<
                    _$PikoDatabase,
                    $SpeedCompletionReceiptsTable,
                    SpeedCompletionReceipt
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpeedCompletionReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$PikoDatabase,
      $SpeedCompletionReceiptsTable,
      SpeedCompletionReceipt,
      $$SpeedCompletionReceiptsTableFilterComposer,
      $$SpeedCompletionReceiptsTableOrderingComposer,
      $$SpeedCompletionReceiptsTableAnnotationComposer,
      $$SpeedCompletionReceiptsTableCreateCompanionBuilder,
      $$SpeedCompletionReceiptsTableUpdateCompanionBuilder,
      (
        SpeedCompletionReceipt,
        BaseReferences<
          _$PikoDatabase,
          $SpeedCompletionReceiptsTable,
          SpeedCompletionReceipt
        >,
      ),
      SpeedCompletionReceipt,
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
  $$VocabularyExamplesTableTableManager get vocabularyExamples =>
      $$VocabularyExamplesTableTableManager(_db, _db.vocabularyExamples);
  $$LearningItemsTableTableManager get learningItems =>
      $$LearningItemsTableTableManager(_db, _db.learningItems);
  $$RegularReviewsTableTableManager get regularReviews =>
      $$RegularReviewsTableTableManager(_db, _db.regularReviews);
  $$RetryObligationsTableTableManager get retryObligations =>
      $$RetryObligationsTableTableManager(_db, _db.retryObligations);
  $$ScopeAnswerOrdinalsTableTableManager get scopeAnswerOrdinals =>
      $$ScopeAnswerOrdinalsTableTableManager(_db, _db.scopeAnswerOrdinals);
  $$LearningIdentitySequenceTableTableManager get learningIdentitySequence =>
      $$LearningIdentitySequenceTableTableManager(
        _db,
        _db.learningIdentitySequence,
      );
  $$VocabularyOrderSequenceTableTableManager get vocabularyOrderSequence =>
      $$VocabularyOrderSequenceTableTableManager(
        _db,
        _db.vocabularyOrderSequence,
      );
  $$CategoryDimensionsTableTableManager get categoryDimensions =>
      $$CategoryDimensionsTableTableManager(_db, _db.categoryDimensions);
  $$CategoryValuesTableTableManager get categoryValues =>
      $$CategoryValuesTableTableManager(_db, _db.categoryValues);
  $$CategoryGroupPreferencesTableTableManager get categoryGroupPreferences =>
      $$CategoryGroupPreferencesTableTableManager(
        _db,
        _db.categoryGroupPreferences,
      );
  $$VocabularyCategoryAssignmentsTableTableManager
  get vocabularyCategoryAssignments =>
      $$VocabularyCategoryAssignmentsTableTableManager(
        _db,
        _db.vocabularyCategoryAssignments,
      );
  $$StatisticsOriginsTableTableManager get statisticsOrigins =>
      $$StatisticsOriginsTableTableManager(_db, _db.statisticsOrigins);
  $$StatisticsActivityTableTableManager get statisticsActivity =>
      $$StatisticsActivityTableTableManager(_db, _db.statisticsActivity);
  $$SpeedCompletionReceiptsTableTableManager get speedCompletionReceipts =>
      $$SpeedCompletionReceiptsTableTableManager(
        _db,
        _db.speedCompletionReceipts,
      );
}
