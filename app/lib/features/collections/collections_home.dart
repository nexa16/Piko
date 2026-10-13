import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/piko_theme.dart';
import 'collection_detail.dart';
import 'create_collection.dart';

class CollectionsHome extends StatefulWidget {
  const CollectionsHome({required this.repository, super.key});
  final CollectionsRepository repository;
  @override
  State<CollectionsHome> createState() => _CollectionsHomeState();
}

class _CollectionsHomeState extends State<CollectionsHome> {
  late Stream<List<CollectionRecord>> _collections;
  @override
  void initState() {
    super.initState();
    _collections = widget.repository.watchAll();
  }

  @override
  void didUpdateWidget(CollectionsHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _collections = widget.repository.watchAll();
    }
  }

  Future<void> _createCollection() async {
    final created = await showPikoDialog<CollectionRecord>(
      context,
      builder: (_) => CreateCollectionDialog(repository: widget.repository),
    );
    if (mounted && created != null) {
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
  }

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
                onPressed: _createCollection,
              ),
            ),
            StreamBuilder<List<CollectionRecord>>(
              stream: _collections,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return CollectionLoadFailure(
                    onRetry: () => setState(() {
                      _collections = widget.repository.watchAll();
                    }),
                  );
                }
                if (!snapshot.hasData ||
                    snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.connectionState == ConnectionState.none) {
                  return Text(copy.text('collection.loading'));
                }
                if (snapshot.data!.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: pikoDesign.dimension('spacing.3'),
                    ),
                    child: PikoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            copy.text('home.emptyDescription'),
                            style: TextStyle(
                              fontSize: pikoDesign.dimension('typography.body'),
                              height: pikoDesign.dimension(
                                'components.emptyState.descriptionLineHeight',
                              ),
                              color: pikoDesign.color('muted'),
                            ),
                          ),
                          SizedBox(height: pikoDesign.dimension('spacing.5')),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: PikoButton(
                              label: copy.text('action.firstCollection'),
                              onPressed: _createCollection,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final collection in snapshot.data!)
                      Padding(
                        padding: EdgeInsets.only(
                          top: pikoDesign.dimension('spacing.3'),
                        ),
                        child: _CollectionTile(
                          collection: collection,
                          key: ValueKey('collection-${collection.id}'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CollectionDetail(
                                repository: widget.repository,
                                collectionId: collection.id,
                              ),
                            ),
                          ),
                        ),
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

class _CollectionTile extends StatefulWidget {
  const _CollectionTile({
    required this.collection,
    required this.onTap,
    super.key,
  });
  final CollectionRecord collection;
  final VoidCallback onTap;
  @override
  State<_CollectionTile> createState() => _CollectionTileState();
}

class _CollectionTileState extends State<_CollectionTile> {
  bool focused = false;
  @override
  Widget build(BuildContext context) {
    final languages = collectionLanguagePair(context, widget.collection);
    return Semantics(
      button: true,
      onTap: widget.onTap,
      label: PikoCopyScope.of(context).text('collection.open', {
        'name': widget.collection.name,
        'languages': languages,
      }),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(
            pikoDesign.dimension('radii.card'),
          ),
          onTap: widget.onTap,
          onFocusChange: (value) => setState(() {
            focused = value;
          }),
          child: ExcludeSemantics(
            child: PikoCard(
              focused: focused,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(widget.collection.name), Text(languages)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
