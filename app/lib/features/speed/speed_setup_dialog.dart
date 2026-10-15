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
    super.key,
  }) : assert(eligibleCount >= 0);

  final CollectionRecord collection;
  final LearningDirection direction;
  final int eligibleCount;

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
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final size = _poolSize;
    if (size == null || widget.eligibleCount == 0) {
      setState(() => _edited = true);
      return;
    }
    Navigator.of(context).pop(size);
  }

  @override
  void dispose() {
    _pool.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    final valid = _poolSize != null && widget.eligibleCount > 0;
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
          Text(
            widget.eligibleCount == 1
                ? copy.text('r2.speedNewOne')
                : copy.text('r2.speedNewCount', {
                    'count': widget.eligibleCount,
                  }),
            key: const ValueKey('speed-new-count'),
            style: TextStyle(fontWeight: d.weight('components.buttons.weight')),
          ),
          SizedBox(height: gap),
          Container(
            key: const ValueKey('speed-reset-warning'),
            padding: EdgeInsets.all(gap),
            decoration: BoxDecoration(
              color: d.color('warningSurface'),
              border: Border.all(
                color: d.color('warningBorder'),
                width: d.dimension('states.borderWidth'),
              ),
              borderRadius: BorderRadius.circular(
                d.dimension('components.fields.radius'),
              ),
            ),
            child: Text(
              copy.text('r2.speedResetWarning'),
              style: TextStyle(
                color: d.color('onWarning'),
                fontSize: d.dimension('typography.small'),
                height: d.dimension(
                  'components.collectionReview.titleLineHeight',
                ),
              ),
            ),
          ),
          SizedBox(height: gap),
          PikoField(
            label: copy.text('r2.pool'),
            child: Semantics(
              label: copy.text('r2.pool'),
              child: TextField(
                key: const ValueKey('speed-pool-size'),
                controller: _pool,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: pikoInputDecoration(
                  error: _edited && !valid ? copy.text('r2.poolInvalid') : null,
                ),
                onChanged: (_) => setState(() => _edited = true),
                onSubmitted: (_) => _start(),
              ),
            ),
          ),
          SizedBox(height: gap),
          Text(
            copy.text('r2.poolHint'),
            key: const ValueKey('speed-pool-hint'),
            style: TextStyle(
              color: d.color('muted'),
              fontSize: d.dimension('typography.small'),
            ),
          ),
        ],
      ),
    );
  }
}
