import 'package:flutter/foundation.dart';
import '../../data/vocabulary_content.dart';

enum AiTask { example, hint }

enum AiFailure implements Exception {
  unavailable,
  connection,
  authentication,
  limit,
  busy,
  invalidResponse,
}

/// The complete application payload. Local IDs and existing content never cross
/// this boundary. Authentication is handled separately by the gateway.
final class AiContentRequest {
  const AiContentRequest({
    required this.requestId,
    required this.task,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.targetText,
    required this.nativeText,
  });
  final String requestId,
      targetLanguage,
      nativeLanguage,
      targetText,
      nativeText;
  final AiTask task;
  Map<String, Object> toJson() => {
    'requestId': requestId,
    'task': task.name,
    'targetLanguage': targetLanguage,
    'nativeLanguage': nativeLanguage,
    'targetText': targetText,
    'nativeText': nativeText,
  };
}

sealed class AiContentSuggestion {
  const AiContentSuggestion();
  static AiContentSuggestion decode(Object? value, AiContentRequest request) {
    if (value is! Map ||
        value['requestId'] != request.requestId ||
        value['task'] != request.task.name) {
      throw AiFailure.invalidResponse;
    }
    String text(Object? raw, int limit) {
      if (raw is! String || raw.trim().isEmpty || raw.runes.length > limit) {
        throw AiFailure.invalidResponse;
      }
      return raw.trim();
    }

    if (request.task == AiTask.example && value.length == 3) {
      final pair = value['example'];
      if (pair is Map && pair.length == 2) {
        return AiExample(
          ExamplePair(
            targetText: text(
              pair['targetText'],
              VocabularyContent.maxExampleLength,
            ),
            nativeText: text(
              pair['nativeText'],
              VocabularyContent.maxExampleLength,
            ),
          ),
        );
      }
    } else if (request.task == AiTask.hint && value.length == 3) {
      return AiHint(text(value['hint'], VocabularyContent.maxHintLength));
    }
    throw AiFailure.invalidResponse;
  }
}

final class AiExample extends AiContentSuggestion {
  const AiExample(this.pair);
  final ExamplePair pair;
}

final class AiHint extends AiContentSuggestion {
  const AiHint(this.text);
  final String text;
}

abstract interface class AiContentGateway {
  bool get configured;
  Future<void> connect();
  Future<void> disconnect();
  Future<Object?> generate(AiContentRequest request);
}

/// No gateway initialization, identity or networking occurs at construction.
/// Connecting is a separate, voluntary action after the data-flow explanation.
final class AiAccess extends ChangeNotifier {
  AiAccess(this.gateway);
  final AiContentGateway gateway;
  bool _enabled = false, _busy = false, _disposed = false;
  bool _changingAccess = false;
  int _generation = 0;
  bool get configured => gateway.configured;
  bool get enabled => _enabled;
  bool get busy => _busy || _changingAccess;
  AiFailure? error;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> connect() async {
    if (busy || _disposed) return;
    if (!configured) {
      error = AiFailure.unavailable;
      changed();
      return;
    }
    final generation = _generation;
    _busy = true;
    error = null;
    changed();
    try {
      await gateway.connect();
      if (!_disposed && generation == _generation) _enabled = true;
    } catch (_) {
      if (!_disposed && generation == _generation) error = AiFailure.connection;
    } finally {
      _busy = false;
      changed();
    }
  }

  Future<void> disconnect() async {
    if (_disposed || _changingAccess) return;
    _changingAccess = true;
    _generation++;
    _enabled = false;
    error = null;
    changed();
    try {
      await gateway.disconnect();
    } catch (_) {
      if (!_disposed) error = AiFailure.connection;
    } finally {
      _changingAccess = false;
    }
    changed();
  }

  Future<AiContentSuggestion> generate(AiContentRequest request) async {
    if (!_enabled || _disposed) throw AiFailure.authentication;
    if (busy) throw AiFailure.busy;
    final generation = _generation;
    _busy = true;
    changed();
    try {
      final raw = await gateway.generate(request);
      if (_disposed || generation != _generation || !_enabled) {
        throw AiFailure.authentication;
      }
      return AiContentSuggestion.decode(raw, request);
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw AiFailure.connection;
    } finally {
      _busy = false;
      changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
