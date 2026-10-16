import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/learning_item.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_reading.dart';
import '../../ui/piko_theme.dart';
import 'due_learning_session.dart';
import 'review_session_route.dart';

typedef ReviewSessionFactory =
    Future<DueLearningSession> Function(
      String collectionId,
      LearningDirection direction,
    );

enum ReviewLaunchPresentation { plain, collectionQuick, collectionCard }

String reviewDirectionLabel(
  CollectionRecord collection,
  LearningDirection direction,
) {
  final target = collection.targetLanguage.code.toUpperCase();
  final native = collection.nativeLanguage.code.toUpperCase();
  return direction == LearningDirection.targetToNative
      ? '$target → $native'
      : '$native → $target';
}

/// Owns only setup/navigation; the supplied runtime owns storage and its drains.
class ReviewLaunch extends StatefulWidget {
  const ReviewLaunch({
    super.key,
    required this.collection,
    required this.factory,
    required this.vocabularyRepository,
    required this.beforeLaunch,
    required this.onPendingWrites,
    required this.onBusyChanged,
    this.enabled = true,
    this.presentation = ReviewLaunchPresentation.plain,
    this.dueCount,
    this.onSessionClosed,
    this.fixedDirection,
    this.directionCounts,
    this.directionCountsLoader,
    this.allowedDirections = const {
      LearningDirection.targetToNative,
      LearningDirection.nativeToTarget,
    },
  }) : assert(
         presentation == ReviewLaunchPresentation.plain || dueCount != null,
       );
  final CollectionRecord collection;
  final ReviewSessionFactory factory;
  final VocabularyRepository vocabularyRepository;
  final Future<void> Function() beforeLaunch;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled;
  final ReviewLaunchPresentation presentation;
  final int? dueCount;
  final VoidCallback? onSessionClosed;
  final LearningDirection? fixedDirection;
  final Map<LearningDirection, int>? directionCounts;
  final Future<Map<LearningDirection, int>> Function()? directionCountsLoader;
  final Set<LearningDirection> allowedDirections;
  @override
  State<ReviewLaunch> createState() => _ReviewLaunchState();
}

