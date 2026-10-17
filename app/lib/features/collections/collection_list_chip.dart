import 'package:flutter/material.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import '../../ui/piko_theme.dart';

/// Reserves the same label, count and trailing target in every state.
class CollectionListChip extends StatefulWidget {
  const CollectionListChip({
    super.key,
    required this.label,
    required this.active,
    required this.resetLabel,
    required this.onOpen,
    required this.onReset,
    this.count,
    this.countCapacity = 0,
  });
  final String label, resetLabel;
  final bool active;
  final int? count;
  final int countCapacity;
  final VoidCallback? onOpen, onReset;
  @override
  State<CollectionListChip> createState() => _CollectionListChipState();
}

class _CollectionListChipState extends State<CollectionListChip> {
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontSize: pikoDesign.dimension('typography.label'),
      fontWeight: FontWeight.bold,
      color: pikoDesign.color('primary'),
    );
    final label = widget.label;
    final reserve = widget.count == null ? '' : ' (${widget.countCapacity})';
    final measure = TextPainter(
      text: TextSpan(text: label + reserve, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width =
        (measure.width.ceilToDouble() + pikoDesign.dimension('spacing.3'))
            .clamp(
              pikoDesign.dimension('controls.largeHeight'),
              double.infinity,
            ) +
        pikoDesign.dimension('controls.largeHeight') +
        2 * pikoDesign.dimension('states.borderWidth');
    measure.dispose();
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        pikoDesign.dimension('components.buttons.radius'),
      ),
      side: BorderSide(
        color: widget.active
            ? pikoDesign.color('tint')
            : pikoDesign
                  .color('muted')
                  .withValues(
                    alpha: pikoDesign.dimension(
                      'components.collectionList.outlineOpacity',
                    ),
                  ),
      ),
    );
    return PikoAnchorRegion(
      child: Builder(
        builder: (anchorContext) => SizedBox(
          width: width,
          child: Material(
            color: widget.active
                ? pikoDesign.color('tint')
                : pikoDesign.color('surface'),
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.all(
                pikoDesign.dimension('states.borderWidth'),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: InkWell(
                      focusNode: focus,
                      onTap: widget.onOpen == null
                          ? null
                          : () {
                              PikoAnchorRegion.capture(anchorContext);
                              widget.onOpen!();
                            },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: pikoDesign.dimension(
                            'controls.largeHeight',
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: pikoDesign.dimension('spacing.3'),
                          ),
                          child: Align(
                            widthFactor: 1,
                            child: Semantics(
                              label:
                                  label +
                                  (widget.count != null && widget.count! > 0
                                      ? ' (${widget.count})'
                                      : ''),
                              excludeSemantics: true,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Opacity(
                                    opacity: 0,
                                    child: Text(label + reserve, style: style),
                                  ),
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        label +
                                            (widget.count != null &&
                                                    widget.count! > 0
                                                ? ' (${widget.count})'
                                                : ''),
                                        style: style,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: widget.active ? widget.resetLabel : label,
                    enabled: widget.onOpen != null,
                    child: Tooltip(
                      message: widget.active ? widget.resetLabel : label,
                      child: InkWell(
                        onTap: widget.active && widget.onReset != null
                            ? () {
                                PikoAnchorRegion.capture(anchorContext);
                                widget.onReset!();
                                focus.requestFocus();
                              }
                            : widget.onOpen == null
                            ? null
                            : () {
                                PikoAnchorRegion.capture(anchorContext);
                                widget.onOpen!();
                              },
                        child: SizedBox(
                          width: pikoDesign.dimension('controls.largeHeight'),
                          height: pikoDesign.dimension('controls.largeHeight'),
                          child: Center(
                            child: IconTheme(
                              data: IconThemeData(
                                color: pikoDesign.color('primary'),
                              ),
                              child: widget.active
                                  ? const PikoIcon(PikoIconName.x, size: 20)
                                  : const RotatedBox(
                                      quarterTurns: 1,
                                      child: PikoIcon(
                                        PikoIconName.chevronRight,
                                        size: 20,
                                      ),
                                    ),
                            ),
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
      ),
    );
  }
}
