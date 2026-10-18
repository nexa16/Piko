import 'package:flutter/material.dart';

import '../../data/collections_repository.dart';
import '../../data/learning_item.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/piko_theme.dart';
import '../learning/review_launch.dart' show reviewDirectionLabel;
import 'speed_learning_session.dart';
import 'speed_session.dart';

/// The launch owner supplies an immutable snapshot of its visible entry IDs.
/// Eligibility is rechecked by the authoritative data boundary at launch.
typedef SpeedSessionFactory =
    Future<SpeedLearningSession> Function({
      required String collectionId,
      required LearningDirection direction,
      required Set<String> visibleEntryIds,
      required int poolSize,
    });

typedef SelectedSpeedSessionFactory =
    Future<SpeedLearningSession> Function({
      required String collectionId,
      required LearningDirection direction,
      required List<String> orderedEntryIds,
      required int poolSize,
    });

/// Setup returns only the configured pool size; dismissal returns no launch.
Future<int?> showSpeedSetup(
  BuildContext context, {
  required CollectionRecord collection,
  required LearningDirection direction,
  required int eligibleCount,
  bool Function()? canRestoreFocus,
  ValueChanged<ModalRoute<int>>? onRouteCreated,
}) {
  if (eligibleCount <= 0) return Future.value(null);
  return showPikoDialog<int>(
    context,
    canRestoreFocus: canRestoreFocus,
    onRouteCreated: onRouteCreated,
    builder: (_) => SpeedSetupDialog(
      collection: collection,
      direction: direction,
      eligibleCount: eligibleCount,
    ),
  );
}

class SpeedSetupDialog extends StatefulWidget {
  const SpeedSetupDialog({
    required this.collection,
    required this.direction,
    required this.eligibleCount,
    this.selectionDetails,
    this.onStart,
    this.busy = false,
    super.key,
  }) : assert(eligibleCount >= 0);

  final CollectionRecord collection;
  final LearningDirection direction;
  final int eligibleCount;
  final Widget? selectionDetails;
  final ValueChanged<int>? onStart;
  final bool busy;

  @override
  State<SpeedSetupDialog> createState() => _SpeedSetupDialogState();
}

class _SpeedSetupDialogState extends State<SpeedSetupDialog> {
  final _pool = TextEditingController(text: '${SpeedSession.defaultPoolSize}');
  bool _edited = false;

  int? get _poolSize {
    final raw = _pool.text.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(raw)) return null;
    final value = int.tryParse(raw);
    return value != null && value >= 1 && value <= SpeedSession.maxPoolSize
        ? value
        : null;
  }

  void _start() {
    if (!mounted || widget.busy || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final size = _poolSize;
    if (size == null || widget.eligibleCount == 0) {
      setState(() => _edited = true);
      return;
    }
    if (widget.onStart != null) {
      widget.onStart!(size);
    } else {
      Navigator.of(context).pop(size);
    }
  }

  @override
  void dispose() {
    _pool.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    final valid = !widget.busy && _poolSize != null && widget.eligibleCount > 0;
    final gap = d.dimension('spacing.3');
    return PikoDialog(
      purpose: PikoDialogPurpose.form,
      title: copy.text('learn.speedTitle'),
      actions: [
        PikoDialogAction(
          label: copy.text('learn.startSpeed'),
          onPressed: valid ? _start : null,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reviewDirectionLabel(widget.collection, widget.direction),
            key: const ValueKey('speed-fixed-direction'),
            style: TextStyle(color: d.color('muted')),
          ),
          SizedBox(height: gap),
          if (widget.selectionDetails != null)
            widget.selectionDetails!
          else
            Text(
              widget.eligibleCount == 1
                  ? copy.text('r2.speedNewOne')
                  : copy.text('r2.speedNewCount', {
                      'count': widget.eligibleCount,
                    }),
              key: const ValueKey('speed-new-count'),
              style: TextStyle(
                fontWeight: d.weight('components.buttons.weight'),
              ),
            ),
          SizedBox(height: gap),
          PikoField(
            label: copy.text('r2.pool'),
            child: Semantics(
              label: copy.text('r2.pool'),
              child: TextField(
                key: const ValueKey('speed-pool-size'),
                readOnly: widget.busy,
                controller: _pool,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: pikoInputDecoration(
                  error: _edited && _poolSize == null
                      ? copy.text('r2.poolInvalid')
                      : null,
                ),
                onChanged: (_) => setState(() => _edited = true),
                onSubmitted: (_) => _start(),
              ),
            ),
          ),
          SizedBox(height: gap),
          for (final section in [
            ('speed.rulesTitle', 'speed.rulesExplanation'),
            ('speed.leavingTitle', 'speed.exitExplanation'),
          ]) ...[
            Text(
              copy.text(section.$1),
              style: TextStyle(
                fontWeight: d.weight('components.buttons.weight'),
              ),
            ),
            SizedBox(height: d.dimension('spacing.2')),
            Text(copy.text(section.$2)),
            SizedBox(height: gap),
          ],
        ],
      ),
    );
  }
}
