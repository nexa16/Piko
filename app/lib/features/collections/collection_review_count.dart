import 'package:flutter/widgets.dart';

import '../../core/clock.dart';
import '../../data/review_due_membership.dart';

/// The owner-selected meaning of a Collection's due badge.
///
/// Both policies are implemented deliberately; callers must choose one rather
/// than inheriting an accidental default while the product decision is open.
enum CollectionReviewCountPolicy { distinctVocabulary, dueDirectionCards }

typedef CollectionReviewMembershipLoader =
    Future<List<ReviewDueMembership>> Function({
      required String collectionId,
      required DateTime at,
    });

int aggregateCollectionReviewCount(
  Iterable<ReviewDueMembership> memberships,
  CollectionReviewCountPolicy policy,
) {
  final due = memberships.where(
    (membership) => membership.regularDue || membership.eligibleRetry,
  );
  return switch (policy) {
    CollectionReviewCountPolicy.distinctVocabulary => {
      for (final membership in due) membership.entryId,
    }.length,
    CollectionReviewCountPolicy.dueDirectionCards => {
      for (final membership in due) (membership.entryId, membership.direction),
    }.length,
  };
}

/// Read-only, lifecycle-refreshable Collection count state.
///
/// The loader supplies passive membership snapshots. This model never creates
/// a review session, expires retry rows or arms retry waits.
final class CollectionReviewCount extends ChangeNotifier {
  CollectionReviewCount({
    required this.collectionId,
    required this.loader,
    required this.policy,
    this.clock = const SystemPikoClock(),
  });

  final String collectionId;
  final CollectionReviewMembershipLoader loader;
  final CollectionReviewCountPolicy policy;
  final PikoClock clock;

  int? _value;
  Object? _error;
  bool _loading = false;
  int _generation = 0;
  bool _disposed = false;

  int? get value => _value;
  Object? get error => _error;
  bool get loading => _loading;

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_generation;
    _loading = true;
    _error = null;
    _value = null;
    notifyListeners();
    try {
      final memberships = await loader(
        collectionId: collectionId,
        at: clock.now().toUtc(),
      );
      if (_disposed || generation != _generation) return;
      _value = aggregateCollectionReviewCount(memberships, policy);
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = error;
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

typedef CollectionReviewCountWidgetBuilder =
    Widget Function(
      BuildContext context,
      CollectionReviewCount count,
      VoidCallback retry,
    );

/// Refreshes the passive count when first shown and whenever the app resumes.
class CollectionReviewCountBuilder extends StatefulWidget {
  const CollectionReviewCountBuilder({
    required this.collectionId,
    required this.loader,
    required this.policy,
    required this.builder,
    this.clock = const SystemPikoClock(),
    super.key,
  });

  final String collectionId;
  final CollectionReviewMembershipLoader loader;
  final CollectionReviewCountPolicy policy;
  final CollectionReviewCountWidgetBuilder builder;
  final PikoClock clock;

  @override
  State<CollectionReviewCountBuilder> createState() =>
      _CollectionReviewCountBuilderState();
}

class _CollectionReviewCountBuilderState
    extends State<CollectionReviewCountBuilder>
    with WidgetsBindingObserver {
  late CollectionReviewCount _count;

  CollectionReviewCount createCount() => CollectionReviewCount(
    collectionId: widget.collectionId,
    loader: widget.loader,
    policy: widget.policy,
    clock: widget.clock,
  )..addListener(changed);

  void changed() {
    if (mounted) setState(() {});
  }

  void refresh() {
    _count.refresh();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _count = createCount();
    refresh();
  }

  @override
  void didUpdateWidget(CollectionReviewCountBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId != widget.collectionId ||
        oldWidget.loader != widget.loader ||
        oldWidget.policy != widget.policy ||
        !identical(oldWidget.clock, widget.clock)) {
      _count.removeListener(changed);
      _count.dispose();
      _count = createCount();
      refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _count.removeListener(changed);
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _count, refresh);
}
