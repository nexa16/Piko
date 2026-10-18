import 'package:flutter/material.dart';
import '../../data/learning_item.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/piko_theme.dart';

/// Direct mode-specific choices. Invalidation and every activation re-read
/// eligibility; a disappeared direction cannot start from an old count.
class LearningDirectionChoice extends StatefulWidget {
  const LearningDirectionChoice({
    super.key,
    required this.initial,
    required this.load,
    required this.label,
    required this.canChoose,
    required this.title,
    this.changes,
  });
  final Map<LearningDirection, int> initial;
  final Future<Map<LearningDirection, int>> Function() load;
  final String Function(LearningDirection, int) label;
  final bool Function() canChoose;
  final String title;
  final Listenable? changes;
  @override
  State<LearningDirectionChoice> createState() => _ChoiceState();
}

class _ChoiceState extends State<LearningDirectionChoice> {
  late var counts = widget.initial;
  bool loading = false;
  Object? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    widget.changes?.addListener(refresh);
  }

  @override
  void didUpdateWidget(LearningDirectionChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) {
      oldWidget.changes?.removeListener(refresh);
      widget.changes?.addListener(refresh);
    }
  }

  @override
  void dispose() {
    generation++;
    widget.changes?.removeListener(refresh);
    super.dispose();
  }

  void refresh() => load();
  Future<void> load([LearningDirection? chosen]) async {
    if (chosen != null && (loading || !widget.canChoose())) return;
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.load();
      if (!mounted || request != generation) return;
      setState(() => counts = value);
      if (chosen != null &&
          (value[chosen] ?? 0) > 0 &&
          widget.canChoose() &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(chosen);
      }
    } catch (failure) {
      if (mounted && request == generation) setState(() => error = failure);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return PikoDialog(
      purpose: PikoDialogPurpose.directChoice,
      title: widget.title,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading) Text(copy.text('collection.reviewLoading')),
          if (error != null) ...[
            Text(copy.text('collection.reviewLoadFailed')),
            PikoButton(
              label: copy.text('action.retry'),
              onPressed: loading ? null : refresh,
            ),
          ],
          if (!loading && error == null && counts.values.every((n) => n <= 0))
            Text(copy.text('collection.noLearningDirection')),
          for (final direction in LearningDirection.values)
            if ((counts[direction] ?? 0) > 0)
              Padding(
                padding: EdgeInsets.only(
                  bottom: pikoDesign.dimension('spacing.2'),
                ),
                child: PikoButton(
                  key: ValueKey('learning-direction-${direction.name}'),
                  label: widget.label(direction, counts[direction]!),
                  onPressed: loading || error != null || !widget.canChoose()
                      ? null
                      : () => load(direction),
                ),
              ),
        ],
      ),
    );
  }
}
