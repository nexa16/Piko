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
  // Expando keys do not retain popped routes. Each state explicitly releases
  // its ownership as well, so a live route never retains a retired row.
  static final _groups = Expando<_SwipeRevealGroup>('swipe-reveal-route');
  _SwipeRevealGroup? _group;
  ModalRoute<dynamic>? _route;
  Offset? start;
  int? pointer;
  bool open = false;
  int _presentation = 0;
  int _animation = 0;
  final focus = FocusNode();
  bool get enabled => widget.enabled && widget.onDelete != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final Object scope = route ?? FocusScope.of(context);
    final group = _groups[scope] ??= _SwipeRevealGroup();
    if (!identical(group, _group) || route?.isCurrent == false) {
      _close(rebuild: false);
    }
    _group = group;
    _route = route;
  }

  void _close({
    bool rebuild = true,
    bool restoreFocus = false,
    bool immediate = false,
  }) {
    final wasOpen = open;
    void clear() {
      open = false;
      _presentation++;
      if (immediate && wasOpen) _animation++;
    }

    if (open && rebuild && mounted) {
      setState(clear);
    } else {
      clear();
    }
    _group?.release(this);
    // A disabled, already-closed wrapper can contain a live text editor.
    // Rebuilds must not steal that editor's focus or trigger a caret scroll.
    if (wasOpen && focus.hasFocus) focus.unfocus();
    if (wasOpen && restoreFocus && mounted) focus.requestFocus();
  }

  void _reveal() {
    if (!enabled || _route?.isCurrent == false || open) return;
    _group!.claim(this);
    setState(() {
      open = true;
      _presentation++;
    });
    focus.requestFocus();
  }

  void _delete(int presentation) {
    if (!mounted ||
        !enabled ||
        !open ||
        presentation != _presentation ||
        _route?.isCurrent == false ||
        !identical(_group?.owner, this)) {
      return;
    }
    final delete = widget.onDelete;
    _close(restoreFocus: true);
    delete?.call();
  }

  @override
  void didUpdateWidget(PikoSwipeReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!enabled) {
      _close(rebuild: false, immediate: true);
      start = null;
      pointer = null;
    }
  }

  @override
  void dispose() {
    _group?.release(this);
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
          _close(restoreFocus: true);
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
            if (delta.dx < 0) {
              _reveal();
            } else {
              _close();
            }
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
            final presentation = _presentation;
            return TweenAnimationBuilder<double>(
              key: ValueKey(_animation),
              tween: Tween(begin: 0, end: open ? 1 : 0),
              duration: PikoTheme.motion(context),
              child: widget.child,
              builder: (context, reveal, child) {
                // A partial reveal cannot contain a full action target. Keep
                // its label/focus/semantics absent until it is wholly exposed,
                // and remove them immediately when closing or swapping rows.
                final actionReady =
                    open &&
                    enabled &&
                    reveal == 1 &&
                    identical(_group?.owner, this);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(
                    d.dimension('radii.card'),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        // A closed card's antialiased border must not blend
                        // with an otherwise hidden red deletion surface.
                        child: ColoredBox(
                          color: reveal > 0
                              ? d.color('danger')
                              : Colors.transparent,
                        ),
                      ),
                      if (actionReady)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: width,
                          child: PikoButton(
                            label: widget.label,
                            icon: const PikoIcon(PikoIconName.trash),
                            variant: PikoButtonVariant.dangerFilled,
                            onPressed: () => _delete(presentation),
                          ),
                        ),
                      // The complete underlay extends beneath the foreground's
                      // rounded trailing corners, including during close.
                      Transform.translate(
                        key: const ValueKey('swipe-foreground'),
                        offset: Offset(-width * reveal, 0),
                        child: child,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

final class _SwipeRevealGroup {
  _PikoSwipeRevealState? owner;

  void claim(_PikoSwipeRevealState next) {
    if (identical(owner, next)) return;
    // A group handoff closes the previous foreground immediately, rather than
    // leaving two revealed rows while independent animations race to finish.
    owner?._close(immediate: true);
    owner = next;
  }

  void release(_PikoSwipeRevealState state) {
    if (identical(owner, state)) owner = null;
  }
}
