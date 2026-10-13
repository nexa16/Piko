import 'package:flutter/material.dart';
import '../piko_theme.dart';

class PikoPage extends StatelessWidget {
  const PikoPage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final d = pikoDesign;
        final horizontal = d.dimension(
          constraints.maxWidth <= d.dimension('layout.mobileBreakpoint')
              ? 'layout.mobilePadding'
              : 'layout.pagePadding',
        );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: d.dimension('controls.contentWidth'),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                d.dimension('layout.pageTop'),
                horizontal,
                d.dimension('spacing.6'),
              ),
              child: child,
            ),
          ),
        );
      },
    ),
  );
}

class PikoHeading extends StatelessWidget {
  const PikoHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });
  final String title;

  /// Meaningful page context, such as a Collection's language pair and count.
  /// Review direction and progress remain separate session context widgets.
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (leading != null || actions.isNotEmpty)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: pikoDesign.dimension('spacing.2'),
          runSpacing: pikoDesign.dimension('spacing.2'),
          children: [?leading, ...actions],
        ),
      Semantics(
        header: true,
        headingLevel: 1,
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (subtitle != null)
        Text(
          subtitle!,
          style: TextStyle(
            fontSize: pikoDesign.dimension('typography.small'),
            color: pikoDesign.color('muted'),
          ),
        ),
    ],
  );
}
