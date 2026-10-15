import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_deletion.dart';
import 'entry_session_controller.dart';
import 'entry_session_screen.dart';

/// The composition root supplies dependencies; the route owns their lifetime.
typedef EntrySessionFactory =
    EntrySessionResources Function(String collectionId);

final class EntrySessionResources {
  EntrySessionResources({
    required this.session,
    required this.deletionService,
    this.interchangeBuilder,
    this.onPendingWrites,
  });
  final EntrySessionController session;
  final VocabularyDeletionService deletionService;
  final Widget Function(BuildContext, CollectionRecord)? interchangeBuilder;
  final ValueChanged<Future<void>>? onPendingWrites;

  void dispose() {
    session.dispose();
    deletionService.dispose();
  }
}

class EntrySessionRoute extends StatefulWidget {
  const EntrySessionRoute({
    required this.collection,
    required this.factory,
    super.key,
  });
  final CollectionRecord collection;
  final EntrySessionFactory factory;

  @override
  State<EntrySessionRoute> createState() => _EntrySessionRouteState();
}

class _EntrySessionRouteState extends State<EntrySessionRoute> {
  late final EntrySessionResources resources;

  @override
  void initState() {
    super.initState();
    // Allocate exactly once, never in a locale-dependent build.
    resources = widget.factory(widget.collection.id);
  }

  @override
  void dispose() {
    resources.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EntrySessionScreen(
    collection: widget.collection,
    session: resources.session,
    onOpenInterchange: resources.interchangeBuilder == null
        ? null
        : () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (context) =>
                    resources.interchangeBuilder!(context, widget.collection),
              ),
            );
          },
    onPendingWrites: resources.onPendingWrites,
  );
}
