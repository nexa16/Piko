import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../categories_repository.dart';
import '../collections_repository.dart';
import '../vocabulary_content.dart';
import '../vocabulary_repository.dart';
import 'ai_contract.dart';

enum AiJobState {
  preparing,
  running,
  paused,
  unknown,
  completed,
  failed,
  cancelling,
  cancelled,
  expired,
  detached,
}

final class AiJobStatus {
  AiJobStatus(this.data) {
    if (data['jobId'] is! String ||
        data['generation'] is! int ||
        data['state'] is! String ||
        data['expiresAt'] is! String) {
      throw AiFailure.invalidResponse;
    }
    DateTime.parse(data['expiresAt']! as String);
    if ((data['generation']! as int) < 0) throw AiFailure.invalidResponse;
    state;
  }
  final Map<String, Object?> data;
  String get id => data['jobId']! as String;
  int get generation => data['generation']! as int;
  AiJobState get state => AiJobState.values.firstWhere(
    (e) => e.name == data['state'],
    orElse: () => throw AiFailure.invalidResponse,
  );
  DateTime get expiresAt =>
      DateTime.parse(data['expiresAt']! as String).toUtc();
  int get processed => (data['processed'] as num?)?.toInt() ?? 0;
  int get total => (data['total'] as num?)?.toInt() ?? 0;
  bool get terminal => {
    AiJobState.completed,
    AiJobState.cancelled,
    AiJobState.expired,
    AiJobState.failed,
    AiJobState.detached,
  }.contains(state);
}

/// Versioned review inputs, independent from the smaller provider transport.
/// Learning/state/history never enter the digest or result replacement.
final class AiReviewManifest {
  AiReviewManifest(this.request) {
    if (request.action != AiAction.review ||
        request.snapshot.collection == null) {
      throw AiFailure.dependency;
    }
  }
  final AiRequest request;
  Map<String, Object?> get document {
    final c = request.snapshot.collection!;
    final entries = request.snapshot.entries.toList()
      ..sort((a, b) => a.record.id.compareTo(b.record.id));
    final groups = request.snapshot.groups.toList()
      ..sort((a, b) => a.dimension.id.compareTo(b.dimension.id));
    final options = request.options ?? const AiOptions();
    return {
      'version': 1,
      'collection': {
        'id': c.id,
        'name': c.name,
        'targetLanguage': c.targetLanguage.toJson(),
        'nativeLanguage': c.nativeLanguage.toJson(),
        'level': c.level,
      },
      'options': {
        ...options.toJson(),
        'filters': {
          for (final f in options.filters.entries)
            f.key: f.value.toList()..sort(),
        },
      },
      'allowNewGroups': request.allowGroups,
      'allowNewValues': request.allowValues,
      'entries': [
        for (final e in entries)
          {
            ...e.toJson(),
            'active': e.record.active,
            'hintVisibility': e.record.content.hintVisibility.name,
          },
      ],
      'groups': [
        for (final g in groups)
          {
            ...g.toJson(),
            'values': [
              for (final v
                  in (g.values.toList()..sort((a, b) => a.id.compareTo(b.id))))
                {'id': v.id, 'name': v.name},
            ],
          },
      ],
    };
  }

