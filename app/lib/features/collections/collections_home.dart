import 'package:flutter/material.dart';
import '../../core/clock.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_language_badge.dart';
import '../../ui/piko_theme.dart';
import 'collection_detail.dart';
import 'collection_review_count.dart';
import 'collection_review_entry_point.dart';
import 'create_collection.dart';
import '../entry/entry_session_route.dart';
import '../learning/review_launch.dart';
import '../vocabulary/collection_vocabulary_mutations.dart';
import 'collection_entry_count.dart';

class CollectionsHome extends StatefulWidget {
  const CollectionsHome({
    required this.repository,
    this.entrySessionFactory,
    this.vocabularyRepository,
    this.onPendingVocabularyWrites,
    this.vocabularyMutationsFactory,
    this.reviewSessionFactory,
    this.reviewMembershipLoader,
    this.reviewCountPolicy,
    this.reviewCountClock = const SystemPikoClock(),
    this.onOpenSettings,
    super.key,
  }) : assert((reviewMembershipLoader == null) == (reviewCountPolicy == null));
  final CollectionsRepository repository;
  final EntrySessionFactory? entrySessionFactory;
  final VocabularyRepository? vocabularyRepository;
  final ValueChanged<Future<void>>? onPendingVocabularyWrites;
  final CollectionVocabularyMutationsFactory? vocabularyMutationsFactory;
  final ReviewSessionFactory? reviewSessionFactory;
  final CollectionReviewMembershipLoader? reviewMembershipLoader;
  final CollectionReviewCountPolicy? reviewCountPolicy;
  final PikoClock reviewCountClock;
  final VoidCallback? onOpenSettings;
  @override
  State<CollectionsHome> createState() => _CollectionsHomeState();
}

class _CollectionsHomeState extends State<CollectionsHome> {
  late Stream<List<CollectionRecord>> _collections;
  int _reviewIdentity = 0;
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

