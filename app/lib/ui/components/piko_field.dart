import 'package:flutter/material.dart';
import '../piko_theme.dart';

InputDecoration pikoInputDecoration({String? error}) {
  final d = pikoDesign;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(
      d.dimension('components.fields.radius'),
    ),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    error: error == null ? null : Text(error, softWrap: true),
    filled: true,
    fillColor: d.color('surface'),
    contentPadding: EdgeInsets.all(d.dimension('components.fields.padding')),
    enabledBorder: border(PikoTheme.border, d.dimension('states.borderWidth')),
    disabledBorder: border(PikoTheme.border, d.dimension('states.borderWidth')),
    focusedBorder: border(
      d.color('primary'),
      d.dimension('components.fields.focusWidth'),
    ),
    errorBorder: border(d.color('danger'), d.dimension('states.borderWidth')),
    focusedErrorBorder: border(
      d.color('danger'),
      d.dimension('components.fields.focusWidth'),
    ),
  );
}

class PikoField extends StatelessWidget {
  const PikoField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: TextStyle(
          color: pikoDesign.color('muted'),
          fontSize: pikoDesign.dimension('components.fields.labelSize'),
          fontWeight: pikoDesign.weight('components.fields.labelWeight'),
        ),
      ),
      SizedBox(height: pikoDesign.dimension('components.dropdowns.gap')),
      child,
    ],
  );
}

class PikoTextField extends StatelessWidget {
  const PikoTextField({
    super.key,
    required this.label,
    required this.controller,
    this.error,
    this.onChanged,
    this.focusNode,
    this.enabled = true,
    this.style,
    this.textInputAction,
    this.onSubmitted,
    this.onEditingComplete,
    this.autofocus = false,
  });
  final String label;
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool enabled;
  final TextStyle? style;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => PikoField(
    label: label,
    child: Semantics(
      label: label,
      child: TextField(
        style: style,
        enabled: enabled,
        controller: controller,
        onChanged: onChanged,
        focusNode: focusNode,
        autofocus: autofocus,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onEditingComplete: onEditingComplete,
        decoration: pikoInputDecoration(error: error),
      ),
    ),
  );
}

class PikoDropdown<T> extends StatelessWidget {
  const PikoDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.autofocus = false,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool autofocus;
  @override
  Widget build(BuildContext context) {
    final d = pikoDesign;
    return PikoField(
      label: label,
      child: Semantics(
        label: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: d.color('surface'),
            borderRadius: BorderRadius.circular(
              d.dimension('components.dropdowns.radius'),
            ),
            border: Border.all(
              color: PikoTheme.border,
              width: d.dimension('states.borderWidth'),
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: d.dimension('components.dropdowns.height'),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: d.dimension('components.dropdowns.padding'),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  autofocus: autofocus,
                  value: value,
                  items: items,
                  onChanged: onChanged,
                  isExpanded: true,
                  itemHeight: null,
                  style: TextStyle(
                    color: d.color('ink'),
                    fontSize: d.dimension('typography.body'),
                    fontWeight: d.weight('components.dropdowns.weight'),
                  ),
                  borderRadius: BorderRadius.circular(
                    d.dimension('components.dropdowns.radius'),
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
