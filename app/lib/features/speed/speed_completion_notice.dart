import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_celebration.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';

/// The owner retains the committed result until dismissal, another launch or
/// departure. This occupies its single mascot slot; compact headers omit art.
class SpeedCompletionNotice extends StatelessWidget {
  const SpeedCompletionNotice({
    super.key,
    required this.count,
    required this.onDismiss,
    this.showArtwork = true,
  }) : assert(count > 0);
  final int count;
  final VoidCallback onDismiss;
  final bool showArtwork;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('speed-completion-notice'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              count == 1
                  ? copy.text('speed.completionNoticeOne')
                  : copy.text('speed.completionNotice', {'count': count}),
            ),
          ),
          if (showArtwork) ...[
            SizedBox(
              width: pikoDesign.dimension(
                'components.collectionReview.mascotGap',
              ),
            ),
            const PikoCelebration(),
          ],
          PikoIconButton(
            semanticLabel: copy.text('speed.dismissCompletion'),
            icon: const PikoIcon(PikoIconName.x),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
