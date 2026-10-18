import 'dart:async';
import '../../data/categories_repository.dart';
import '../../data/collections_repository.dart';
import '../vocabulary/inline_vocabulary_edit_controller.dart';
import '../vocabulary/saved_vocabulary_editor.dart';
import 'learning_editor_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/learning_item.dart';
import '../../data/vocabulary_repository.dart';
import '../../data/vocabulary_content.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';
import '../../ui/components/piko_interaction_anchor.dart';

/// One current stored card; reveal is presentation only, never a grade/write.
class LearningPromptCard extends StatefulWidget {
  const LearningPromptCard({
    super.key,
    required this.presentation,
    required this.entryId,
    required this.repository,
    required this.collectionId,
    required this.direction,
    required this.canReveal,
    this.initiallyRevealed = false,
    this.questionActions,
    this.revealedActions,
    this.scopeMatches = true,
    this.onReveal,
    this.collection,
    this.categoriesRepository,
    this.editorGuard,
    this.onPendingWrites,
    this.onInactive,
    this.allowEditing = true,
  });
  final CollectionRecord? collection;
  final CategoriesRepository? categoriesRepository;
  final LearningEditorGuard? editorGuard;
  final ValueChanged<Future<void>>? onPendingWrites;
  final Future<void> Function()? onInactive;
  final bool allowEditing;
  final Object presentation;
  final String entryId;
  final VocabularyRepository repository;
  final String collectionId;
  final LearningDirection direction;
  final bool Function() canReveal;
  final bool Function()? onReveal;
  final bool scopeMatches;
  final bool initiallyRevealed;
  final Widget Function(BuildContext, bool Function())? questionActions;
  final Widget Function(BuildContext, bool Function())? revealedActions;
  @override
  State<LearningPromptCard> createState() => _LearningPromptCardState();
}

class _LearningPromptCardState extends State<LearningPromptCard> {
  InlineVocabularyEditController? _edits;
  final _target = TextEditingController(), _native = TextEditingController();
  final _targetFocus = FocusNode(), _nativeFocus = FocusNode();
  bool _opening = false, _closing = false, _inactiveScheduled = false;
  Object? _editError;
  final Set<Future<void>> _extraWrites = {};

  void _register(Future<void> work) {
    final drained = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _extraWrites.add(drained);
    unawaited(drained.whenComplete(() => _extraWrites.remove(drained)));
    widget.onPendingWrites?.call(drained);
  }

  void _editChanged() {
    if (!mounted) return;
    setState(() {});
    final edits = _edits;
    if (edits != null &&
        !edits.isSaving &&
        !edits.hasUncommittedChanges &&
        !edits.committed.active) {
      _scheduleInactive();
    }
  }

  Future<void> _openEditor() async {
    if (_opening ||
        _edits != null ||
        !widget.allowEditing ||
        !widget.canReveal()) {
      return;
    }
    final presentation = widget.presentation;
    setState(() {
      _opening = true;
      _editError = null;
    });
    widget.editorGuard?.attach(this, () async => false);
    try {
      final edits = await InlineVocabularyEditController.open(
        entryId: widget.entryId,
        collectionId: widget.collectionId,
        repository: widget.repository,
      );
      if (!mounted || !identical(widget.presentation, presentation)) {
        edits.dispose();
        return;
      }
      _edits = edits;
      _target.text = edits.draft.targetText;
      _native.text = edits.draft.nativeText;
      edits.addListener(_editChanged);
      widget.editorGuard?.attach(this, _closeEditor);
    } catch (error) {
      if (mounted) _editError = error;
      widget.editorGuard?.detach(this);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<bool> _closeEditor() async {
    if (_opening || _closing) return false;
    final edits = _edits;
    if (edits == null) return true;
    setState(() => _closing = true);
    try {
      await edits.awaitSavedEdits();
      while (_extraWrites.isNotEmpty) {
        await Future.wait(_extraWrites.toList());
      }
      if (!mounted ||
          !identical(_edits, edits) ||
          edits.error != null ||
          edits.hasUncommittedChanges) {
        return false;
      }
      _targetFocus.unfocus();
      _nativeFocus.unfocus();
      edits.removeListener(_editChanged);
      edits.dispose();
      _edits = null;
      _watch();
      widget.editorGuard?.detach(this);
      return true;
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  void _scheduleInactive() {
    if (_inactiveScheduled || widget.onInactive == null) return;
    _inactiveScheduled = true;
    final presentation = widget.presentation;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted || !identical(widget.presentation, presentation)) return;
        if (await _closeEditor()) await widget.onInactive?.call();
      } finally {
        _inactiveScheduled = false;
      }
    });
  }

