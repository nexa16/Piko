import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_form.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';

class CollectionSettingsOverview extends StatefulWidget {
  const CollectionSettingsOverview({
    required this.repository,
    required this.settingsBuilder,
    super.key,
  });
  final CollectionsRepository repository;
  final Widget Function(BuildContext, CollectionRecord) settingsBuilder;
  @override
  State<CollectionSettingsOverview> createState() =>
      _CollectionSettingsOverviewState();
}

class _CollectionSettingsOverviewState
    extends State<CollectionSettingsOverview> {
  late Stream<List<CollectionRecord>> collections = widget.repository
      .watchAll();
  @override
  void didUpdateWidget(CollectionSettingsOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      collections = widget.repository.watchAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Scaffold(
      body: PikoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PikoFormHeading(
              title: copy.text('settingsPreview.collections'),
              leading: PikoIconButton(
                icon: const PikoIcon(PikoIconName.arrowLeft),
                semanticLabel: copy.text('common.back'),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            StreamBuilder<List<CollectionRecord>>(
              stream: collections,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      Text(copy.text('collection.loadFailed')),
                      PikoButton(
                        label: copy.text('action.retry'),
                        onPressed: () => setState(
                          () => collections = widget.repository.watchAll(),
                        ),
                      ),
                    ],
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !snapshot.hasData) {
                  return Text(copy.text('collection.loading'));
                }
                if (snapshot.data!.isEmpty) {
                  return Text(copy.text('settings.noCollections'));
                }
                return PikoFormGroup(
                  children: [
                    for (final collection in snapshot.data!)
                      PikoNavigationRow(
                        key: ValueKey('collection-settings-${collection.id}'),
                        title: collection.name,
                        subtitle:
                            '${copy.text(collection.targetLanguage.copyKey)} · ${copy.text(collection.nativeLanguage.copyKey)}',
                        onTap: () {
                          if (ModalRoute.of(context)?.isCurrent == true) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    widget.settingsBuilder(context, collection),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