  String get canonical => aiContentKey(document);
  String get digest => sha256.convert(utf8.encode(canonical)).toString();
  Map<String, Object?> get persisted => {
    'manifest': document,
    'requestId': request.id,
    'issuedAt': request.issuedAt.toUtc().toIso8601String(),
    'fullContentKey': request.fullContentKey,
    'collectionName': request.snapshot.collection!.name,
  };
  static AiReviewManifest restore(Map<String, Object?> saved) {
    final m = aiObject(saved['manifest']);
    if (m['version'] != 1) throw AiFailure.invalidResponse;
    final c = aiObject(m['collection']);
    final collection = CollectionRecord(
      id: aiText(c['id']),
      name: aiText(c['name'] ?? saved['collectionName']),
      targetLanguage: VocabularyLanguage.fromJson(c['targetLanguage']),
      nativeLanguage: VocabularyLanguage.fromJson(c['nativeLanguage']),
      level: aiText(c['level']),
    );
    final o = aiObject(m['options']);
    final filters = aiObject(o['filters']);
    final options = AiOptions(
      level: aiText(o['level']),
      goals: aiList(o['goals']).cast<String>().toSet(),
      checks: aiList(o['checks']).cast<String>().toSet(),
      categoryMode: aiText(o['categoryMode']),
      filters: {
        for (final f in filters.entries)
          f.key: aiList(f.value).cast<String>().toSet(),
      },
    );
    final groups = <AiGroup>[];
    for (final raw in aiList(m['groups'])) {
      final g = aiObject(raw), id = aiText(aiObject(raw)['id']);
      groups.add(
        AiGroup(
          CategoryDimensionRecord(
            id: id,
            collectionId: collection.id,
            name: aiText(g['name']),
            mode: CategoryMode.values.byName(aiText(g['mode'])),
            position: groups.length,
            acquisitionSource: g['acquisitionSource'] == true,
          ),
          [
            for (final v in aiList(g['values']).map(aiObject))
              CategoryValueRecord(
                id: aiText(v['id']),
                dimensionId: id,
                name: aiText(v['name']),
                position: 0,
              ),
          ],
        ),
      );
    }
    final entries = <AiEntry>[];
    for (final raw in aiList(m['entries'])) {
      final e = aiObject(raw),
          assignments = aiObject(aiObject(raw)['assignments']);
      entries.add(
        AiEntry(
          VocabularyRecord(
            id: aiText(e['id']),
            collectionId: collection.id,
            targetText: aiText(e['target']),
            nativeText: aiText(e['native']),
            active: e['active'] == true,
            content: VocabularyContent(
              hintText: e['hint'] as String?,
              hintVisibility: HintVisibility.values.byName(
                aiText(e['hintVisibility']),
              ),
              examples: [
                for (final p in aiList(e['examples']).map(aiObject))
                  ExamplePair(
                    targetText: aiText(p['target']),
                    nativeText: aiText(p['native']),
                  ),
              ],
            ),
          ),
          {
            for (final a in assignments.entries)
              a.key: aiList(a.value).cast<String>().toSet(),
          },
        ),
      );
    }
    return AiReviewManifest(
      AiRequest(
        id: aiText(saved['requestId']),
        action: AiAction.review,
        options: options,
        issuedAt: DateTime.parse(aiText(saved['issuedAt'])),
        fullContentKey: saved['fullContentKey'] as String?,
        allowGroups: m['allowNewGroups'] == true,
        allowValues: m['allowNewValues'] == true,
        snapshot: AiSnapshot(
          collectionId: collection.id,
          targetLanguage:
              collection.targetLanguage.customName ??
              collection.targetLanguage.code,
          nativeLanguage:
              collection.nativeLanguage.customName ??
              collection.nativeLanguage.code,
          entries: entries,
          groups: groups,
          collection: collection,
        ),
      ),
    );
  }
}

abstract interface class AiReviewJobProvider {
  Future<Map<String, Object?>> reviewJob(
    String action,
    Map<String, Object?> data,
  );
}

abstract interface class AiReviewJobStore {
  Future<AiLocalReviewJob?> reviewJobFor(
    String collectionId,
    String installationId,
  );
  Future<AiLocalReviewJob> prepareReviewJob({
    required String collectionId,
    required String installationId,
    required int maxCostCents,
    required AiOptions options,
    bool allowGroups = true,
    bool allowValues = true,
  });
  Future<AiLocalReviewJob> saveReviewStatus(
    AiLocalReviewJob job,
    AiJobStatus status,
  );
  Future<void> markReviewCancellation(AiLocalReviewJob job);
  Future<void> saveReviewResult(
    AiLocalReviewJob job,
    Map<String, Object?> result,
  );
}

abstract interface class AiReviewJobsSupport {
  AiReviewJobStore get reviewJobs;
}

final class AiServiceError implements Exception {
  const AiServiceError(
    this.failure, {
    this.code,
    this.limit,
    this.retryAt,
    this.limitMaximum,
    this.limitRemaining,
    this.limitUnit,
  });
  final AiFailure failure;
  final String? code, limit;
  final DateTime? retryAt;
  final num? limitMaximum, limitRemaining;
  final String? limitUnit;
  static AiServiceError? read(Object? value) {
    if (value is! Map) return null;
    String? safe(Object? s) =>
        s is String && RegExp(r'^[a-zA-Z0-9_.:-]{1,80}$').hasMatch(s)
        ? s
        : null;
    final cause = safe(value['limitType']) ?? safe(value['limit']);
    return AiServiceError(
      AiFailure.limit,
      code: safe(value['code']),
      limit: cause,
      retryAt: value['retryAt'] is String
          ? DateTime.tryParse(value['retryAt'] as String)
          : null,
      limitMaximum: value['limitMaximum'] is num
          ? value['limitMaximum'] as num
          : null,
      limitRemaining: value['limitRemaining'] is num
          ? value['limitRemaining'] as num
          : null,
      limitUnit: safe(value['limitUnit']),
    );
  }
}

final class AiLocalReviewJob {
  const AiLocalReviewJob({
    required this.id,
    required this.installationId,
    required this.manifest,
    required this.maxCostCents,
    required this.status,
    this.cancelPending = false,
    this.result,
  });
  final String id, installationId;
  final AiReviewManifest manifest;
  final int maxCostCents;
  final AiJobStatus status;
  final bool cancelPending;
  final Map<String, Object?>? result;
}