  @override
  void dispose() {
    widget.editorGuard?.detach(this);
    _edits?.removeListener(_editChanged);
    _edits?.dispose();
    _target.dispose();
    _native.dispose();
    _targetFocus.dispose();
    _nativeFocus.dispose();
    super.dispose();
  }

  late Stream<VocabularyRecord?> _entry;
  int _revision = 0;
  bool _revealed = false, _showFocus = false, _focused = false;
  bool _hintRevealed = false;
  bool _showExamples = true;
  VocabularyRecord? _visibleEntry;
  void _watch() {
    _revision++;
    _visibleEntry = null;
    final repository = widget.repository,
        id = widget.entryId,
        revision = _revision;
    if (repository is QuestionExamplesRepository) {
      _entry =
          Stream.fromFuture(
            (repository as QuestionExamplesRepository).readQuestionExamples(),
          ).asyncExpand((show) {
            if (revision != _revision) {
              return const Stream<VocabularyRecord?>.empty();
            }
            _showExamples = show;
            return repository.watchById(id);
          });
    } else {
      _showExamples = true;
      _entry = repository.watchById(id);
    }
  }

  @override
  void initState() {
    super.initState();
    _revealed = widget.initiallyRevealed;
    _watch();
  }

  @override
  void didUpdateWidget(LearningPromptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentation != widget.presentation ||
        oldWidget.entryId != widget.entryId ||
        oldWidget.repository != widget.repository ||
        oldWidget.collectionId != widget.collectionId ||
        oldWidget.direction != widget.direction) {
      _revealed = widget.initiallyRevealed;
      _hintRevealed = false;
      _watch();
    }
  }

  @override
  Widget build(BuildContext context) => PikoAnchorRegion(
    key: ValueKey(widget.presentation),
    child: Builder(builder: _buildContent),
  );

  Widget _buildContent(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final edits = _edits;
    if (edits != null && widget.collection != null) {
      return PikoCard(
        key: const ValueKey('learning-answer-editor'),
        role: PikoCardRole.input,
        child: SavedVocabularyEditor(
          collection: widget.collection!,
          repository: widget.repository,
          edits: edits,
          target: _target,
          native: _native,
          targetFocus: _targetFocus,
          nativeFocus: _nativeFocus,
          categories: widget.categoriesRepository,
          busy: _closing,
          onPendingWrites: _register,
          onCollapse: () => unawaited(_closeEditor()),
        ),
      );
    }
    return StreamBuilder<VocabularyRecord?>(
      key: ValueKey(_revision),
      stream: _entry,
      builder: (context, snapshot) {
        final revision = _revision;
        final repository = widget.repository;
        final handle = widget.presentation;
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          _visibleEntry = null;
          return Text(copy.text('vocab.loading'));
        }
        final entry = snapshot.data;
        if (snapshot.hasError ||
            entry == null ||
            entry.id != widget.entryId ||
            entry.collectionId != widget.collectionId ||
            !widget.scopeMatches) {
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
                        !identical(widget.presentation, handle) ||
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
        if (!entry.active && widget.onInactive != null) {
          _visibleEntry = null;
          _scheduleInactive();
          return Text(copy.text('vocab.inactive'));
        }
        final prompt = widget.direction == LearningDirection.targetToNative
            ? entry.targetText
            : entry.nativeText;
        final answer = widget.direction == LearningDirection.targetToNative
            ? entry.nativeText
            : entry.targetText;
        final content = entry.content;
        final pairs = content.examples
            .map(
              (pair) => widget.direction == LearningDirection.targetToNative
                  ? (pair.targetText, pair.nativeText)
                  : (pair.nativeText, pair.targetText),
            )
            .toList();
        final hint = content.hintText ?? '';
        final hasHint = hint.isNotEmpty;
        final showHint =
            hasHint &&
            (_revealed ||
                _hintRevealed ||
                content.hintVisibility == HintVisibility.always);
        final hiddenHint = hasHint && !showHint;
        final spoken = [
          prompt,
          if (_revealed) answer,
          if (_revealed || _showExamples)
            for (final pair in pairs) ...[pair.$1, if (_revealed) pair.$2],
          if (showHint) hint,
        ].join('\n');
        _visibleEntry = entry;
        bool currentSnapshot() =>
            mounted &&
            revision == _revision &&
            identical(widget.presentation, handle) &&
            identical(widget.repository, repository) &&
            identical(_visibleEntry, entry) &&
            !_opening &&
            _edits == null &&
            entry.active &&
            widget.canReveal() &&
            ModalRoute.of(context)?.isCurrent == true;
        void reveal() {
          if (_revealed || !currentSnapshot()) {
            return;
          }
          if (!(widget.onReveal?.call() ?? true)) return;
          PikoAnchorRegion.capture(context);
          setState(() => _revealed = true);
        }

        final active = !_revealed && widget.canReveal();
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
                    ExcludeSemantics(
                      child: Text(
                        prompt,
                        key: const ValueKey('review-prompt-text'),
                        textAlign: TextAlign.center,
                        style:
                            (_revealed
                                    ? Theme.of(context).textTheme.displaySmall!
                                    : Theme.of(context).textTheme.displayLarge!)
                                .copyWith(
                                  color: d.color(_revealed ? 'muted' : 'ink'),
                                ),
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
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                    ],
                    if (_revealed || _showExamples)
                      for (var i = 0; i < pairs.length; i++) ...[
                        SizedBox(height: d.dimension('spacing.3')),
                        ExcludeSemantics(
                          child: Text(
                            pairs[i].$1,
                            key: ValueKey(
                              i == 0
                                  ? 'learning-prompt-example'
                                  : 'learning-prompt-example-$i',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        if (_revealed) ...[
                          SizedBox(height: d.dimension('spacing.2')),
                          ExcludeSemantics(
                            child: Text(
                              pairs[i].$2,
                              key: ValueKey(
                                i == 0
                                    ? 'learning-answer-example'
                                    : 'learning-answer-example-$i',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ],
                    if (showHint) ...[
                      SizedBox(height: d.dimension('spacing.3')),
                      ExcludeSemantics(
                        child: Text(
                          hint,
                          key: const ValueKey('learning-hint'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                    if (hiddenHint) ...[
                      SizedBox(height: d.dimension('spacing.3')),
                      PikoButton(
                        key: const ValueKey('learning-reveal-hint'),
                        label: copy.text('vocab.revealHint'),
                        variant: PikoButtonVariant.neutral,
                        onPressed: !widget.canReveal()
                            ? null
                            : () {
                                if (!currentSnapshot() ||
                                    _revealed ||
                                    _hintRevealed) {
                                  return;
                                }
                                setState(() => _hintRevealed = true);
                              },
                      ),
                    ],
                  ],
                ),
              ),
            );
            final card = Semantics(
              key: const ValueKey('review-reveal-target'),
              label: spoken,
              explicitChildNodes: hiddenHint,
              hint: active ? copy.text('learn.revealCue') : null,
              button: active,
              focusable: active,
              focused: active ? _focused : null,
              enabled: _revealed ? null : widget.canReveal(),
              onTap: active ? reveal : null,
              child: ExcludeSemantics(
                excluding: !hiddenHint,
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
                            child: ExcludeSemantics(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconTheme(
                                    data: IconThemeData(
                                      color: d.color('muted'),
                                    ),
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
                if (_revealed &&
                    widget.allowEditing &&
                    widget.collection != null &&
                    widget.repository is VocabularyContentRepository)
                  Stack(
                    children: [
                      card,
                      Positioned(
                        top: 0,
                        right: 0,
                        child: PikoIconButton(
                          key: const ValueKey('learning-edit-answer'),
                          icon: const PikoIcon(PikoIconName.pencil),
                          semanticLabel: copy.text('vocab.inlineEdit'),
                          onPressed: _opening || !currentSnapshot()
                              ? null
                              : () => _register(_openEditor()),
                        ),
                      ),
                    ],
                  )
                else
                  card,
                if (_editError != null) Text(copy.text('entry.saveFailed')),
                if (!_revealed && widget.questionActions != null)
                  widget.questionActions!(
                    context,
                    () => !_revealed && currentSnapshot(),
                  ),
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
