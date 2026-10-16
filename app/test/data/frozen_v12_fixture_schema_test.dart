import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../integration_test/support/frozen_v12_schema.dart';

void main() {
  test(
    'native migration fixture SQL exactly matches frozen schema12 export',
    () async {
      final schema =
          jsonDecode(
                await File(
                  'drift_schemas/drift_schema_v12.json',
                ).readAsString(),
              )
              as Map;
      final sql = (schema['fixed_sql'] as List)
          .map((group) => ((group as Map)['sql'] as List).single['sql'])
          .toList();
      expect(frozenV12Sql, sql);
    },
  );
}
