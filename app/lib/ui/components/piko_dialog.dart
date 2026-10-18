import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../shared/copy_scope.dart';
import '../piko_theme.dart';
import 'piko_button.dart';
import 'piko_icon.dart';
import 'piko_interaction_anchor.dart';

enum PikoDialogPurpose { form, confirmation, selection, directChoice, summary }

enum PikoDialogActionRole { primary, safe, destructive }

/// Explicit outcomes, in safe-then-affirmative order. The shared footer adapts
/// layout and traversal together, without guessing the meaning from copy.
final class PikoDialogAction {
  const PikoDialogAction({
    required this.label,
    required this.onPressed,
    this.role = PikoDialogActionRole.primary,
    this.icon,
    this.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final PikoDialogActionRole role;
  final Widget? icon;
  final Key? key;
}

/// Null means safe dismissal; only an explicit action returns a result.
Future<T?> showPikoDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  ValueChanged<ModalRoute<T>>? onRouteCreated,
  bool Function()? canRestoreFocus,
  bool Function()? canDismiss,
}) async {
  final opener = FocusManager.instance.primaryFocus;
  try {
    return await showDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor:
          Color(
            0xff000000 |
                int.parse(
                  pikoDesign
                      .text('components.dialogs.backdropColor')
                      .substring(1),
                  radix: 16,
                ),
          ).withValues(
            alpha: pikoDesign.dimension('components.dialogs.backdropOpacity'),
          ),
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      requestFocus: true,
      animationStyle: AnimationStyle(
        duration: PikoTheme.motion(context),
        reverseDuration: PikoTheme.motion(context),
      ),
      builder: (dialogContext) {
        final route = ModalRoute.of<T>(dialogContext);
        if (route != null) onRouteCreated?.call(route);
        return Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
          },
          child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  if (ModalRoute.of(dialogContext)?.isCurrent == true &&
                      (canDismiss?.call() ?? true)) {
                    Navigator.of(dialogContext).maybePop();
                  }
                  return null;
                },
              ),
            },
            child: Builder(builder: builder),
          ),
        );
      },
    );
  } finally {
    if ((canRestoreFocus?.call() ?? true) &&
        opener?.context?.mounted == true &&
        opener!.canRequestFocus) {
      opener.requestFocus();
    }
  }
}

class PikoDialog extends StatelessWidget {
  const PikoDialog({
    required this.title,
    required this.body,
    this.titleContent,
    this.actions = const [],
    this.purpose = PikoDialogPurpose.form,
    this.dismissible = true,
    this.onClose,
    this.closeLabel,
    super.key,
  });
  final String title;

  /// Optional icon/title composition; [title] remains the route's spoken name.
  final Widget? titleContent;
  final Widget body;
  final List<PikoDialogAction> actions;
  final PikoDialogPurpose purpose;
  final bool dismissible;
  final VoidCallback? onClose;
  final String? closeLabel;

