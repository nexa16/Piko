import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/piko_theme.dart';
import 'vocabulary_selection.dart';

/// Content-sized controls. The owner overlays nonempty selection and measures
/// its actual footprint; active-zero controls belong to ordinary list chrome.
class VocabularySelectionPanel extends StatelessWidget {
  const VocabularySelectionPanel({
    super.key,
    required this.selection,
    required this.matchingIds,
    required this.enabled,
    this.onHeightChanged,
  });
  final VocabularySelection selection;
  final List<String> matchingIds;
  final bool enabled;
  final ValueChanged<double>? onHeightChanged;
  @override
  Widget build(BuildContext context) {
    if (!selection.active) return const SizedBox.shrink();
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    final gap = d.dimension('spacing.2');
    final hidden = selection.hidden(matchingIds);
    final media = MediaQuery.of(context);
    final controls = Wrap(
      spacing: gap,
      runSpacing: gap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            copy.text('selection.count', {'count': selection.ids.length}),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        PikoButton(
          key: const ValueKey('vocabulary-select-all'),
          label: copy.text('selection.all'),
          variant: PikoButtonVariant.ghost,
          onPressed: enabled && matchingIds.any((id) => !selection.contains(id))
              ? () => selection.selectAll(matchingIds)
              : null,
        ),
        PikoButton(
          key: const ValueKey('vocabulary-clear-selection'),
          label: copy.text('selection.clear'),
          variant: PikoButtonVariant.ghost,
          onPressed: enabled ? selection.clear : null,
        ),
        if (hidden > 0)
          Text(
            copy.text('selection.hidden', {'count': hidden}),
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
    return _PanelMeasure(
      onHeightChanged: onHeightChanged,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            d.dimension('layout.mobilePadding'),
            gap,
            d.dimension('layout.mobilePadding'),
            gap,
          ),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: d.dimension('controls.contentWidth'),
                maxHeight:
                    (media.size.height -
                        media.viewInsets.bottom -
                        media.padding.vertical) *
                    d.dimension(
                      'components.selectionPanel.maxViewportFraction',
                    ),
              ),
              child: Material(
                key: const ValueKey('vocabulary-selection-panel'),
                color: d.color('tint'),
                borderRadius: BorderRadius.circular(d.dimension('radii.card')),
                child: SingleChildScrollView(
                  key: const ValueKey('vocabulary-selection-scroll'),
                  padding: EdgeInsets.all(d.dimension('spacing.3')),
                  child: controls,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelMeasure extends SingleChildRenderObjectWidget {
  const _PanelMeasure({required this.onHeightChanged, required super.child});
  final ValueChanged<double>? onHeightChanged;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PanelRender(onHeightChanged);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _PanelRender renderObject,
  ) => renderObject.callback = onHeightChanged;
}

class _PanelRender extends RenderProxyBox {
  _PanelRender(this.callback);
  ValueChanged<double>? callback;
  double? previous;
  @override
  void performLayout() {
    super.performLayout();
    if (previous == size.height) return;
    previous = size.height;
    final height = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) callback?.call(height);
    });
  }
}
