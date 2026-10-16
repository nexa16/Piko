import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/platform/vocabulary_json_platform.dart';

void main() {
  test('cancel open/save is not an error; UTF-8 round trip is exact', () async {
    final cancelled = SystemVocabularyJsonPlatform(
      pick: () async => null,
      save: (_) async => false,
    );
    expect(await cancelled.readFile(), isNull);
    expect(await cancelled.saveFile('{}'), isFalse);
    const text = '{"한국어":"Maße"}';
    final encoded = utf8.encode(text);
    Uint8List? written;
    final adapter = SystemVocabularyJsonPlatform(
      pick: () async => JsonFileInput(
        bytes: Stream.fromIterable([encoded.sublist(0, 4), encoded.sublist(4)]),
      ),
      save: (bytes) async {
        written = bytes;
        return true;
      },
    );
    expect(await adapter.readFile(), text);
    expect(await adapter.saveFile(text), isTrue);
    expect(written, encoded);
  });

  test(
    'known oversized files are rejected before reading the stream',
    () async {
      var read = false;
      Stream<List<int>> bytes() async* {
        read = true;
        yield [1];
      }

      final adapter = SystemVocabularyJsonPlatform(
        pick: () async => JsonFileInput(
          length: VocabularyJsonFormat.maxImportBytes + 1,
          bytes: bytes(),
        ),
      );
      await expectLater(
        adapter.readFile(),
        throwsA(JsonPlatformFailure.tooLarge),
      );
      expect(read, isFalse);
    },
  );

  test('unknown or lying file lengths are bounded while streaming', () async {
    var cancelled = false;
    Stream<List<int>> bytes() async* {
      try {
        yield Uint8List(VocabularyJsonFormat.maxImportBytes);
        yield [1];
        fail('The stream must stop at the size limit');
      } finally {
        cancelled = true;
      }
    }

    final adapter = SystemVocabularyJsonPlatform(
      pick: () async => JsonFileInput(length: 0, bytes: bytes()),
    );
    await expectLater(
      adapter.readFile(),
      throwsA(JsonPlatformFailure.tooLarge),
    );
    expect(cancelled, isTrue);
  });

  test(
    'malformed UTF-8 and permission failures are recoverable typed errors',
    () async {
      final malformed = SystemVocabularyJsonPlatform(
        pick: () async => JsonFileInput(bytes: Stream.value([0xff])),
      );
      await expectLater(
        malformed.readFile(),
        throwsA(JsonPlatformFailure.invalidUtf8),
      );
      final unavailable = SystemVocabularyJsonPlatform(
        pick: () async => throw PlatformException(code: 'permission'),
        save: (_) async => throw PlatformException(code: 'permission'),
      );
      await expectLater(
        unavailable.readFile(),
        throwsA(JsonPlatformFailure.readFailed),
      );
      await expectLater(
        unavailable.saveFile('{}'),
        throwsA(JsonPlatformFailure.writeFailed),
      );
    },
  );

  test(
    'clipboard is explicit, counts UTF-8 bytes and preserves copied text',
    () async {
      String? copied;
      var reads = 0;
      final adapter = SystemVocabularyJsonPlatform(
        clipboardRead: () async {
          reads++;
          return '학교';
        },
        clipboardWrite: (text) async => copied = text,
      );
      expect(reads, 0);
      expect(await adapter.readClipboard(), '학교');
      expect(reads, 1);
      await adapter.copyText('{"ß":"ss"}');
      expect(copied, '{"ß":"ss"}');
      final oversized = SystemVocabularyJsonPlatform(
        clipboardRead: () async => '학' * 333334,
      );
      await expectLater(
        oversized.readClipboard(),
        throwsA(JsonPlatformFailure.tooLarge),
      );
      final denied = SystemVocabularyJsonPlatform(
        clipboardRead: () async => throw PlatformException(code: 'denied'),
        clipboardWrite: (_) async => throw PlatformException(code: 'denied'),
      );
      await expectLater(
        denied.readClipboard(),
        throwsA(JsonPlatformFailure.clipboardFailed),
      );
      await expectLater(
        denied.copyText('{}'),
        throwsA(JsonPlatformFailure.clipboardFailed),
      );
    },
  );
}
