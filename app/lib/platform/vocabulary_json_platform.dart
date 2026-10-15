import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../data/vocabulary_json.dart';

abstract interface class VocabularyJsonPlatform {
  Future<String?> readFile();
  Future<String?> readClipboard();
  Future<void> copyText(String text);

  /// False means the system save picker was cancelled, not a write failure.
  Future<bool> saveFile(String json);
}

enum JsonPlatformFailure {
  tooLarge,
  invalidUtf8,
  readFailed,
  writeFailed,
  clipboardFailed,
}

final class JsonFileInput {
  const JsonFileInput({required this.bytes, this.length});
  final Stream<List<int>> bytes;
  final int? length;
}

/// Native operations are injectable; UI never reads paths or requests broad
/// storage permissions. The OS owns destination selection and overwrite consent.
final class SystemVocabularyJsonPlatform implements VocabularyJsonPlatform {
  const SystemVocabularyJsonPlatform({
    this.pick = _pick,
    this.save = _save,
    this.clipboardRead = _clipboardRead,
    this.clipboardWrite = _clipboardWrite,
  });
  final Future<JsonFileInput?> Function() pick;
  final Future<bool> Function(Uint8List bytes) save;
  final Future<String?> Function() clipboardRead;
  final Future<void> Function(String text) clipboardWrite;

  static Future<JsonFileInput?> _pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    return JsonFileInput(
      bytes: file.readAsByteStream(),
      length: await file.length(),
    );
  }

  static Future<bool> _save(Uint8List bytes) async =>
      await FilePicker.saveFile(
        fileName: 'piko-vocabulary.json',
        bytes: bytes,
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      ) !=
      null;

  static Future<String?> _clipboardRead() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  static Future<void> _clipboardWrite(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<String?> readFile() async {
    try {
      final file = await pick();
      if (file == null) return null;
      if ((file.length ?? 0) > VocabularyJsonFormat.maxImportBytes) {
        throw JsonPlatformFailure.tooLarge;
      }
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in file.bytes) {
        if (buffer.length + chunk.length >
            VocabularyJsonFormat.maxImportBytes) {
          throw JsonPlatformFailure.tooLarge;
        }
        buffer.add(chunk);
      }
      return utf8.decode(buffer.takeBytes(), allowMalformed: false);
    } on JsonPlatformFailure {
      rethrow;
    } on FormatException {
      throw JsonPlatformFailure.invalidUtf8;
    } catch (_) {
      throw JsonPlatformFailure.readFailed;
    }
  }

  @override
  Future<String?> readClipboard() async {
    try {
      final text = await clipboardRead();
      if (text != null &&
          utf8.encode(text).length > VocabularyJsonFormat.maxImportBytes) {
        throw JsonPlatformFailure.tooLarge;
      }
      return text;
    } on JsonPlatformFailure {
      rethrow;
    } catch (_) {
      throw JsonPlatformFailure.clipboardFailed;
    }
  }

  @override
  Future<void> copyText(String text) async {
    try {
      await clipboardWrite(text);
    } catch (_) {
      throw JsonPlatformFailure.clipboardFailed;
    }
  }

  @override
  Future<bool> saveFile(String json) async {
    try {
      return await save(Uint8List.fromList(utf8.encode(json)));
    } catch (_) {
      throw JsonPlatformFailure.writeFailed;
    }
  }
}
