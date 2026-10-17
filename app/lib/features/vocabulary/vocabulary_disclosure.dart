import 'package:flutter/material.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';

/// Independent optional editor section. Hidden fields retain raw input/state.
class VocabularyDisclosure extends StatefulWidget {
  const VocabularyDisclosure({
    required this.label,
    required this.child,
    required this.controlKey,
    this.error = false,
    super.key,
  });
  final String label;
  final Widget child;
  final Key controlKey;
  final bool error;
  @override
  State<VocabularyDisclosure> createState() => _VocabularyDisclosureState();
}

class _VocabularyDisclosureState extends State<VocabularyDisclosure> {
  bool expanded = false;
  @override
  void initState() {
    super.initState();
    expanded = widget.error;
  }

  @override
  void didUpdateWidget(VocabularyDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error && !oldWidget.error) expanded = true;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        expanded: expanded,
        button: true,
        child: InkWell(
          key: widget.controlKey,
          onTap: () => setState(() => expanded = !expanded),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: pikoDesign.dimension('spacing.2'),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.error
                            ? pikoDesign.color('danger')
                            : pikoDesign.color('ink'),
                      ),
                    ),
                  ),
                  RotatedBox(
                    quarterTurns: expanded ? 3 : 1,
                    child: const PikoIcon(PikoIconName.chevronRight),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ExcludeFocus(
        excluding: !expanded,
        child: Offstage(offstage: !expanded, child: widget.child),
      ),
    ],
  );
}
