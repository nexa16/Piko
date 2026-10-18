import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import '../../ui/piko_theme.dart';

/// Keeps focus through temporary loading/zero states, with disabled semantics
/// and guarded pointer, keyboard and accessibility activation.
class CollectionCompactAction extends StatelessWidget {
  const CollectionCompactAction({
    super.key,
    required this.label,
    required this.count,
    required this.focusNode,
    required this.onPressed,
    this.speed = false,
  });
  final String label, count;
  final FocusNode focusNode;
  final VoidCallback? onPressed;
  final bool speed;
  @override
  Widget build(BuildContext context) => PikoAnchorAction(
    builder: (anchorContext) {
      final d = pikoDesign, enabled = onPressed != null;
      void activate() {
        if (onPressed == null) return;
        PikoAnchorRegion.capture(anchorContext);
        onPressed!();
      }

      return Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: FocusableActionDetector(
          focusNode: focusNode,
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
          child: ListenableBuilder(
            listenable: focusNode,
            builder: (_, _) => Semantics(
              button: true,
              enabled: enabled,
              label: label,
              excludeSemantics: true,
              onTap: enabled ? activate : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: enabled ? activate : null,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: d.dimension('controls.largeHeight'),
                    minHeight: d.dimension('controls.largeHeight'),
                  ),
                  padding: EdgeInsets.all(d.dimension('spacing.1')),
                  decoration: BoxDecoration(
                    color: d.color(speed ? 'gold' : 'tint'),
                    borderRadius: BorderRadius.circular(
                      d.dimension('components.buttons.radius'),
                    ),
                    border: Border.all(
                      color: focusNode.hasFocus
                          ? d.color('primary')
                          : Colors.transparent,
                      width: d.dimension('states.focusWidth'),
                    ),
                  ),
                  child: Opacity(
                    opacity: enabled
                        ? 1
                        : d.dimension('states.disabledOpacity'),
                    child: IconTheme(
                      data: IconThemeData(
                        color: d.color(speed ? 'ink' : 'primary'),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PikoIcon(
                            speed ? PikoIconName.zap : PikoIconName.rotateCcw,
                          ),
                          Text(
                            count,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: d.color(speed ? 'ink' : 'primary'),
                              fontSize: d.dimension('typography.control'),
                              fontWeight: d.weight('typography.controlWeight'),
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
        ),
      );
    },
  );
}