class _ReviewLaunchState extends State<ReviewLaunch> {
  bool _opening = false;
  Object? _launchError;
  int _identity = 0;
  late final _eligibility = ValueNotifier(widget.enabled);
  ModalRoute<DueLearningSession>? _dialog;
  void _closeDialog() {
    final old = _dialog;
    _dialog = null;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (old.isActive) old.navigator?.removeRoute(old);
      });
    }
  }

  @override
  void didUpdateWidget(ReviewLaunch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      // The dialog is on a sibling route; notify after this parent's build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _eligibility.value = widget.enabled;
      });
    }
    if (oldWidget.collection.id != widget.collection.id ||
        oldWidget.factory != widget.factory ||
        oldWidget.vocabularyRepository != widget.vocabularyRepository) {
      _identity++;
      _opening = false;
      _closeDialog();
    }
  }

  @override
  void dispose() {
    _identity++;
    _closeDialog();
    _eligibility.dispose();
    final busy = widget.onBusyChanged;
    WidgetsBinding.instance.addPostFrameCallback((_) => busy(false));
    super.dispose();
  }

  Future<void> _open([LearningDirection? chosenDirection]) async {
    final route = ModalRoute.of(context);
    if (_opening || !widget.enabled || route?.isCurrent != true) return;
    final requestedDirection = chosenDirection ?? widget.fixedDirection;
    if (requestedDirection != null &&
        !widget.allowedDirections.contains(requestedDirection)) {
      return;
    }
    final identity = _identity;
    final collection = widget.collection;
    final factory = widget.factory;
    final vocabulary = widget.vocabularyRepository;
    final beforeLaunch = widget.beforeLaunch;
    final register = widget.onPendingWrites;
    final busy = widget.onBusyChanged;
    bool current() =>
        mounted &&
        identity == _identity &&
        widget.factory == factory &&
        identical(widget.vocabularyRepository, vocabulary);
    setState(() {
      _opening = true;
      _launchError = null;
    });
    busy(true);
    DueLearningSession? session;
    try {
      var counts = widget.directionCounts;
      final explicit = chosenDirection ?? widget.fixedDirection;
      if (counts != null || explicit != null) {
        final done = Completer<void>();
        register?.call(done.future);
        try {
          await beforeLaunch();
          if (!current() || !widget.enabled || route?.isCurrent != true) return;
          counts = await widget.directionCountsLoader?.call() ?? counts;
          if (!current() || !widget.enabled || route?.isCurrent != true) return;
          final available = counts?.entries
              .where((entry) => entry.value > 0)
              .toList();
          final direction =
              explicit ??
              (available?.length == 1 ? available!.single.key : null);
          if (direction != null) {
            if (!widget.allowedDirections.contains(direction)) return;
            session = await factory(collection.id, direction);
          } else if (available?.isEmpty == true) {
            // The launch was valid when offered. Let authoritative preparation
            // resolve this race into its existing no-due / retry-wait state.
            final original = widget.directionCounts?.entries
                .where((entry) => entry.value > 0)
                .firstOrNull;
            if (original == null) return;
            session = await factory(collection.id, original.key);
          }
        } finally {
          done.complete();
        }
      }
      if (!mounted || !current()) return;
      session ??= await showPikoDialog<DueLearningSession>(
        context,
        canRestoreFocus: () => current() && route?.isCurrent == true,
        onRouteCreated: (owned) {
          if (current()) _dialog = owned;
        },
        builder: (_) => ReviewDirectionDialog(
          collection: collection,
          factory: factory,
          beforeLaunch: beforeLaunch,
          onPendingWrites: register,
          canLaunch: () => current() && widget.enabled,
          eligibility: _eligibility,
          directionCounts: counts,
          directionCountsLoader: widget.directionCountsLoader,
        ),
      );
      if (!mounted || !current()) return;
      _dialog = null;
      if (session == null || route?.isCurrent != true || !widget.enabled) {
        return;
      }
      final launched = session;
      session = null; // The pushed route now owns the already prepared session.
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ReviewSessionRoute(
            collection: collection,
            session: launched,
            vocabularyRepository: vocabulary,
          ),
        ),
      );
      if (current()) widget.onSessionClosed?.call();
    } catch (error) {
      if (current() && route?.isCurrent == true) {
        setState(() => _launchError = error);
      }
    } finally {
      if (session != null) {
        await session.stop();
        session.dispose();
      }
      if (current()) {
        setState(() => _opening = false);
        busy(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final activate = widget.enabled && !_opening ? _open : null;
    final counts = widget.directionCounts;
    if (counts != null && counts.values.every((count) => count <= 0)) {
      return const SizedBox.shrink();
    }
    if (counts != null &&
        widget.presentation == ReviewLaunchPresentation.collectionCard) {
      final available = LearningDirection.values
          .where((direction) => (counts[direction] ?? 0) > 0)
          .where(widget.allowedDirections.contains)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final direction in available)
            Padding(
              padding: EdgeInsets.only(
                top: direction == available.first
                    ? 0
                    : pikoDesign.dimension('spacing.2'),
              ),
              child: PikoButton(
                key: ValueKey('collection-review-${direction.name}'),
                label: copy.text('r2.due', {
                  'direction': reviewDirectionLabel(
                    widget.collection,
                    direction,
                  ),
                  'count': counts[direction]!,
                }),
                expandLabel: true,
                labelAlignment: TextAlign.start,
                trailingSpacing: pikoDesign.dimension(
                  'components.collectionReview.mascotGap',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (direction == available.first) ...[
                      const PikoReading(),
                      SizedBox(
                        width: pikoDesign.dimension(
                          'components.collectionReview.mascotGap',
                        ),
                      ),
                    ],
                    const PikoIcon(PikoIconName.rotateCcw),
                  ],
                ),
                variant: direction == available.first
                    ? PikoButtonVariant.reviewPrimary
                    : PikoButtonVariant.reviewSecondary,
                onPressed: activate == null ? null : () => _open(direction),
              ),
            ),
          if (_launchError != null) Text(copy.text('learn.prepareFailed')),
        ],
      );
    }
    if (_launchError != null) {
      return Column(
        children: [
          Text(copy.text('learn.prepareFailed')),
          PikoButton(label: copy.text('action.retry'), onPressed: activate),
        ],
      );
    }
    return switch (widget.presentation) {
      ReviewLaunchPresentation.plain => PikoButton(
        label: copy.text('action.review'),
        onPressed: activate,
      ),
      ReviewLaunchPresentation.collectionQuick => SizedBox(
        width: pikoDesign.dimension('components.collectionReview.quickWidth'),
        child: PikoButton(
          key: const ValueKey('collection-review-quick'),
          label: copy.text('action.review'),
          icon: const PikoIcon(PikoIconName.rotateCcw),
          padding: EdgeInsets.symmetric(
            horizontal: pikoDesign.dimension(
              'components.collectionReview.quickPaddingX',
            ),
            vertical: pikoDesign.dimension(
              'components.collectionReview.quickPaddingY',
            ),
          ),
          iconLabelSpacing: pikoDesign.dimension('spacing.1'),
          trailingSpacing: pikoDesign.dimension('spacing.2'),
          trailing: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: pikoDesign.dimension(
                'components.collectionReview.quickCountMinWidth',
              ),
            ),
            child: Text(
              '${widget.dueCount!}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: pikoDesign.dimension(
                  'components.collectionReview.quickCountSize',
                ),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          onPressed: activate,
        ),
      ),
      ReviewLaunchPresentation.collectionCard => Semantics(
        button: true,
        enabled: activate != null,
        label:
            '${copy.text('collection.reviewDue', {'count': widget.dueCount!})}. '
            '${copy.text('action.reviewNow')}',
        onTap: activate,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('collection-review-card'),
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(
              pikoDesign.dimension('radii.card'),
            ),
            onTap: activate,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: pikoDesign.dimension(
                  'components.collectionReview.cardMinHeight',
                ),
              ),
              padding: EdgeInsets.all(
                pikoDesign.dimension('components.collectionReview.cardPadding'),
              ),
              decoration: BoxDecoration(
                color: pikoDesign.color('tint'),
                borderRadius: BorderRadius.circular(
                  pikoDesign.dimension('radii.card'),
                ),
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.text('collection.reviewDue', {
                              'count': widget.dueCount!,
                            }),
                            style: TextStyle(
                              fontSize: pikoDesign.dimension('typography.body'),
                              height: pikoDesign.dimension(
                                'components.collectionReview.titleLineHeight',
                              ),
                              fontWeight: pikoDesign.weight(
                                'components.buttons.weight',
                              ),
                              color: pikoDesign.color('primary'),
                            ),
                          ),
                          SizedBox(height: pikoDesign.dimension('spacing.1')),
                          Text(
                            copy.text('action.reviewNow'),
                            style: TextStyle(
                              fontSize: pikoDesign.dimension(
                                'typography.small',
                              ),
                              color: pikoDesign.color('muted'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: pikoDesign.dimension('spacing.3')),
                    IconTheme(
                      data: IconThemeData(color: pikoDesign.color('primary')),
                      child: const PikoIcon(PikoIconName.rotateCcw),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    };
  }
}

