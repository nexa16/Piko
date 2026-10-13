import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../piko_theme.dart';
import 'piko_button.dart';
import 'piko_icon.dart';

/// Touch reveal only: the gesture never invokes the destructive callback.
/// Disable for editors so horizontal text selection remains native.
class PikoSwipeReveal extends StatefulWidget {
  const PikoSwipeReveal({
    super.key,
    required this.child,
    required this.label,
    required this.onDelete,
    this.enabled = true,
  });
  final Widget child;
  final String label;
  final VoidCallback? onDelete;
  final bool enabled;
  @override
  State<PikoSwipeReveal> createState() => _PikoSwipeRevealState();
}

class _PikoSwipeRevealState extends State<PikoSwipeReveal> {
  Offset? start;
  int? pointer;
  bool open = false;
  final focus = FocusNode();
  bool get enabled => widget.enabled && widget.onDelete != null;
  @override
  void didUpdateWidget(PikoSwipeReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!enabled) {
      open = false;
      start = null;
      pointer = null;
    }
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = pikoDesign;
    return Focus(
      focusNode: focus,
      onKeyEvent: (_, event) {
        if (open &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() => open = false);
          focus.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (event) {
          if (enabled &&
              event.kind == PointerDeviceKind.touch &&
              pointer == null) {
            pointer = event.pointer;
            start = event.position;
          }
        },
        onPointerCancel: (_) {
          start = null;
          pointer = null;
        },
        onPointerUp: (event) {
          if (event.pointer != pointer || start == null) return;
          final delta = event.position - start!;
          start = null;
          pointer = null;
          if (enabled &&
              delta.dx.abs() > d.dimension('components.swipe.revealDistance') &&
              delta.dx.abs() >
                  delta.dy.abs() *
                      d.dimension('components.swipe.axisDominance')) {
            setState(() => open = delta.dx < 0);
            if (open) focus.requestFocus();
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final text = TextPainter(
              text: TextSpan(
                text: widget.label,
                style: TextStyle(
                  fontSize: d.dimension('typography.label'),
                  fontWeight: d.weight('components.buttons.weight'),
                ),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final width = math.min(
              constraints.maxWidth,
              text.width +
                  d.dimension('components.icons.size') +
                  d.dimension('spacing.2') +
                  2 * d.dimension('components.buttons.padding'),
            );
            text.dispose();
            return ClipRRect(
              borderRadius: BorderRadius.circular(d.dimension('radii.card')),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: PikoTheme.motion(context),
                    transform: Matrix4.translationValues(
                      open ? -width : 0,
                      0,
                      0,
                    ),
                    child: widget.child,
                  ),
                  if (open)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: width,
                      child: ColoredBox(
                        color: d.color('surface'),
                        child: Center(
                          child: PikoButton(
                            label: widget.label,
                            icon: const PikoIcon(PikoIconName.trash),
                            variant: PikoButtonVariant.dangerGhost,
                            onPressed: () {
                              setState(() => open = false);
                              focus.requestFocus();
                              widget.onDelete?.call();
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
