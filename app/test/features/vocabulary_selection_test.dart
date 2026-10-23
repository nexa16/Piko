import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/vocabulary/vocabulary_selection.dart';

void main() {
  test('group tri-state deduplicates matches and retains outside selection', () {
    final selection = VocabularySelection();
    addTearDown(selection.dispose);
    selection.toggle('hidden');
    selection.toggle('one');
    expect(selection.groupState(['one', 'two', 'two']), isNull);
    selection.toggleGroup(['one', 'two', 'two']);
    expect(selection.groupState(['one', 'two']), isTrue);
    expect(selection.ids, {'hidden', 'one', 'two'});
    selection.toggleGroup(['one', 'two', 'two']);
    expect(selection.groupState(['one', 'two']), isFalse);
    expect(selection.ids, {'hidden'});
    selection.toggleGroup(const []);
    expect(selection.ids, {'hidden'});
  });
  test(
    'UUID selection retains hidden identities, unions matching all and permits active zero',
    () {
      final selection = VocabularySelection();
      addTearDown(selection.dispose);
      selection.toggle('one');
      selection.selectAll(['two', 'two', 'three']);
      expect(selection.ids, {'one', 'two', 'three'});
      expect(selection.hidden(['three']), 2);
      selection.toggle('one');
      selection.toggle('two');
      selection.toggle('three');
      expect(selection.active, isTrue);
      expect(selection.ids, isEmpty);
      selection.selectAll(['four']);
      selection.clear();
      expect(selection.active, isFalse);
      expect(selection.ids, isEmpty);
    },
  );
}
