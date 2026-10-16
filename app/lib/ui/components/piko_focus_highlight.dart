import 'package:flutter/material.dart';

/// Visible focus is for hardware-keyboard navigation, not retained touch focus.
class PikoFocusHighlight extends StatefulWidget {
  const PikoFocusHighlight({super.key, required this.builder});
  final Widget Function(BuildContext context, bool visible) builder;

  @override
  State<PikoFocusHighlight> createState() => _PikoFocusHighlightState();
}

class _PikoFocusHighlightState extends State<PikoFocusHighlight> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_changed);
  }

  void _changed(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    FocusManager.instance.highlightMode == FocusHighlightMode.traditional,
  );
}
