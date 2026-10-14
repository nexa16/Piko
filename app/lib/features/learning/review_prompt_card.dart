import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/learning_item.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';
import 'regular_grading_coordinator.dart';

/// One current stored card; reveal is presentation only, never a grade/write.
class ReviewPromptCard extends StatefulWidget {
  const ReviewPromptCard({
    super.key,
    required this.handle,
    required this.repository,
    required this.collectionId,
    required this.direction,
    required this.canReveal,
    this.revealedActions,
  });
  final GradingCardHandle handle;
  final VocabularyRepository repository;
  final String collectionId;
  final LearningDirection direction;
  final bool Function(GradingCardHandle) canReveal;
  final Widget Function(BuildContext, bool Function())? revealedActions;
  @override
  State<ReviewPromptCard> createState() => _ReviewPromptCardState();
}

class _ReviewPromptCardState extends State<ReviewPromptCard> {
  late Stream<VocabularyRecord?> _entry;
  int _revision = 0;
  bool _revealed = false, _showFocus = false, _focused = false;
  VocabularyRecord? _visibleEntry;
  void _watch() {
    _revision++;
    _visibleEntry = null;
    _entry = widget.repository.watchById(widget.handle.item.entryId);
  }

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(ReviewPromptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle ||
        oldWidget.repository != widget.repository ||
        oldWidget.collectionId != widget.collectionId ||
        oldWidget.direction != widget.direction) {
      _revealed = false;
      _watch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return StreamBuilder<VocabularyRecord?>(
      key: ValueKey(_revision),
      stream: _entry,
      builder: (context, snapshot) {
        final revision = _revision;
        final repository = widget.repository;
        final handle = widget.handle;
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          _visibleEntry = null;
          return Text(copy.text('vocab.loading'));
        }
        final entry = snapshot.data;
        if (snapshot.hasError ||
            entry == null ||
            entry.id != widget.handle.item.entryId ||
            entry.collectionId != widget.collectionId ||
            widget.handle.item.direction != widget.direction) {
          _visibleEntry = null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy.text('vocab.loadFailed')),
              Align(
                alignment: Alignment.centerLeft,
                child: PikoButton(
                  label: copy.text('action.retry'),
                  onPressed: () {
                    if (!mounted ||
                        revision != _revision ||
                        !identical(widget.repository, repository) ||
                        !identical(widget.handle, handle) ||
                        ModalRoute.of(context)?.isCurrent != true) {
                      return;
                    }
                    setState(_watch);
                  },
                ),
              ),
            ],
          );
        }
        final prompt = widget.direction == LearningDirection.targetToNative
            ? entry.targetText
            : entry.nativeText;
        final answer = widget.direction == LearningDirection.targetToNative
            ? entry.nativeText
            : entry.targetText;
        _visibleEntry = entry;
        bool currentSnapshot() =>
            mounted &&
            revision == _revision &&
            identical(widget.handle, handle) &&
            identical(widget.repository, repository) &&
            identical(_visibleEntry, entry) &&
            widget.canReveal(handle) &&
            ModalRoute.of(context)?.isCurrent == true;
        void reveal() {
          if (_revealed || !currentSnapshot()) {
            return;
          }
          setState(() => _revealed = true);
        }

        final active = !_revealed && widget.canReveal(handle);
        final d = pikoDesign;
        return LayoutBuilder(
          builder: (context, constraints) {
            final cueStyle = TextStyle(
              fontSize: d.dimension('components.learningCard.cueSize'),
              fontWeight: d.weight('components.learningCard.cueWeight'),
              color: d.color('muted'),
            );
            final cueWidth =
                constraints.maxWidth -
                d.dimension('components.cards.padding') -
                d.dimension('components.learningCard.cueRight') -
                d.dimension('components.learningCard.cueIconSize') -
                d.dimension('components.learningCard.cueGap');
            final cueMetrics = TextPainter(
              text: TextSpan(
                text: copy.text('learn.revealCue'),
                style: DefaultTextStyle.of(context).style.merge(cueStyle),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: cueWidth > 0 ? cueWidth : 0);
            final cueHeight =
                cueMetrics.height >
                    d.dimension('components.learningCard.cueIconSize')
                ? cueMetrics.height
                : d.dimension('components.learningCard.cueIconSize');
            cueMetrics.dispose();
            final measuredBottom =
                cueHeight +
                d.dimension('components.learningCard.cueBottom') +
                d.dimension('spacing.2');
            final bindingBottom = d.dimension(
              'components.learningCard.bottomPadding',
            );
            final bottomPadding = !_revealed && measuredBottom > bindingBottom
                ? measuredBottom
                : bindingBottom;
            final content = PikoCard(
              key: const ValueKey('review-prompt'),
              padding: EdgeInsets.fromLTRB(
                d.dimension('components.cards.padding'),
                d.dimension('components.cards.padding'),
                d.dimension('components.cards.padding'),
                bottomPadding,
              ),
              constraints: BoxConstraints(
                minHeight: pikoDesign.dimension(
                  'components.learningCard.minHeight',
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      prompt,
                      key: const ValueKey('review-prompt-text'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: d.dimension(
                          _revealed
                              ? 'components.learningCard.answerPromptSize'
                              : 'components.learningCard.promptSize',
                        ),
                        fontWeight: d.weight(
                          _revealed
                              ? 'components.learningCard.answerPromptWeight'
                              : 'components.learningCard.promptWeight',
                        ),
                        color: d.color(_revealed ? 'muted' : 'ink'),
                      ),
                    ),
                    if (_revealed) ...[
                      SizedBox(
                        height: d.dimension(
                          'components.learningCard.answerGap',
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: d.dimension(
                          'components.learningCard.dividerWidthFactor',
                        ),
                        child: SizedBox(
                          height: d.dimension('states.borderWidth'),
                          child: ColoredBox(
                            color: d
                                .color('ink')
                                .withValues(
                                  alpha: d.dimension(
                                    'components.learningCard.dividerInkOpacity',
                                  ),
                                ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: d.dimension(
                          'components.learningCard.answerGap',
                        ),
                      ),
                      Text(
                        answer,
                        key: const ValueKey('review-answer-text'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: d.dimension(
                            'components.learningCard.answerSize',
                          ),
                          fontWeight: d.weight(
                            'components.learningCard.answerWeight',
                          ),
                          color: d.color('ink'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
            final card = Semantics(
              key: const ValueKey('review-reveal-target'),
              label: _revealed ? '$prompt\n$answer' : prompt,
              hint: active ? copy.text('learn.revealCue') : null,
              button: active,
              focusable: active,
              focused: active ? _focused : null,
              enabled: _revealed ? null : widget.canReveal(handle),
              onTap: active ? reveal : null,
              child: ExcludeSemantics(
                child: FocusableActionDetector(
                  enabled: active,
                  onFocusChange: (value) {
                    if (mounted) setState(() => _focused = value);
                  },
                  onShowFocusHighlight: (value) {
                    if (mounted) setState(() => _showFocus = value);
                  },
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                  },
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        reveal();
                        return null;
                      },
                    ),
                  },
                  mouseCursor: active
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: active ? reveal : null,
                    child: Stack(
                      children: [
                        content,
                        if (!_revealed)
                          Positioned(
                            left: d.dimension('components.cards.padding'),
                            right: d.dimension(
                              'components.learningCard.cueRight',
                            ),
                            bottom: d.dimension(
                              'components.learningCard.cueBottom',
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconTheme(
                                  data: IconThemeData(color: d.color('muted')),
                                  child: PikoIcon(
                                    PikoIconName.bookOpen,
                                    size: d.dimension(
                                      'components.learningCard.cueIconSize',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: d.dimension(
                                    'components.learningCard.cueGap',
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    copy.text('learn.revealCue'),
                                    key: const ValueKey('review-reveal-cue'),
                                    style: cueStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (active && _showFocus)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    d.dimension('radii.card'),
                                  ),
                                  border: Border.all(
                                    color: d.color('primary'),
                                    width: d.dimension('states.focusWidth'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                card,
                if (_revealed && widget.revealedActions != null)
                  widget.revealedActions!(
                    context,
                    () => _revealed && currentSnapshot(),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
