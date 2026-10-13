import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/piko_theme.dart';
import '../entry/entry_session_route.dart';
import '../vocabulary/collection_vocabulary.dart';

String collectionLanguagePair(BuildContext context, CollectionRecord record) {
  final copy = PikoCopyScope.of(context);
  return copy.text('collection.languagePair', {
    'target': copy.text(record.targetLanguage.copyKey),
    'native': copy.text(record.nativeLanguage.copyKey),
  });
}

class CollectionLoadFailure extends StatelessWidget {
  const CollectionLoadFailure({required this.onRetry, super.key});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Column(
      children: [
        Text(copy.text('collection.loadFailed')),
        PikoButton(label: copy.text('action.retry'), onPressed: onRetry),
      ],
    );
  }
}

class CollectionDetail extends StatefulWidget {
  const CollectionDetail({
    required this.repository,
    required this.collectionId,
    this.entrySessionFactory,
    this.vocabularyRepository,
    this.onPendingVocabularyWrites,
    super.key,
  });
  final CollectionsRepository repository;
  final String collectionId;
  final EntrySessionFactory? entrySessionFactory;
  final VocabularyRepository? vocabularyRepository;
  final ValueChanged<Future<void>>? onPendingVocabularyWrites;
  @override
  State<CollectionDetail> createState() => _CollectionDetailState();
}

class _CollectionDetailState extends State<CollectionDetail> {
  late Stream<CollectionRecord?> _collection;
  bool _openingEntry = false;
  CollectionRecord? _currentCollection;
  CollectionRecord? _lastReadyCollection;

  Future<void> _openEntry() async {
    final record = _currentCollection;
    final factory = widget.entrySessionFactory;
    if (_openingEntry || record == null || factory == null) return;
    setState(() => _openingEntry = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              EntrySessionRoute(collection: record, factory: factory),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingEntry = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _currentCollection = null;
    _collection = widget.repository.watchById(widget.collectionId);
  }

  @override
  void didUpdateWidget(CollectionDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.collectionId != widget.collectionId) {
      _lastReadyCollection = null;
      _watch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Scaffold(
      body: PikoPage(
        child: StreamBuilder<CollectionRecord?>(
          stream: _collection,
          builder: (context, snapshot) {
            final record = snapshot.data;
            final ready =
                !snapshot.hasError &&
                snapshot.connectionState != ConnectionState.waiting &&
                snapshot.connectionState != ConnectionState.none &&
                record != null;
            _currentCollection = ready ? record : null;
            if (ready) {
              _lastReadyCollection = record;
            } else if (!snapshot.hasError &&
                snapshot.connectionState != ConnectionState.waiting &&
                snapshot.connectionState != ConnectionState.none &&
                record == null) {
              _lastReadyCollection = null;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PikoHeading(
                  title: record?.name ?? copy.text('collection.title'),
                  subtitle: record == null
                      ? null
                      : collectionLanguagePair(context, record),
                  leading: PikoButton(
                    label: copy.text('common.back'),
                    icon: const PikoIcon(PikoIconName.arrowLeft),
                    variant: PikoButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                if (snapshot.hasError)
                  CollectionLoadFailure(onRetry: () => setState(_watch))
                else if (snapshot.connectionState == ConnectionState.waiting)
                  Text(copy.text('collection.loading'))
                else if (record == null)
                  Text(copy.text('collection.notFound')),
                if (ready &&
                    (widget.entrySessionFactory != null ||
                        widget.vocabularyRepository != null))
                  Padding(
                    padding: EdgeInsets.only(
                      top: pikoDesign.dimension(
                        'components.sectionHeading.topMargin',
                      ),
                      bottom: pikoDesign.dimension(
                        'components.sectionHeading.bottomMargin',
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            headingLevel: 2,
                            child: Text(
                              copy.text('collection.vocabulary'),
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
                          width: pikoDesign.dimension(
                            'components.sectionHeading.gap',
                          ),
                        ),
                        if (widget.entrySessionFactory != null)
                          SizedBox.square(
                            dimension: pikoDesign.dimension(
                              'components.buttons.height',
                            ),
                            child: PikoIconButton(
                              icon: const PikoIcon(PikoIconName.plus),
                              semanticLabel: copy.text('action.addEntry'),
                              variant: PikoButtonVariant.primary,
                              padding: EdgeInsets.all(
                                pikoDesign.dimension('spacing.2'),
                              ),
                              onPressed: _openingEntry ? null : _openEntry,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_lastReadyCollection != null &&
                    widget.vocabularyRepository != null)
                  CollectionVocabulary(
                    key: ValueKey(
                      'collection-vocabulary-${widget.collectionId}',
                    ),
                    collection: _lastReadyCollection!,
                    repository: widget.vocabularyRepository!,
                    onPendingWrites: widget.onPendingVocabularyWrites,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
