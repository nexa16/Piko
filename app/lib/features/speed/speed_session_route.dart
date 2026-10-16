import '../learning/learning_editor_guard.dart';
import '../../data/categories_repository.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/piko_theme.dart';
import '../learning/learning_progress_bar.dart';
import '../learning/learning_prompt_card.dart';
import '../learning/review_launch.dart' show reviewDirectionLabel;
import 'speed_learning_session.dart';
import 'speed_numbers_break.dart';
import 'speed_session.dart';

typedef SpeedGameBuilder =
    Widget Function(BuildContext context, SpeedLearningSession session);

/// Returned only after every selected word has committed its completion.
final class SpeedSessionResult {
  const SpeedSessionResult({required this.completedCount})
    : assert(completedCount > 0);

  final int completedCount;
}

/// Owns this in-process session's presentation and safe exit, never its storage.
class SpeedSessionRoute extends StatefulWidget {
  const SpeedSessionRoute({
    required this.collection,
    required this.session,
    required this.vocabularyRepository,
    this.categoriesRepository,
    this.onPendingWrites,
    this.gameBuilder,
    super.key,
  });

  final CollectionRecord collection;
  final SpeedLearningSession session;
  final VocabularyRepository vocabularyRepository;
  final CategoriesRepository? categoriesRepository;
  final ValueChanged<Future<void>>? onPendingWrites;
  final SpeedGameBuilder? gameBuilder;

  @override
  State<SpeedSessionRoute> createState() => _SpeedSessionRouteState();
}

