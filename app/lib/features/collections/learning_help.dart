import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';

class LearningHelpMetadata extends StatefulWidget {
  const LearningHelpMetadata({super.key, required this.metadata});
  final String metadata;
  @override
  State<LearningHelpMetadata> createState() => _LearningHelpMetadataState();
}

class _LearningHelpMetadataState extends State<LearningHelpMetadata> {
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          widget.metadata,
          style: TextStyle(
            fontSize: pikoDesign.dimension('typography.small'),
            color: pikoDesign.color('muted'),
          ),
        ),
      ),
      PikoIconButton(
        key: const ValueKey('collection-learning-help'),
        focusNode: focus,
        icon: const PikoIcon(PikoIconName.info, size: 20),
        semanticLabel: PikoCopyScope.of(context).text('learnHelp.title'),
        onPressed: () {
          focus.requestFocus();
          showPikoDialog<void>(
            context,
            builder: (_) => const LearningHelpDialog(),
          );
        },
      ),
    ],
  );
}

class LearningHelpDialog extends StatelessWidget {
  const LearningHelpDialog({super.key});
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    Widget paragraph(String key, {bool heading = false}) => Padding(
      padding: EdgeInsets.only(bottom: pikoDesign.dimension('spacing.3')),
      child: Text(
        copy.text('learnHelp.$key'),
        style: heading ? Theme.of(context).textTheme.titleSmall : null,
      ),
    );
    return PikoDialog(
      title: copy.text('learnHelp.title'),
      closeLabel: copy.text('learnHelp.close'),
      purpose: PikoDialogPurpose.directChoice,
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final key in [
            'intro',
            'recall',
            'correct',
            'incorrect',
            'honest',
          ])
            paragraph(key),
          for (final key in ['return', 'mistake', 'speed']) ...[
            paragraph('${key}Title', heading: true),
            paragraph(key),
          ],
          ExpansionTile(
            key: const ValueKey('learning-help-scheduling'),
            tilePadding: EdgeInsets.zero,
            title: Text(copy.text('learnHelp.scheduling')),
            children: [
              for (final key in ['fsrs', 'ratings', 'extra', 'expiry'])
                paragraph(key),
            ],
          ),
        ],
      ),
    );
  }
}
