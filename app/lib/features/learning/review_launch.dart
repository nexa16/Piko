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
import '../../ui/piko_theme.dart';
import 'due_learning_session.dart';
import 'review_session_route.dart';

typedef ReviewSessionFactory =
    Future<DueLearningSession> Function(
      String collectionId,
      LearningDirection direction,
    );

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
  });
  final CollectionRecord collection;
  final ReviewSessionFactory factory;
  final VocabularyRepository vocabularyRepository;
  final Future<void> Function() beforeLaunch;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled;
  @override
  State<ReviewLaunch> createState() => _ReviewLaunchState();
}

class _ReviewLaunchState extends State<ReviewLaunch> {
  bool _opening = false;
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

  Future<void> _open() async {
    final route = ModalRoute.of(context);
    if (_opening || !widget.enabled || route?.isCurrent != true) return;
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
    setState(() => _opening = true);
    busy(true);
    DueLearningSession? session;
    try {
      session = await showPikoDialog<DueLearningSession>(
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
  Widget build(BuildContext context) => PikoButton(
    label: PikoCopyScope.of(context).text('action.review'),
    onPressed: widget.enabled && !_opening ? _open : null,
  );
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
  });
  final CollectionRecord collection;
  final ReviewSessionFactory factory;
  final Future<void> Function() beforeLaunch;
  final ValueChanged<Future<void>>? onPendingWrites;
  final bool Function() canLaunch;
  final ValueListenable<bool> eligibility;
  @override
  State<ReviewDirectionDialog> createState() => _ReviewDirectionDialogState();
}

class _ReviewDirectionDialogState extends State<ReviewDirectionDialog> {
  LearningDirection _direction = LearningDirection.targetToNative;
  bool _pending = false;
  Object? _error;
  Future<void> _start() async {
    final route = ModalRoute.of(context);
    if (_pending || !widget.canLaunch() || route?.isCurrent != true) return;
    final factory = widget.factory, register = widget.onPendingWrites;
    final before = widget.beforeLaunch;
    final collectionId = widget.collection.id;
    final direction = _direction;
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
          PikoButton(
            label: copy.text('learn.start'),
            onPressed: _pending || !widget.canLaunch() ? null : _start,
          ),
        ],
      ),
    );
  }
}
