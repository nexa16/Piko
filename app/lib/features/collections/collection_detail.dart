import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';

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
    super.key,
  });
  final CollectionsRepository repository;
  final String collectionId;
  @override
  State<CollectionDetail> createState() => _CollectionDetailState();
}

class _CollectionDetailState extends State<CollectionDetail> {
  late Stream<CollectionRecord?> _collection;
  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _collection = widget.repository.watchById(widget.collectionId);
  }

  @override
  void didUpdateWidget(CollectionDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.collectionId != widget.collectionId) {
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
              ],
            );
          },
        ),
      ),
    );
  }
}
