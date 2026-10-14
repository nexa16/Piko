import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../piko_theme.dart';

/// One full-label checked target; the nested visual checkbox is decorative.
class PikoCheckbox extends StatefulWidget {
  const PikoCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    this.focusNode,
    this.selectedColorRole = 'primary',
    super.key,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final FocusNode? focusNode;
  final String selectedColorRole;
  @override
  State<PikoCheckbox> createState() => _PikoCheckboxState();
}

class _PikoCheckboxState extends State<PikoCheckbox> {
  bool _focused = false, _showFocus = false;
  void _toggle() => widget.onChanged?.call(!widget.value);
  @override
  Widget build(BuildContext context) {
    final d = pikoDesign, enabled = widget.onChanged != null;
    final checkboxSize = d.dimension('components.checkboxes.size');
    return Semantics(
      label: widget.label,
      checked: widget.value,
      enabled: enabled,
      focusable: enabled,
      focused: enabled && _focused,
      onTap: enabled ? _toggle : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: enabled,
          focusNode: widget.focusNode,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onFocusChange: (value) => setState(() => _focused = value),
          onShowFocusHighlight: (value) => setState(() => _showFocus = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _toggle();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _toggle : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  d.dimension('components.buttons.radius'),
                ),
                border: _showFocus && enabled
                    ? Border.all(
                        color: d.color('primary'),
                        width: d.dimension('states.focusWidth'),
                      )
                    : null,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: d.dimension('components.buttons.height'),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: d.dimension('spacing.2'),
                    vertical: d.dimension('components.checkboxes.paddingY'),
                  ),
                  child: Opacity(
                    opacity: enabled
                        ? 1
                        : d.dimension('states.disabledOpacity'),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: checkboxSize,
                          child: Center(
                            child: IgnorePointer(
                              child: ExcludeFocus(
                                child: Transform.scale(
                                  scale: checkboxSize / Checkbox.width,
                                  child: SizedBox.square(
                                    dimension: Checkbox.width,
                                    child: Checkbox(
                                      // Match the prototype's immediate native toggle.
                                      key: ValueKey(widget.value),
                                      value: widget.value,
                                      onChanged: enabled ? (_) {} : null,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      fillColor:
                                          WidgetStateProperty.resolveWith(
                                            (states) => d.color(
                                              states.contains(
                                                    WidgetState.selected,
                                                  )
                                                  ? widget.selectedColorRole
                                                  : 'surface',
                                            ),
                                          ),
                                      checkColor: d.color('onPrimary'),
                                      side: WidgetStateBorderSide.resolveWith(
                                        (states) => BorderSide(
                                          color: d.color(
                                            states.contains(
                                                  WidgetState.selected,
                                                )
                                                ? widget.selectedColorRole
                                                : 'ink',
                                          ),
                                          // Scale the visual box without scaling its semantic border.
                                          width:
                                              d.dimension(
                                                'states.borderWidth',
                                              ) *
                                              Checkbox.width /
                                              checkboxSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: d.dimension('spacing.2')),
                        Expanded(
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: d.dimension('typography.label'),
                              color: d.color('ink'),
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
      ),
    );
  }
}
