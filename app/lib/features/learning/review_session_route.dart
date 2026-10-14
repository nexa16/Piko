import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/piko_theme.dart';
import 'due_learning_session.dart';
import 'review_launch.dart';
import 'review_prompt_card.dart';
import 'regular_grading_coordinator.dart';
import 'hard_modifier.dart';
import 'review_progress.dart';

/// Stored self-assessment card and regular grades; reinforcement follows separately.
class ReviewSessionRoute extends StatefulWidget {
  const ReviewSessionRoute({
    super.key,
    required this.collection,
    required this.session,
    required this.vocabularyRepository,
  });
  final CollectionRecord collection;
  final DueLearningSession session;
  final VocabularyRepository vocabularyRepository;
  @override
  State<ReviewSessionRoute> createState() => _ReviewSessionRouteState();
}

class _ReviewSessionRouteState extends State<ReviewSessionRoute>
    with WidgetsBindingObserver {
  bool _foreground = true;
  bool _activityScheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  bool _isPresentationCurrent(DueLearningSession session) =>
      mounted &&
      identical(widget.session, session) &&
      _foreground &&
      !_exiting &&
      ModalRoute.of(context)?.isCurrent == true;

  void _syncActivity() {
    if (_activityScheduled) return;
    _activityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activityScheduled = false;
      if (!mounted) return;
      final session = widget.session;
      session.setPresentationActive(
        _isPresentationCurrent(session),
        isCurrent: () => _isPresentationCurrent(session),
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
      _isPresentationCurrent(session),
      isCurrent: () => _isPresentationCurrent(session),
    );
  }

  bool _exiting = false;
  GradingCardHandle? _preAdmissionError;
  Future<void> _grade(
    DueLearningSession session,
    GradingCardHandle handle,
    AnswerGrade grade,
    bool Function() canSubmit,
  ) async {
    if (!mounted ||
        _exiting ||
        !identical(session, widget.session) ||
        ModalRoute.of(context)?.isCurrent != true ||
        !canSubmit()) {
      return;
    }
    if (_preAdmissionError != null) setState(() => _preAdmissionError = null);
    try {
      await session.submitAnswerNow(handle, grade);
    } catch (_) {
      // The existing coordinator retains the current answer/modifier and error.
      // Its registered drain and session bookkeeping own the accepted operation.
      // A clock can fail before coordinator admission; keep that feedback local
      // to this still-current stored presentation, with no late covered effect.
      if (mounted &&
          identical(session, widget.session) &&
          canSubmit() &&
          session.error == null) {
        setState(() => _preAdmissionError = handle);
      }
    }
  }

  Widget _gradingActions(
    BuildContext context,
    DueLearningSession session,
    GradingCardHandle handle,
    bool Function() canSubmit,
  ) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    final enabled = !_exiting && canSubmit();
    Widget action(AnswerGrade grade) => Expanded(
      child: PikoButton(
        key: ValueKey('review-grade-${grade.name}'),
        label: copy.text(
          grade == AnswerGrade.incorrect
              ? 'action.incorrect'
              : 'action.correct',
        ),
        variant: grade == AnswerGrade.incorrect
            ? PikoButtonVariant.gradeIncorrect
            : PikoButtonVariant.gradeCorrect,
        padding: EdgeInsets.symmetric(
          horizontal: d.dimension('components.reviewGrading.paddingX'),
          vertical: d.dimension('components.reviewGrading.paddingY'),
        ),
        labelWeight: d.weight('components.reviewGrading.weight'),
        onPressed: enabled
            ? () => _grade(session, handle, grade, canSubmit)
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
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(width: d.dimension('components.reviewGrading.gap')),
              Expanded(
                child: HardModifier(
                  key: const ValueKey('review-hard'),
                  coordinator: session,
                  handle: handle,
                  canChange: () =>
                      mounted &&
                      !_exiting &&
                      identical(session, widget.session) &&
                      canSubmit(),
                ),
              ),
            ],
          ),
          SizedBox(height: d.dimension('components.reviewGrading.gap')),
          IntrinsicHeight(
            child: Row(
              key: const ValueKey('review-grading'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                action(AnswerGrade.incorrect),
                SizedBox(width: d.dimension('components.reviewGrading.gap')),
                action(AnswerGrade.correct),
              ],
            ),
          ),
          if (session.isSubmitting ||
              session.error != null ||
              identical(_preAdmissionError, handle))
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

  Future<void> _exit(DueLearningSession session) async {
    if (!mounted || _exiting || !identical(session, widget.session)) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    setState(() => _exiting = true);
    await session.stop();
    if (mounted && identical(session, widget.session)) {
      setState(() => _exiting = false);
      if (route?.isCurrent == true) Navigator.of(context).pop();
    }
  }

  @override
  void didUpdateWidget(ReviewSessionRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      unawaited(oldWidget.session.stop());
      oldWidget.session.dispose();
      _exiting = false;
      _preAdmissionError = null;
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
    final copy = PikoCopyScope.of(context);
    final sessionForBuild = widget.session;
    return ListenableBuilder(
      listenable: sessionForBuild,
      builder: (_, _) => PopScope(
        canPop: !_exiting && widget.session.isStopped,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_exit(sessionForBuild));
        },
        child: Scaffold(
          body: PikoPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PikoHeading(
                  title: copy.text('learn.longTitle'),
                  leading: PikoButton(
                    label: copy.text(
                      sessionForBuild.hasInitialWork
                          ? 'learn.exit'
                          : 'common.back',
                    ),
                    icon: const PikoIcon(PikoIconName.arrowLeft),
                    variant: PikoButtonVariant.ghost,
                    onPressed: _exiting ? null : () => _exit(sessionForBuild),
                  ),
                ),
                if (sessionForBuild.hasInitialWork)
                  ReviewProgress(
                    direction: reviewDirectionLabel(
                      widget.collection,
                      sessionForBuild.direction,
                    ),
                    progress: sessionForBuild.progress,
                  )
                else
                  Text(
                    reviewDirectionLabel(
                      widget.collection,
                      widget.session.direction,
                    ),
                    key: const ValueKey('review-fixed-direction'),
                  ),
                if (sessionForBuild.current case final handle?)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: ReviewPromptCard(
                      key: ObjectKey(handle),
                      handle: handle,
                      repository: widget.vocabularyRepository,
                      collectionId: sessionForBuild.collectionId,
                      direction: sessionForBuild.direction,
                      canReveal: (handle) =>
                          !sessionForBuild.isStopped &&
                          !sessionForBuild.isSubmitting &&
                          identical(sessionForBuild.current, handle),
                      revealedActions: (context, canSubmit) => _gradingActions(
                        context,
                        sessionForBuild,
                        handle,
                        canSubmit,
                      ),
                    ),
                  ),
                // Initial empty membership is not regular exhaustion after grades.
                // Retry integration must also check pending reinforcement first.
                if (!widget.session.hasInitialWork)
                  Padding(
                    padding: EdgeInsets.only(
                      top: pikoDesign.dimension('spacing.5'),
                    ),
                    child: PikoCard(
                      key: const ValueKey('review-no-due'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            headingLevel: 2,
                            child: Text(
                              copy.text('learn.noDueTitle'),
                              style: TextStyle(
                                fontSize: pikoDesign.dimension(
                                  'typography.body',
                                ),
                                fontWeight: pikoDesign.weight(
                                  'typography.titleWeight',
                                ),
                                color: pikoDesign.color('ink'),
                              ),
                            ),
                          ),
                          SizedBox(height: pikoDesign.dimension('spacing.3')),
                          Text(
                            copy.text('learn.noDueBody'),
                            style: TextStyle(
                              fontSize: pikoDesign.dimension(
                                'components.emptyState.descriptionSize',
                              ),
                              height: pikoDesign.dimension(
                                'components.emptyState.descriptionLineHeight',
                              ),
                              color: pikoDesign.color('muted'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if ((sessionForBuild.hasPendingRetryWork ||
                        sessionForBuild.selectionFailed) &&
                    sessionForBuild.current == null)
                  Padding(
                    padding: EdgeInsets.only(
                      top: pikoDesign.dimension('spacing.5'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          copy.text(
                            sessionForBuild.error == null
                                ? 'learn.retryWaiting'
                                : 'learn.retryLoadFailed',
                          ),
                        ),
                        PikoButton(
                          label: copy.text('action.retry'),
                          onPressed: sessionForBuild.isSubmitting
                              ? null
                              : () {
                                  if (mounted &&
                                      identical(
                                        widget.session,
                                        sessionForBuild,
                                      ) &&
                                      ModalRoute.of(context)?.isCurrent ==
                                          true &&
                                      !sessionForBuild.isStopped) {
                                    sessionForBuild.refreshRetries();
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