class ReviewDirectionDialog extends StatefulWidget {
  const ReviewDirectionDialog({
    super.key,
    required this.collection,
    required this.factory,
    required this.beforeLaunch,
    required this.onPendingWrites,
    required this.canLaunch,
    required this.eligibility,
    this.directionCounts,
    this.directionCountsLoader,
  });
  final CollectionRecord collection;
  final ReviewSessionFactory factory;
  final Future<void> Function() beforeLaunch;
  final ValueChanged<Future<void>>? onPendingWrites;
  final bool Function() canLaunch;
  final ValueListenable<bool> eligibility;
  final Map<LearningDirection, int>? directionCounts;
  final Future<Map<LearningDirection, int>> Function()? directionCountsLoader;
  @override
  State<ReviewDirectionDialog> createState() => _ReviewDirectionDialogState();
}

class _ReviewDirectionDialogState extends State<ReviewDirectionDialog> {
  LearningDirection _direction = LearningDirection.targetToNative;
  bool _pending = false;
  Object? _error;
  Future<void> _start([LearningDirection? selected]) async {
    final route = ModalRoute.of(context);
    if (_pending || !widget.canLaunch() || route?.isCurrent != true) return;
    final factory = widget.factory, register = widget.onPendingWrites;
    final before = widget.beforeLaunch;
    final collectionId = widget.collection.id;
    final direction = selected ?? _direction;
    bool current() => mounted && widget.canLaunch() && route?.isCurrent == true;
    setState(() {
      _pending = true;
      _error = null;
    });
    final done = Completer<void>();
    try {
      // Register the entire preparation before it can touch caller-owned storage.
      register?.call(done.future);
      await before();
      if (!current()) return;
      await widget.directionCountsLoader?.call();
      if (!current()) return;
      final session = await factory(collectionId, direction);
      if (!mounted || !current()) {
        await session.stop();
        session.dispose();
        return;
      }
      Navigator.of(context).pop(session);
    } catch (error) {
      if (current()) {
        setState(() {
          _pending = false;
          _error = error;
        });
      }
    } finally {
      // Covered setup can become current again: release its local single-flight
      // latch, but never navigate, restore focus or surface a late error there.
      if (mounted) setState(() => _pending = false);
      done.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return ListenableBuilder(
      listenable: widget.eligibility,
      builder: (_, _) => PikoDialog(
        title: copy.text('learn.setup'),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.directionCounts != null) ...[
              for (final direction in LearningDirection.values)
                if ((widget.directionCounts![direction] ?? 0) > 0)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: pikoDesign.dimension('spacing.2'),
                    ),
                    child: PikoButton(
                      label: copy.text('r2.due', {
                        'direction': reviewDirectionLabel(
                          widget.collection,
                          direction,
                        ),
                        'count': widget.directionCounts![direction]!,
                      }),
                      onPressed: _pending || !widget.canLaunch()
                          ? null
                          : () => _start(direction),
                    ),
                  ),
            ] else
              PikoDropdown<LearningDirection>(
                autofocus: true,
                label: copy.text('settings.direction'),
                value: _direction,
                items: [
                  for (final direction in LearningDirection.values)
                    DropdownMenuItem(
                      value: direction,
                      child: Text(
                        reviewDirectionLabel(widget.collection, direction),
                      ),
                    ),
                ],
                onChanged: _pending
                    ? null
                    : (direction) {
                        if (direction != null) {
                          setState(() => _direction = direction);
                        }
                      },
              ),
            if (_pending) Text(copy.text('learn.preparing')),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  copy.text('learn.prepareFailed'),
                  style: TextStyle(color: pikoDesign.color('danger')),
                ),
              ),
          ],
        ),
        actions: [
          if (widget.directionCounts == null)
            PikoDialogAction(
              label: copy.text('learn.start'),
              onPressed: _pending || !widget.canLaunch() ? null : _start,
            ),
        ],
      ),
    );
  }
}