  @override
  Widget build(BuildContext context) {
    final d = pikoDesign;
    final titleStyle = Theme.of(context).textTheme.titleMedium!;
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) *
        (titleStyle.height ?? 1);
    final target = d.dimension('controls.largeHeight');
    return PopScope(
      canPop: dismissible,
      child: Dialog(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        constraints: BoxConstraints(
          minWidth: 0,
          maxWidth: d.dimension('components.dialogs.maxWidth'),
        ),
        insetAnimationDuration: PikoTheme.motion(context),
        backgroundColor: d.color('surface'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(d.dimension('radii.dialog')),
        ),
        insetPadding: EdgeInsets.all(d.dimension('spacing.4')),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: d.dimension('components.dialogs.maxWidth'),
          ),
          child: _DialogContents(
            purpose: purpose,
            body: body,
            actions: actions,
            header: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: ((target - lineHeight) / 2).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: Semantics(
                      namesRoute: true,
                      header: true,
                      label: title,
                      excludeSemantics: true,
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.titleMedium!,
                        child: titleContent ?? Text(title),
                      ),
                    ),
                  ),
                ),
                if (purpose != PikoDialogPurpose.confirmation) ...[
                  SizedBox(width: d.dimension('spacing.3')),
                  Padding(
                    padding: EdgeInsets.only(
                      top: ((lineHeight - target) / 2).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: d.dimension('controls.largeHeight'),
                      child: PikoIconButton(
                        icon: const PikoIcon(PikoIconName.x),
                        semanticLabel:
                            closeLabel ??
                            PikoCopyScope.of(context).text('common.close'),
                        onPressed: !dismissible
                            ? null
                            : onClose ??
                                  () {
                                    if (ModalRoute.of(context)?.isCurrent ==
                                        true) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogContents extends StatelessWidget {
  const _DialogContents({
    required this.header,
    required this.body,
    required this.actions,
    required this.purpose,
  });
  final Widget header, body;
  final List<PikoDialogAction> actions;
  final PikoDialogPurpose purpose;

  @override
  Widget build(BuildContext context) {
    final d = pikoDesign;
    return Padding(
      padding: EdgeInsets.all(d.dimension('spacing.6')),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          SizedBox(height: d.dimension('spacing.3')),
          Flexible(
            child: PikoAnchoredBoxScrollView(
              key: const ValueKey('selection-dialog-body'),
              child: body,
            ),
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(height: d.dimension('spacing.4')),
            _DialogFooter(
              actions: actions,
              focusSafe: purpose == PikoDialogPurpose.confirmation,
            ),
          ],
        ],
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({required this.actions, required this.focusSafe});
  final List<PikoDialogAction> actions;
  final bool focusSafe;

  @override
  Widget build(BuildContext context) {
    final d = pikoDesign;
    final gap = d.dimension('spacing.2');
    final touch = d.dimension('controls.largeHeight');
    final labelStyle = Theme.of(context).textTheme.labelLarge!;
    double naturalWidth(PikoDialogAction action) {
      final painter = TextPainter(
        text: TextSpan(text: action.label, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width =
          painter.width.ceilToDouble() +
          d.dimension('components.buttons.padding') * 2 +
          (action.icon == null
              ? 0
              : d.dimension('components.icons.size') + gap);
      painter.dispose();
      return width < touch ? touch : width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = actions.map(naturalWidth).toList();
        final stacked =
            widths.fold<double>(0, (sum, width) => sum + width) +
                gap * (actions.length - 1) >
            constraints.maxWidth;
        final ordered = stacked ? actions.reversed.toList() : actions;
        final buttons = <Widget>[
          for (var index = 0; index < ordered.length; index++)
            FocusTraversalOrder(
              order: NumericFocusOrder(index.toDouble()),
              child: Semantics(
                sortKey: OrdinalSortKey(index.toDouble()),
                child: SizedBox(
                  width: stacked
                      ? double.infinity
                      : naturalWidth(ordered[index]),
                  child: PikoButton(
                    key: ordered[index].key,
                    label: ordered[index].label,
                    icon: ordered[index].icon,
                    onPressed: ordered[index].onPressed,
                    minimumSize: Size(touch, touch),
                    autofocus:
                        focusSafe &&
                        ordered[index].role == PikoDialogActionRole.safe,
                    variant: switch (ordered[index].role) {
                      PikoDialogActionRole.safe => PikoButtonVariant.neutral,
                      PikoDialogActionRole.destructive =>
                        PikoButtonVariant.dangerFilled,
                      PikoDialogActionRole.primary => PikoButtonVariant.primary,
                    },
                  ),
                ),
              ),
            ),
        ];
        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < buttons.length; index++) ...[
                      if (index > 0) SizedBox(height: gap),
                      buttons[index],
                    ],
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var index = 0; index < buttons.length; index++) ...[
                      if (index > 0) SizedBox(width: gap),
                      buttons[index],
                    ],
                  ],
                ),
        );
      },
    );
  }
}
