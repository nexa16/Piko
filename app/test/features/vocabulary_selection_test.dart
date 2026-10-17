import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/vocabulary/vocabulary_selection.dart';

void main() {
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
