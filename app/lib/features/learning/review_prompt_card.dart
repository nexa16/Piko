import '../../data/learning_reset.dart';
import '../../data/collections_repository.dart';
import '../../data/categories_repository.dart';
import 'learning_editor_guard.dart';
import 'package:flutter/material.dart';

import '../../data/learning_item.dart';
import '../../data/vocabulary_repository.dart';
import 'learning_prompt_card.dart';
import 'regular_grading_coordinator.dart';

/// Regular-review adapter over the shared stored self-assessment presentation.
class ReviewPromptCard extends StatelessWidget {
  const ReviewPromptCard({
    super.key,
    required this.handle,
    required this.repository,
    required this.collectionId,
    required this.direction,
    required this.canReveal,
    this.initiallyRevealed = false,
    this.collection,
    this.categoriesRepository,
    this.learningReset,
    this.editorGuard,
    this.onPendingWrites,
    this.onInactive,
    this.onLearningReset,
    this.allowEditing = true,
    this.questionActions,
    this.revealedActions,
  });

  final CollectionRecord? collection;
  final CategoriesRepository? categoriesRepository;
  final LearningResetRepository? learningReset;
  final LearningEditorGuard? editorGuard;
  final ValueChanged<Future<void>>? onPendingWrites;
  final Future<void> Function()? onInactive;
  final ValueChanged<Set<LearningDirection>>? onLearningReset;
  final bool allowEditing;
  final GradingCardHandle handle;
  final VocabularyRepository repository;
  final String collectionId;
  final LearningDirection direction;
  final bool Function(GradingCardHandle) canReveal;
  final bool initiallyRevealed;
  final Widget Function(BuildContext, bool Function())? questionActions;
  final Widget Function(BuildContext, bool Function())? revealedActions;

  @override
  Widget build(BuildContext context) => LearningPromptCard(
    presentation: handle,
    collection: collection,
    categoriesRepository: categoriesRepository,
    learningReset: learningReset,
    onLearningReset: onLearningReset,
    editorGuard: editorGuard,
    onPendingWrites: onPendingWrites,
    onInactive: onInactive,
    allowEditing: allowEditing,
    entryId: handle.item.entryId,
    repository: repository,
    collectionId: collectionId,
    direction: direction,
    scopeMatches: handle.item.direction == direction,
    canReveal: () => canReveal(handle),
    initiallyRevealed: initiallyRevealed,
    questionActions: questionActions,
    revealedActions: revealedActions,
  );
}