class _SpeedSessionRouteState extends State<SpeedSessionRoute>
    with WidgetsBindingObserver {
  final _editorGuard = LearningEditorGuard();
  bool _foreground = true;

  Future<void> _back() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_editorGuard.isEditing) {
      await _editorGuard.close();
      return;
    }
    await _exit(widget.session);
  }

  bool _exiting = false;
  bool _activityScheduled = false;
  bool _transitionScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  bool _isCurrent(SpeedLearningSession session) =>
      mounted &&
      identical(session, widget.session) &&
      session.state?.collectionId == widget.collection.id &&
      !_exiting &&
      _foreground &&
      ModalRoute.of(context)?.isCurrent == true;

  void _syncActivity() {
    if (_activityScheduled) return;
    _activityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activityScheduled = false;
      if (!mounted) return;
      final session = widget.session;
      session.setPresentationActive(
        _isCurrent(session),
        isCurrent: () => _isCurrent(session),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    final session = widget.session;
    session.setPresentationActive(
      _isCurrent(session),
      isCurrent: () => _isCurrent(session),
    );
    if (_foreground) _scheduleTransition(session);
  }

  void _scheduleTransition(SpeedLearningSession session) {
    if (_transitionScheduled ||
        session.isSubmitting ||
        session.isStopped ||
        !(session.isComplete ||
            (session.needsBreak && session.state?.numberGame == null))) {
      return;
    }
    _transitionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transitionScheduled = false;
      if (!_isCurrent(session) || session.isSubmitting || session.isStopped) {
        return;
      }
      if (session.isComplete) {
        unawaited(_exit(session, completed: !session.endedByExclusion));
      } else if (session.needsBreak && session.state?.numberGame == null) {
        session.beginBreak();
      }
    });
  }

  Future<void> _exit(
    SpeedLearningSession session, {
    bool completed = false,
  }) async {
    if (!mounted || _exiting || !identical(session, widget.session)) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    if (_editorGuard.isEditing && !await _editorGuard.close()) return;
    if (!mounted ||
        _exiting ||
        !identical(session, widget.session) ||
        route?.isCurrent != true) {
      return;
    }
    final state = session.state;
    final result =
        completed &&
            state != null &&
            state.isComplete &&
            state.entryIds.isNotEmpty &&
            !session.isSubmitting &&
            session.error == null &&
            state.completedEntryIds.length == state.entryIds.length
        ? SpeedSessionResult(completedCount: state.completedEntryIds.length)
        : null;
    setState(() => _exiting = true);
    await session.stop();
    if (mounted && identical(session, widget.session)) {
      setState(() => _exiting = false);
      if (route?.isCurrent == true) {
        Navigator.of(context).pop<SpeedSessionResult>(result);
      }
    }
  }

  Future<void> _grade(
    SpeedLearningSession session,
    SpeedTurnHandle handle,
    SpeedAnswer answer,
    bool Function() canSubmit,
  ) async {
    if (!_isCurrent(session) || !canSubmit()) return;
    try {
      await session.submitAnswer(handle, answer);
    } catch (_) {
      // The session retains this exact revealed turn and retryable failure.
    }
  }

  Widget _grades(
    BuildContext context,
    SpeedLearningSession session,
    SpeedTurnHandle handle,
    bool Function() canSubmit,
  ) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    Widget action(SpeedAnswer answer) => Expanded(
      child: PikoButton(
        key: ValueKey('speed-grade-${answer.name}'),
        label: copy.text(
          answer == SpeedAnswer.correct ? 'action.correct' : 'action.incorrect',
        ),
        variant: answer == SpeedAnswer.correct
            ? PikoButtonVariant.gradeCorrect
            : PikoButtonVariant.gradeIncorrect,
        padding: EdgeInsets.symmetric(
          horizontal: d.dimension('components.reviewGrading.paddingX'),
          vertical: d.dimension('components.reviewGrading.paddingY'),
        ),
        labelWeight: d.weight('components.reviewGrading.weight'),
        onPressed: _isCurrent(session) && canSubmit()
            ? () => _grade(session, handle, answer, canSubmit)
            : null,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(
        top: d.dimension('components.reviewGrading.topMargin'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                action(SpeedAnswer.incorrect),
                SizedBox(width: d.dimension('components.reviewGrading.gap')),
                action(SpeedAnswer.correct),
              ],
            ),
          ),
          if (session.isSubmitting || session.error != null)
            Padding(
              padding: EdgeInsets.only(top: d.dimension('spacing.3')),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  copy.text(
                    session.isSubmitting
                        ? 'learn.gradeSaving'
                        : 'learn.gradeFailed',
                  ),
                  style: TextStyle(
                    color: d.color(session.isSubmitting ? 'muted' : 'danger'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(SpeedSessionRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      unawaited(oldWidget.session.stop());
      oldWidget.session.dispose();
      _exiting = false;
      _transitionScheduled = false;
      _syncActivity();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.session.stop());
    widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        _scheduleTransition(session);
        final state = session.state;
        final description = state == null
            ? ''
            : copy.text('learn.speedProgress', {
                'completed': state.completedEntryIds.length,
                'total': state.entryIds.length,
              });
        return PopScope<SpeedSessionResult>(
          canPop: !_exiting && session.isStopped,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_back());
          },
          child: Scaffold(
            body: PikoPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PikoHeading(
                    title: widget.collection.name,
                    leading: PikoIconButton(
                      key: const ValueKey('speed-exit'),
                      semanticLabel: copy.text('learn.exitSpeed'),
                      icon: const PikoIcon(PikoIconName.arrowLeft),
                      large: true,
                      onPressed: _exiting ? null : () => _exit(session),
                    ),
                  ),
                  if (state != null) ...[
                    Padding(
                      padding: EdgeInsets.only(
                        top: d.dimension('components.reviewContext.topMargin'),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: d.dimension('spacing.2'),
                        runSpacing: d.dimension('spacing.2'),
                        children: [
                          Text(
                            reviewDirectionLabel(
                              widget.collection,
                              state.direction,
                            ),
                            key: const ValueKey('speed-fixed-direction'),
                          ),
                          Text(
                            description,
                            key: const ValueKey('speed-progress-count'),
                            textAlign: TextAlign.right,
                            style: TextStyle(color: d.color('muted')),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: d.dimension('components.progress.marginY'),
                      ),
                      child: LearningProgressBar(
                        key: const ValueKey('speed-progress'),
                        fillKey: const ValueKey('speed-progress-fill'),
                        completed: state.completedEntryIds.length,
                        total: state.entryIds.length,
                        label:
                            '${copy.text('learn.progressLabel')} · $description',
                      ),
                    ),
                    if (session.current case final handle?)
                      LearningPromptCard(
                        key: ObjectKey(handle),
                        presentation: handle,
                        collection: widget.collection,
                        categoriesRepository: widget.categoriesRepository,
                        editorGuard: _editorGuard,
                        onPendingWrites: widget.onPendingWrites,
                        onInactive: session.revalidateActivity,
                        entryId: handle.entryId,
                        collectionId: state.collectionId,
                        direction: state.direction,
                        repository: widget.vocabularyRepository,
                        scopeMatches:
                            state.collectionId == widget.collection.id,
                        initiallyRevealed: session.revealed,
                        canReveal: () =>
                            _isCurrent(session) && session.canReveal(handle),
                        onReveal: () => session.reveal(handle),
                        revealedActions: (context, canSubmit) =>
                            _grades(context, session, handle, canSubmit),
                      )
                    else if (session.needsBreak)
                      widget.gameBuilder?.call(context, session) ??
                          SpeedNumbersBreak(session: session),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
