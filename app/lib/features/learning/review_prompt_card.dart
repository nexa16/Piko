import 'package:flutter/material.dart';
import '../../data/learning_item.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/piko_theme.dart';
import 'regular_grading_coordinator.dart';

/// Current stored prompt only. Reveal and the answer presentation follow later.
class ReviewPromptCard extends StatefulWidget {
  const ReviewPromptCard({
    super.key,
    required this.handle,
    required this.repository,
    required this.collectionId,
    required this.direction,
  });
  final GradingCardHandle handle;
  final VocabularyRepository repository;
  final String collectionId;
  final LearningDirection direction;
  @override
  State<ReviewPromptCard> createState() => _ReviewPromptCardState();
}

class _ReviewPromptCardState extends State<ReviewPromptCard> {
  late Stream<VocabularyRecord?> _entry;
  int _revision = 0;
  void _watch() {
    _revision++;
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
          return Text(copy.text('vocab.loading'));
        }
        final entry = snapshot.data;
        if (snapshot.hasError ||
            entry == null ||
            entry.id != widget.handle.item.entryId ||
            entry.collectionId != widget.collectionId ||
            widget.handle.item.direction != widget.direction) {
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
        return PikoCard(
          key: const ValueKey('review-prompt'),
          constraints: BoxConstraints(
            minHeight: pikoDesign.dimension(
              'components.learningCard.minHeight',
            ),
          ),
          child: Center(
            child: Text(
              prompt,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: pikoDesign.dimension(
                  'components.learningCard.promptSize',
                ),
                fontWeight: pikoDesign.weight(
                  'components.learningCard.promptWeight',
                ),
                color: pikoDesign.color('ink'),
              ),
            ),
          ),
        );
      },
    );
  }
}
