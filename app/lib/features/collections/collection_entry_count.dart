import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';

typedef CollectionEntryCountBuilder =
    Widget Function(BuildContext context, int? entryCount);

String collectionLanguagePair(BuildContext context, CollectionRecord record) {
  final copy = PikoCopyScope.of(context);
  return copy.text('collection.languagePair', {
    'target': record.targetLanguage.label(copy.locale),
    'native': record.nativeLanguage.label(copy.locale),
  });
}

/// Reads the persisted vocabulary stream without substituting a count while
/// the source is unresolved or failed. A successful empty result is exactly 0.
class CollectionEntryCount extends StatefulWidget {
  const CollectionEntryCount({
    required this.repository,
    required this.collectionId,
    required this.builder,
    super.key,
  });

  final VocabularyRepository repository;
  final String collectionId;
  final CollectionEntryCountBuilder builder;

  @override
  State<CollectionEntryCount> createState() => _CollectionEntryCountState();
}

class _CollectionEntryCountState extends State<CollectionEntryCount> {
  late Stream<List<VocabularyRecord>> _entries;
  int _sourceIdentity = 0;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _entries = widget.repository.watchByCollection(widget.collectionId);
  }

  @override
  void didUpdateWidget(CollectionEntryCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.collectionId != widget.collectionId) {
      _sourceIdentity++;
      _watch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VocabularyRecord>>(
      key: ValueKey(_sourceIdentity),
      stream: _entries,
      builder: (context, snapshot) {
        final resolved =
            !snapshot.hasError &&
            snapshot.hasData &&
            snapshot.connectionState != ConnectionState.none &&
            snapshot.connectionState != ConnectionState.waiting;
        return widget.builder(context, resolved ? snapshot.data!.length : null);
      },
    );
  }
}

String collectionEntryMetadata(
  BuildContext context,
  CollectionRecord collection,
  int? entryCount,
) {
  final pair = collectionLanguagePair(context, collection);
  if (entryCount == null) return pair;
  final entries = PikoCopyScope.of(context).text(
    entryCount == 1 ? 'common.entry' : 'common.entries',
    {'count': entryCount},
  );
  return '$pair · $entries';
}
