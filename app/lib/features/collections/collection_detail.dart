import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/piko_theme.dart';
import '../entry/entry_session_route.dart';
import '../vocabulary/collection_vocabulary.dart';
import '../vocabulary/collection_vocabulary_mutations.dart';
import 'collection_write_barrier.dart';

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
    this.vocabularyMutationsFactory,
    super.key,
  });
  final CollectionsRepository repository;
  final String collectionId;
  final EntrySessionFactory? entrySessionFactory;
  final VocabularyRepository? vocabularyRepository;
  final ValueChanged<Future<void>>? onPendingVocabularyWrites;
  final CollectionVocabularyMutationsFactory? vocabularyMutationsFactory;
  @override
  State<CollectionDetail> createState() => _CollectionDetailState();
}

class _CollectionDetailState extends State<CollectionDetail> {
  late Stream<CollectionRecord?> _collection;
  bool _openingEntry = false;
  CollectionRecord? _currentCollection;
  CollectionRecord? _lastReadyCollection;
  CollectionVocabularyMutations? _mutations;
  CollectionWriteBarrier _writeBarrier = CollectionWriteBarrier();
  Object? _deleteRequest;
  Object? _deleteError;
  bool _deleting = false;
  int _identity = 0;
  ModalRoute<bool>? _deleteDialog;

  void _closeDeleteDialog() {
    final owned = _deleteDialog;
    _deleteDialog = null;
    if (owned != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (owned.isActive) owned.navigator?.removeRoute(owned);
      });
    }
  }

  Future<void> _deleteCollection() async {
    final record = _currentCollection;
    final route = ModalRoute.of(context);
    if (_deleteRequest != null ||
        record == null ||
        _openingEntry ||
        route?.isCurrent == false) {
      return;
    }
    final repository = widget.repository;
    final identity = _identity;
    final request = Object();
    final barrier = _writeBarrier;
    final mutations = _mutations;
    final register = widget.onPendingVocabularyWrites;
    bool current() =>
        mounted &&
        identity == _identity &&
        identical(_deleteRequest, request) &&
        identical(widget.repository, repository) &&
        widget.collectionId == record.id;
    bool dialogConsumed = false;
    bool consumeDialog() {
      if (!current() || dialogConsumed || _deleteDialog?.isCurrent != true) {
        return false;
      }
      dialogConsumed = true;
      return true;
    }

    setState(() {
      _deleteRequest = request;
      _deleteError = null;
    });
    try {
      final confirmed = await showPikoDialog<bool>(
        context,
        canRestoreFocus: () =>
            current() && route?.isCurrent != false && !_deleting,
        canDismiss: consumeDialog,
        onRouteCreated: (owned) {
          if (current()) {
            _deleteDialog = owned;
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (owned.isActive) owned.navigator?.removeRoute(owned);
            });
          }
        },
        builder: (dialogContext) {
          final copy = PikoCopyScope.of(dialogContext);
          return PikoDialog(
            onClose: () {
              if (consumeDialog()) Navigator.of(dialogContext).pop();
            },
            title: copy.text('collection.delete'),
            body: Text(
              copy.text('collection.deleteWarning', {'name': record.name}),
            ),
            actions: [
              PikoButton(
                label: copy.text('collection.delete'),
                icon: const PikoIcon(PikoIconName.trash),
                variant: PikoButtonVariant.dangerGhost,
                onPressed: () {
                  if (consumeDialog()) Navigator.of(dialogContext).pop(true);
                },
              ),
            ],
          );
        },
      );
      if (!current() ||
          confirmed != true ||
          route?.isCurrent == false ||
          _currentCollection?.id != record.id) {
        return;
      }
      _deleteDialog = null;
      barrier.freeze();
      setState(() => _deleting = true);
      final operation = (() async {
        await barrier.drain();
        await mutations?.awaitPending();
        if (!current()) {
          return; // Never begin a new delete after route replacement/disposal.
        }
        await repository.delete(record.id);
        await mutations
            ?.end(); // Included in the registered accepted operation.
      })();
      register?.call(operation);
      await operation;
      if (!current()) return;
      _endMutations(register);
      if (mounted && route?.isCurrent == true) Navigator.of(context).pop();
    } catch (error) {
      if (current()) setState(() => _deleteError = error);
    } finally {
      if (current()) {
        barrier.release();
        setState(() {
          _deleteRequest = null;
          _deleting = false;
        });
      }
    }
  }

  void _mutationChanged() {
    if (mounted) setState(() {});
  }

  void _createMutations() {
    _mutations = widget.vocabularyMutationsFactory?.call(widget.collectionId);
    _mutations?.addListener(_mutationChanged);
  }

  void _endMutations(ValueChanged<Future<void>>? register) {
    final old = _mutations;
    _mutations = null;
    old?.removeListener(_mutationChanged);
    if (old != null) {
      final ending = old.end();
      register?.call(ending);
    }
  }

  Future<void> _openEntry() async {
    final record = _currentCollection;
    final factory = widget.entrySessionFactory;
    if (_openingEntry ||
        _deleteRequest != null ||
        _mutations?.isBusy == true ||
        record == null ||
        factory == null) {
      return;
    }
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
    _createMutations();
    _watch();
  }

  void _watch() {
    _currentCollection = null;
    _collection = widget.repository.watchById(widget.collectionId);
  }

  @override
  void didUpdateWidget(CollectionDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId != widget.collectionId ||
        oldWidget.repository != widget.repository ||
        oldWidget.vocabularyMutationsFactory !=
            widget.vocabularyMutationsFactory) {
      _identity++;
      _closeDeleteDialog();
      _deleteRequest = null;
      _deleteError = null;
      _deleting = false;
      _writeBarrier.dispose();
      _writeBarrier = CollectionWriteBarrier();
      _endMutations(oldWidget.onPendingVocabularyWrites);
      _createMutations();
    }
    if (oldWidget.repository != widget.repository ||
        oldWidget.collectionId != widget.collectionId) {
      _lastReadyCollection = null;
      _watch();
    }
  }

  @override
  void dispose() {
    _identity++;
    _closeDeleteDialog();
    _writeBarrier.dispose();
    _endMutations(widget.onPendingVocabularyWrites);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final barrierForBuild = _writeBarrier;
    final registerForBuild = widget.onPendingVocabularyWrites;
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
                if (ready)
                  Align(
                    alignment: Alignment.centerRight,
                    child: PikoButton(
                      label: copy.text('collection.delete'),
                      icon: const PikoIcon(PikoIconName.trash),
                      variant: PikoButtonVariant.dangerGhost,
                      onPressed: _deleteRequest != null || _openingEntry
                          ? null
                          : _deleteCollection,
                    ),
                  ),
                if (_deleting) Text(copy.text('collection.deleting')),
                if (_deleteError != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      copy.text('collection.deleteFailed'),
                      style: TextStyle(color: pikoDesign.color('danger')),
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
                              onPressed:
                                  _deleteRequest != null ||
                                      _openingEntry ||
                                      _mutations?.isBusy == true
                                  ? null
                                  : _openEntry,
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
                    onPendingWrites: (work) {
                      // Capture this build's barrier/dependency callback so old
                      // child work is registered with its original storage owner.
                      barrierForBuild.track(work);
                      registerForBuild?.call(work);
                    },
                    writeBarrier: barrierForBuild,
                    mutations: _mutations,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