  Future<void> _openCollection(CollectionRecord collection) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CollectionDetail(
          repository: widget.repository,
          collectionId: collection.id,
          entrySessionFactory: widget.entrySessionFactory,
          reviewSessionFactory: widget.reviewSessionFactory,
          reviewMembershipLoader: widget.reviewMembershipLoader,
          reviewCountPolicy: widget.reviewCountPolicy,
          reviewCountClock: widget.reviewCountClock,
          vocabularyRepository: widget.vocabularyRepository,
          onPendingVocabularyWrites: widget.onPendingVocabularyWrites,
          vocabularyMutationsFactory: widget.vocabularyMutationsFactory,
        ),
      ),
    );
    if (mounted) setState(() => _reviewIdentity++);
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Scaffold(
      body: PikoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    copy.text('app.name'),
                    key: const ValueKey('home-brand'),
                    style: TextStyle(
                      fontSize: pikoDesign.dimension(
                        'components.homeHeader.brandSize',
                      ),
                      fontWeight: pikoDesign.weight(
                        'components.homeHeader.brandWeight',
                      ),
                      letterSpacing: pikoDesign.dimension(
                        'components.homeHeader.brandLetterSpacing',
                      ),
                      color: pikoDesign.color('ink'),
                    ),
                  ),
                ),
                if (widget.onOpenSettings != null) ...[
                  SizedBox(width: pikoDesign.dimension('spacing.3')),
                  Flexible(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: PikoButton(
                        label: copy.text('nav.settings'),
                        icon: const PikoIcon(PikoIconName.settings),
                        variant: PikoButtonVariant.ghost,
                        onPressed: widget.onOpenSettings,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(
              height: pikoDesign.dimension('components.homeHeader.sectionGap'),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    headingLevel: 1,
                    child: Text(
                      copy.text('home.collections'),
                      key: const ValueKey('home-collections-heading'),
                      style: TextStyle(
                        fontSize: pikoDesign.dimension(
                          'components.sectionHeading.size',
                        ),
                        fontWeight: pikoDesign.weight(
                          'components.sectionHeading.weight',
                        ),
                        color: pikoDesign.color('ink'),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: pikoDesign.dimension('components.sectionHeading.gap'),
                ),
                PikoButton(
                  label: copy.text('action.new'),
                  icon: const PikoIcon(PikoIconName.plus),
                  variant: PikoButtonVariant.ghost,
                  onPressed: _createCollection,
                ),
              ],
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
                          vocabularyRepository: widget.vocabularyRepository,
                          reviewAction:
                              widget.reviewSessionFactory != null &&
                                  widget.vocabularyRepository != null &&
                                  widget.reviewMembershipLoader != null
                              ? CollectionReviewEntryPoint(
                                  key: ValueKey(
                                    'collection-review-home-${collection.id}-$_reviewIdentity',
                                  ),
                                  collection: collection,
                                  loader: widget.reviewMembershipLoader!,
                                  policy: widget.reviewCountPolicy!,
                                  clock: widget.reviewCountClock,
                                  factory: widget.reviewSessionFactory!,
                                  vocabularyRepository:
                                      widget.vocabularyRepository!,
                                  beforeLaunch: () async {},
                                  onPendingWrites:
                                      widget.onPendingVocabularyWrites,
                                  onBusyChanged: (_) {},
                                  presentation:
                                      ReviewLaunchPresentation.collectionQuick,
                                )
                              : null,
                          onTap: () => _openCollection(collection),
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
    required this.vocabularyRepository,
    this.reviewAction,
    super.key,
  });
  final CollectionRecord collection;
  final VoidCallback onTap;
  final VocabularyRepository? vocabularyRepository;
  final Widget? reviewAction;
  @override
  State<_CollectionTile> createState() => _CollectionTileState();
}

class _CollectionTileState extends State<_CollectionTile> {
  bool focused = false;
  @override
  Widget build(BuildContext context) {
    final repository = widget.vocabularyRepository;
    if (repository == null) return _buildTile(context, null);
    return CollectionEntryCount(
      repository: repository,
      collectionId: widget.collection.id,
      builder: _buildTile,
    );
  }

  Widget _buildTile(BuildContext context, int? entryCount) {
    final metadata = collectionEntryMetadata(
      context,
      widget.collection,
      entryCount,
    );
    if (widget.reviewAction != null) {
      return PikoCard(
        padding: EdgeInsets.zero,
        focused: focused,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              onTap: widget.onTap,
              label: PikoCopyScope.of(context).text('collection.open', {
                'name': widget.collection.name,
                'languages': metadata,
              }),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  excludeFromSemantics: true,
                  borderRadius: BorderRadius.circular(
                    pikoDesign.dimension('radii.card'),
                  ),
                  onTap: widget.onTap,
                  onFocusChange: (value) => setState(() => focused = value),
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        pikoDesign.dimension(
                          'components.collectionReview.quickHorizontal',
                        ),
                        pikoDesign.dimension(
                          'components.collectionReview.quickOpenTop',
                        ),
                        pikoDesign.dimension(
                          'components.collectionReview.quickHorizontal',
                        ),
                        pikoDesign.dimension(
                          'components.collectionReview.quickOpenBottom',
                        ),
                      ),
                      child: Row(
                        children: [
                          PikoLanguageBadge(widget.collection.targetLanguage),
                          SizedBox(width: pikoDesign.dimension('spacing.3')),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _collectionTitle(),
                                _collectionMetadata(metadata),
                              ],
                            ),
                          ),
                          SizedBox(width: pikoDesign.dimension('spacing.3')),
                          _collectionChevron(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                pikoDesign.dimension(
                  'components.collectionReview.quickHorizontal',
                ),
                0,
                pikoDesign.dimension(
                  'components.collectionReview.quickHorizontal',
                ),
                pikoDesign.dimension(
                  'components.collectionReview.quickActionsBottom',
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: widget.reviewAction!,
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      onTap: widget.onTap,
      label: PikoCopyScope.of(context).text('collection.open', {
        'name': widget.collection.name,
        'languages': metadata,
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
              child: Row(
                children: [
                  PikoLanguageBadge(widget.collection.targetLanguage),
                  SizedBox(width: pikoDesign.dimension('spacing.3')),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _collectionTitle(),
                        _collectionMetadata(metadata),
                      ],
                    ),
                  ),
                  SizedBox(width: pikoDesign.dimension('spacing.3')),
                  _collectionChevron(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _collectionTitle() => Text(
    widget.collection.name,
    style: TextStyle(
      fontSize: pikoDesign.dimension('components.collectionCard.titleSize'),
      fontWeight: pikoDesign.weight('components.collectionCard.titleWeight'),
      color: pikoDesign.color('ink'),
    ),
  );

  Widget _collectionMetadata(String metadata) => Text(
    metadata,
    style: TextStyle(
      fontSize: pikoDesign.dimension('components.collectionCard.metadataSize'),
      height: pikoDesign.dimension(
        'components.collectionCard.metadataLineHeight',
      ),
      color: pikoDesign.color('muted'),
    ),
  );

  Widget _collectionChevron() => IconTheme(
    data: IconThemeData(color: pikoDesign.color('muted')),
    child: const PikoIcon(PikoIconName.chevronRight),
  );
}
