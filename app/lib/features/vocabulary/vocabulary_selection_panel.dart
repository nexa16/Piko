import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/piko_theme.dart';
import 'vocabulary_selection.dart';

/// The measured panel footprint is reserved even before selection starts.
/// Hidden-count space is retained to avoid resizing when a filter hides a word.
class VocabularySelectionPanel extends StatelessWidget {
  const VocabularySelectionPanel({
    super.key,
    required this.selection,
    required this.matchingIds,
    required this.enabled,
    this.speedAction,
  });
  final VocabularySelection selection;
  final List<String> matchingIds;
  final bool enabled;
  final Widget? speedAction;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final gap = pikoDesign.dimension('spacing.2');
    final hidden = selection.hidden(matchingIds);
    final media = MediaQuery.of(context);
    // Reserve a stable footprint without starving the list at large text or
    // above the keyboard. All panel actions remain reachable by scrolling.
    final panelLimit =
        (media.size.height - media.viewInsets.bottom - media.padding.vertical) *
        pikoDesign.dimension('components.selectionPanel.maxViewportFraction');
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          pikoDesign.dimension('layout.mobilePadding'),
          gap,
          pikoDesign.dimension('layout.mobilePadding'),
          gap,
        ),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: pikoDesign.dimension('controls.contentWidth'),
            ),
            child: Visibility(
              visible: selection.active,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: panelLimit),
                child: SingleChildScrollView(
                  key: const ValueKey('vocabulary-selection-scroll'),
                  child: Container(
                    key: const ValueKey('vocabulary-selection-panel'),
                    padding: EdgeInsets.all(pikoDesign.dimension('spacing.3')),
                    decoration: BoxDecoration(
                      color: pikoDesign.color('tint'),
                      boxShadow: [
                        BoxShadow(
                          color: pikoDesign
                              .color('ink')
                              .withValues(
                                alpha: pikoDesign.dimension(
                                  'states.borderInkOpacity',
                                ),
                              ),
                          offset: Offset(0, gap),
                          blurRadius: pikoDesign.dimension('spacing.6'),
                        ),
                      ],
                      border: Border.all(
                        color: pikoDesign.color('primary'),
                        width: pikoDesign.dimension('states.borderWidth'),
                      ),
                      borderRadius: BorderRadius.circular(
                        pikoDesign.dimension('components.buttons.radius'),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            copy.text('selection.count', {
                              'count': selection.ids.length,
                            }),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        Opacity(
                          opacity: hidden == 0 ? 0 : 1,
                          child: ExcludeSemantics(
                            excluding: hidden == 0,
                            child: Text(
                              copy.text('selection.hidden', {'count': hidden}),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        SizedBox(height: gap),
                        Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            ?speedAction,
                            PikoButton(
                              key: const ValueKey('vocabulary-select-all'),
                              label: copy.text('selection.all'),
                              variant: PikoButtonVariant.ghost,
                              onPressed:
                                  enabled &&
                                      matchingIds.any(
                                        (id) => !selection.contains(id),
                                      )
                                  ? () => selection.selectAll(matchingIds)
                                  : null,
                            ),
                            PikoButton(
                              key: const ValueKey('vocabulary-clear-selection'),
                              label: copy.text('selection.clear'),
                              variant: PikoButtonVariant.ghost,
                              onPressed: selection.clear,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
