import 'package:flutter/material.dart';
import '../piko_theme.dart';
import 'piko_interaction_anchor.dart';

class PikoPage extends StatelessWidget {
  const PikoPage({super.key, required Widget this.child})
    : slivers = null,
      physics = null,
      interactionAnchor = null,
      safeAreaBottom = true;
  const PikoPage.slivers({
    super.key,
    required this.slivers,
    this.physics,
    this.interactionAnchor,
    this.safeAreaBottom = true,
  }) : child = null;
  final Widget? child;
  final List<Widget>? slivers;
  final ScrollPhysics? physics;
  final PikoInteractionAnchor? interactionAnchor;
  final bool safeAreaBottom;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: safeAreaBottom,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final d = pikoDesign;
        final horizontal = d.dimension(
          constraints.maxWidth <= d.dimension('layout.mobileBreakpoint')
              ? 'layout.mobilePadding'
              : 'layout.pagePadding',
        );
        final padding = EdgeInsets.fromLTRB(
          horizontal,
          d.dimension('layout.pageTop'),
          horizontal,
          d.dimension('spacing.6'),
        );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: d.dimension('controls.contentWidth'),
            ),
            child: slivers == null
                ? SingleChildScrollView(padding: padding, child: child)
                : interactionAnchor != null
                ? interactionAnchor!.scope(
                    child: PikoAnchoredScrollView(
                      interactionAnchor: interactionAnchor!,
                      physics: physics,
                      slivers: [
                        SliverPadding(
                          padding: padding,
                          sliver: SliverMainAxisGroup(slivers: slivers!),
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    physics: physics,
                    slivers: [
                      SliverPadding(
                        padding: padding,
                        sliver: SliverMainAxisGroup(slivers: slivers!),
                      ),
                    ],
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
    this.subtitleContent,
    this.leading,
    this.actions = const [],
    this.titleContent,
    this.titleMargin,
    this.subtitleInset,
  });
  final String title;

  /// Meaningful page context, such as a Collection's language pair and count.
  /// Review direction and progress remain separate session context widgets.
  final String? subtitle;
  final Widget? subtitleContent;
  final Widget? leading;
  final List<Widget> actions;

  /// Optional inline title controls; callers retain the title's heading semantics.
  final Widget? titleContent;
  final double? titleMargin;
  final double? subtitleInset;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (leading != null || actions.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(bottom: pikoDesign.dimension('spacing.1')),
          child: leading != null && actions.isNotEmpty
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: leading!,
                      ),
                    ),
                    SizedBox(width: pikoDesign.dimension('spacing.2')),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: pikoDesign.dimension('spacing.2'),
                        runSpacing: pikoDesign.dimension('spacing.2'),
                        children: actions,
                      ),
                    ),
                  ],
                )
              : Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: pikoDesign.dimension('spacing.2'),
                  runSpacing: pikoDesign.dimension('spacing.2'),
                  children: [?leading, ...actions],
                ),
        ),
      Padding(
        padding: EdgeInsets.symmetric(
          vertical:
              titleMargin ??
              pikoDesign.dimension('components.headings.titleMargin'),
        ),
        child:
            titleContent ??
            Semantics(
              header: true,
              headingLevel: 1,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
      ),
      if (subtitle != null || subtitleContent != null)
        Padding(
          padding: EdgeInsets.only(
            left: subtitleInset ?? pikoDesign.dimension('spacing.2'),
          ),
          child:
              subtitleContent ??
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: pikoDesign.dimension('typography.small'),
                  color: pikoDesign.color('muted'),
                ),
              ),
        ),
    ],
  );
}
