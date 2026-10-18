import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import '../../ui/piko_theme.dart';

/// Statistics actions remain focusable while a refresh temporarily disables
/// activation. Native Material disabled buttons otherwise eject keyboard focus.
/// Disabled semantics and guarded pointer/keyboard activation remain explicit.
class StatisticsAction extends StatefulWidget {
  const StatisticsAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.child,
    this.tint = false,
    this.field = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Widget? child;
  final bool tint, field;
  @override
  State<StatisticsAction> createState() => _StatisticsActionState();
}

class _StatisticsActionState extends State<StatisticsAction> {
  final focus = FocusNode();
  bool showFocus = false;
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PikoAnchorAction(
    builder: (anchorContext) {
      final enabled = widget.onPressed != null;
      final d = pikoDesign;
      final radius = d.dimension(
        widget.field ? 'components.fields.radius' : 'radii.card',
      );
      void activate() {
        if (widget.onPressed == null) return;
        PikoAnchorRegion.capture(anchorContext);
        widget.onPressed!();
      }

      final border = showFocus
          ? d.color('primary')
          : widget.field
          ? d.color('muted')
          : widget.child != null
          ? PikoTheme.border
          : Colors.transparent;
      return FocusableActionDetector(
        focusNode: focus,
        onShowFocusHighlight: (value) => setState(() => showFocus = value),
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              activate();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          enabled: enabled,
          label: widget.label,
          excludeSemantics: widget.child == null,
          onTap: enabled ? activate : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: enabled ? activate : null,
            child: Container(
              constraints: BoxConstraints(
                minHeight: d.dimension('controls.largeHeight'),
                minWidth: d.dimension('controls.largeHeight'),
              ),
              padding: EdgeInsets.all(
                d.dimension(
                  widget.child != null
                      ? 'components.statistics.padding'
                      : 'components.dropdowns.padding',
                ),
              ),
              decoration: BoxDecoration(
                color: d.color(widget.tint ? 'tint' : 'surface'),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: border,
                  width: d.dimension(
                    showFocus ? 'states.focusWidth' : 'states.borderWidth',
                  ),
                ),
              ),
              child:
                  widget.child ??
                  Opacity(
                    opacity: enabled
                        ? 1
                        : d.dimension('states.disabledOpacity'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.label,
                            textAlign: widget.field
                                ? TextAlign.start
                                : TextAlign.center,
                            style: TextStyle(
                              fontSize: d.dimension(
                                widget.field
                                    ? 'typography.body'
                                    : 'typography.control',
                              ),
                              fontWeight: d.weight(
                                widget.field
                                    ? 'typography.bodyWeight'
                                    : 'typography.controlWeight',
                              ),
                              color: d.color('ink'),
                            ),
                          ),
                        ),
                        if (widget.field)
                          const PikoIcon(PikoIconName.chevronRight),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      );
    },
  );
}
