import 'package:flutter/material.dart';
import '../piko_theme.dart';
import 'piko_icon.dart';
import 'piko_interaction_anchor.dart';

/// Shared input/settings roles. Feature callers supply content, not insets.
class PikoFormSection extends StatelessWidget {
  const PikoFormSection({
    required this.title,
    required this.children,
    super.key,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: pikoDesign.dimension('spacing.6')),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            pikoDesign.dimension('spacing.4'),
            0,
            pikoDesign.dimension('spacing.4'),
            pikoDesign.dimension('spacing.2'),
          ),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        PikoFormGroup(children: children),
      ],
    ),
  );
}

class PikoFormGroup extends StatelessWidget {
  const PikoFormGroup({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: pikoDesign.color('surface'),
    borderRadius: BorderRadius.circular(pikoDesign.dimension('radii.card')),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: pikoDesign.dimension('states.borderWidth'),
              thickness: pikoDesign.dimension('states.borderWidth'),
              color: pikoDesign.color('tint'),
            ),
          children[i],
        ],
      ],
    ),
  );
}

class PikoFormFieldRow extends StatelessWidget {
  const PikoFormFieldRow({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(pikoDesign.dimension('spacing.4')),
    child: child,
  );
}

class PikoFormRow extends StatelessWidget {
  const PikoFormRow({
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
    this.focusNode,
    super.key,
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final color = pikoDesign.color(danger ? 'danger' : 'ink');
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null
            ? pikoDesign.dimension('states.disabledOpacity')
            : 1,
        child: InkWell(
          focusNode: focusNode,
          onTap: onTap == null
              ? null
              : () {
                  PikoAnchorRegion.capture(context);
                  onTap!();
                },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: pikoDesign.dimension('controls.largeHeight'),
            ),
            child: PikoFormFieldRow(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color: color,
                                fontWeight: pikoDesign.weight(
                                  'typography.controlWeight',
                                ),
                              ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    SizedBox(width: pikoDesign.dimension('spacing.3')),
                    IconTheme(
                      data: IconThemeData(
                        color: pikoDesign.color(danger ? 'danger' : 'primary'),
                      ),
                      child: trailing!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PikoNavigationRow extends StatelessWidget {
  const PikoNavigationRow({
    required this.title,
    this.subtitle,
    required this.onTap,
    super.key,
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => PikoFormRow(
    title: title,
    subtitle: subtitle,
    onTap: onTap,
    trailing: const PikoIcon(PikoIconName.chevronRight),
  );
}
