import 'package:integration_test/integration_test.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/features/collections/collection_compact_action.dart';
import '../test/ui/collection_search_field_test.dart' as search;
import '../test/ui/selected_deletion_test.dart' as deletion;
import '../test/ui/collection_compact_header_test.dart' as header;

// Uses isolated in-memory fixture repositories, never the ordinary app database.
// Exercise the real Flutter/native input channel and production Collection UI.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  search.main();
  deletion.main(nativeViewport: true);
  testWidgets(
    'native viewport keeps compact focus and scroll during hidden-result refresh',
    (tester) async {
      final h = header.HeaderHarness();
      await h.mount(tester, nativeView: true);
      await h.collapse(tester);
      final action = tester.widget<CollectionCompactAction>(
        header.compactReview,
      );
      action.focusNode.requestFocus();
      await tester.pumpAndSettle();
      final offset = h.position(tester).pixels;
      final pending = h.service.gate = Completer<CollectionQuerySnapshot>();
      h.binding.refresh();
      await tester.pump(const Duration(milliseconds: 160));
      expect(h.binding.showLoading, isTrue);
      expect(
        tester.widget<CollectionCompactAction>(header.compactReview).count,
        '19',
      );
      expect(action.focusNode.hasFocus, isTrue);
      expect(h.position(tester).pixels, closeTo(offset, .5));
      pending.completeError(StateError('synthetic read failure'));
      await tester.pumpAndSettle();
      expect(action.focusNode.hasFocus, isTrue);
      expect(h.position(tester).pixels, closeTo(offset, .5));
      h.service.gate = null;
      h.service.value = header.headerProjection(
        forward: 0,
        reverse: 0,
        speedForward: 0,
        speedReverse: 0,
      );
      h.binding.refresh();
      await tester.pumpAndSettle();
      expect(
        tester.widget<CollectionCompactAction>(header.compactReview).count,
        '0',
      );
    },
  );
}
