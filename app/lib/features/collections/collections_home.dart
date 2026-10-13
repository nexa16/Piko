import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import 'create_collection.dart';

class CollectionsHome extends StatelessWidget {
  const CollectionsHome({required this.repository, super.key});
  final CollectionsRepository repository;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Scaffold(
      body: PikoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PikoHeading(title: copy.text('home.collections')),
            Align(
              alignment: Alignment.centerRight,
              child: PikoButton(
                label: copy.text('action.new'),
                icon: const PikoIcon(PikoIconName.plus),
                onPressed: () async {
                  final created = await showPikoDialog<CollectionRecord>(
                    context,
                    builder: (_) =>
                        CreateCollectionDialog(repository: repository),
                  );
                  if (context.mounted && created != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          PikoCopyScope.of(
                            context,
                          ).text('collection.created', {'name': created.name}),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
