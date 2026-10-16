import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collection_view_scope.dart';

void main() {
  test('scopes retain per collection in session, never share or persist', () {
    final store = CollectionViewScopes();
    addTearDown(store.dispose);
    final korean = store.forCollection('ko');
    korean.setSearch('학교');
    korean.setFilters({
      'topic': {'school'},
    });
    expect(identical(korean, store.forCollection('ko')), isTrue);
    expect(store.forCollection('ko').search, '학교');
    expect(store.forCollection('fr').restricted, isFalse);
    final restarted = CollectionViewScopes();
    addTearDown(restarted.dispose);
    expect(restarted.forCollection('ko').restricted, isFalse);
  });

  test(
    'defensive snapshots and independent clearing retain other constraint',
    () {
      final scope = CollectionViewScope();
      addTearDown(scope.dispose);
      var notifications = 0;
      scope.addListener(() => notifications++);
      final values = {'school'};
      scope.setSearch('school');
      scope.setFilters({'topic': values, 'unused': {}});
      values.add('food');
      expect(scope.filters, {
        'topic': {'school'},
      });
      expect(() => scope.filters['topic']!.add('food'), throwsUnsupportedError);
      expect(() => scope.filters.clear(), throwsUnsupportedError);
      scope.setFilters({
        'topic': {'school'},
      });
      expect(notifications, 2);
      scope.setFilters({});
      expect(scope.search, 'school');
      scope.setFilters({
        'topic': {'food'},
      });
      scope.setSearch('');
      expect(scope.filters, {
        'topic': {'food'},
      });
    },
  );
}
