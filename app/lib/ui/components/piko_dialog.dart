import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/copy_scope.dart';
import '../piko_theme.dart';
import 'piko_button.dart';
import 'piko_icon.dart';

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
                    Navigator.of(dialogContext).pop();
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
    this.actions = const [],
    this.onClose,
    super.key,
  });
  final String title;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final d = pikoDesign;
    return Dialog(
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(d.dimension('spacing.6')),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Semantics(
                      namesRoute: true,
                      header: true,
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(
                              fontSize: d.dimension(
                                'components.dialogs.titleSize',
                              ),
                              fontWeight: d.weight('typography.titleWeight'),
                            ),
                      ),
                    ),
                  ),
                  SizedBox(width: d.dimension('spacing.3')),
                  PikoIconButton(
                    icon: const PikoIcon(PikoIconName.x),
                    semanticLabel: PikoCopyScope.of(
                      context,
                    ).text('common.close'),
                    onPressed:
                        onClose ??
                        () {
                          if (ModalRoute.of(context)?.isCurrent == true) {
                            Navigator.of(context).pop();
                          }
                        },
                  ),
                ],
              ),
              SizedBox(height: d.dimension('spacing.3')),
              body,
              if (actions.isNotEmpty) ...[
                SizedBox(height: d.dimension('spacing.4')),
                Wrap(
                  spacing: d.dimension('spacing.2'),
                  runSpacing: d.dimension('spacing.2'),
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
