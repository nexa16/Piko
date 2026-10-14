import 'dart:convert';
import 'package:fsrs/fsrs.dart' as fsrs;

enum LearningDirection { targetToNative, nativeToTarget }

/// Versioned complete FSRS 2.0.1 card state, with identity checked at the boundary.
abstract final class LearningCardCodec {
  static const version = 1;
  static const _keys = {
    'cardId',
    'state',
    'step',
    'stability',
    'difficulty',
    'due',
    'lastReview',
  };

  static String encode(fsrs.Card card) {
    final json = jsonEncode(card.toMap());
    decode(json, expectedId: card.cardId, formatVersion: version);
    return json;
  }

  static fsrs.Card decode(
    String json, {
    required int expectedId,
    required int formatVersion,
  }) {
    if (formatVersion != version || expectedId <= 0) {
      throw const FormatException(
        'Unsupported learning card format or identity',
      );
    }
    final value = jsonDecode(json);
    if (value is! Map<String, dynamic> ||
        value.length != _keys.length ||
        value['cardId'] is! int ||
        !_keys.every(value.containsKey) ||
        value['cardId'] != expectedId) {
      throw const FormatException('Learning card fields or identity mismatch');
    }
    if (value['state'] is! int || ![1, 2, 3].contains(value['state'])) {
      throw const FormatException('Invalid learning state');
    }
    final step = value['step'];
    if (step != null && (step is! int || step < 0)) {
      throw const FormatException('Invalid learning step');
    }
    if ((value['state'] == 2 && step != null) ||
        (value['state'] != 2 && step == null)) {
      throw const FormatException('Learning step/state mismatch');
    }
    for (final field in ['stability', 'difficulty']) {
      final number = value[field];
      if (number != null &&
          (number is! num || !number.isFinite || number <= 0)) {
        throw FormatException('Invalid $field');
      }
      if (number != null) value[field] = (number as num).toDouble();
    }
    final difficulty = value['difficulty'] as double?;
    final memory = [
      value['stability'],
      value['difficulty'],
      value['lastReview'],
    ];
    if (memory.any((field) => field == null)) {
      if (!memory.every((field) => field == null) ||
          value['state'] != 1 ||
          step != 0) {
        throw const FormatException('Incomplete learning memory state');
      }
    }
    if (difficulty != null && (difficulty < 1 || difficulty > 10)) {
      throw const FormatException('Invalid difficulty');
    }
    for (final field in ['due', 'lastReview']) {
      final stamp = value[field];
      if (stamp == null && field == 'lastReview') continue;
      if (stamp is! String || DateTime.tryParse(stamp)?.isUtc != true) {
        throw FormatException('Invalid UTC $field');
      }
    }
    return fsrs.Card.fromMap(value);
  }
}

final class LearningItemRecord {
  const LearningItemRecord({
    required this.id,
    required this.entryId,
    required this.direction,
    required this.cardJson,
    required this.formatVersion,
    this.generation = 0,
    this.reviewRevision = 0,
  });
  final int id;
  final String entryId;
  final LearningDirection direction;
  final String cardJson;
  final int formatVersion;
  final int generation;
  final int reviewRevision;

  /// Returns an independent mutable library object, never shared with another item.
  fsrs.Card get card {
    if (generation < 0 || reviewRevision < 0 || entryId.trim().isEmpty) {
      throw const FormatException('Invalid learning ownership or generation');
    }
    return LearningCardCodec.decode(
      cardJson,
      expectedId: id,
      formatVersion: formatVersion,
    );
  }
}
