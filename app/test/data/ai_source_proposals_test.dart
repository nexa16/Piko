import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'regular_reviews_test.dart' show Fixture;
import 'ai_service_test.dart' show envelope, edit;
import 'statistics_test.dart' show stored;

void main() {
  for (final action in [AiAction.generate, AiAction.review]) {
    test(
      '${action.name} cannot label an existing card AI-generated through a newly proposed Source group',
      () async {
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        final s = SqliteAiService(f.db, enabled: true),
            r = await SqliteAiService(
              f.db,
              enabled: true,
            ).request(collectionId: f.owner.id, action: action, goal: 'Topic');
        final plan = AiPlan.parse(
          r,
          envelope(
            r,
            groups: [
              {
                'id': 'newSource',
                'name': 'Source',
                'mode': 'multiple',
                'reason': 'Known acquisition',
              },
            ],
            values: [
              {
                'id': 'newAI',
                'groupId': 'newSource',
                'name': 'AI-generated',
                'reason': 'Acquisition route',
              },
            ],
            edits: [
              edit('relabel', f.entry.id, 'assignments', [
                {
                  'groupId': 'newSource',
                  'valueIds': ['newAI'],
                },
              ]),
            ],
          ),
        );
        final before = await stored(f.db);
        await expectLater(
          s.apply(plan, {'newSource', 'newAI', 'relabel'}),
          throwsA(AiFailure.dependency),
        );
        expect(await stored(f.db), before);
      },
    );
  }
}
