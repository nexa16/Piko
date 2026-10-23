import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../piko_theme.dart';

/// Intrinsically sized, pinned header with one painted/semantic presentation.
/// Both children stay mounted so a collapse never disposes an admitted launch,
/// rename draft or popup owner. Unlike extent prototypes, neither child is a
/// duplicate measurement tree with a second set of stateful controls.
class PikoCollapsingHeader extends StatefulWidget {
  const PikoCollapsingHeader({
    super.key,
    required this.expanded,
    required this.compact,
    required this.onCompactChanged,
    this.keepExpanded = false,
  });
  final Widget expanded, compact;
  final ValueChanged<bool> onCompactChanged;
  final bool keepExpanded;
  @override
  State<PikoCollapsingHeader> createState() => _HeaderState();
}

class _HeaderState extends State<PikoCollapsingHeader> {
  bool compact = false;
  void changed(bool value) {
    if (!mounted || value == compact) return;
    // Transfer the active focus before excluding the old representation.
    widget.onCompactChanged(value);
    setState(() => compact = value);
  }

  @override
  Widget build(BuildContext context) => _HeaderSliver(
    keepExpanded: widget.keepExpanded,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
    onCompactChanged: changed,
    children: [
      ExcludeFocus(excluding: compact, child: widget.expanded),
      ExcludeFocus(excluding: !compact, child: widget.compact),
    ],
  );
}

class _HeaderSliver extends MultiChildRenderObjectWidget {
  const _HeaderSliver({
    required super.children,
    required this.keepExpanded,
    required this.reduceMotion,
    required this.onCompactChanged,
  });
  final bool keepExpanded;
  final bool reduceMotion;
  final ValueChanged<bool> onCompactChanged;
  @override
  MultiChildRenderObjectElement createElement() => _HeaderElement(this);
  @override
  _RenderHeader createRenderObject(BuildContext context) => _RenderHeader(
    keepExpanded,
    reduceMotion: reduceMotion,
    onCompactChanged: onCompactChanged,
  );
  @override
  void updateRenderObject(BuildContext context, _RenderHeader renderObject) {
    renderObject
      ..keepExpanded = keepExpanded
      ..reduceMotion = reduceMotion
      ..onCompactChanged = onCompactChanged;
  }
}

class _HeaderElement extends MultiChildRenderObjectElement {
  _HeaderElement(super.widget);
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final header = renderObject as _RenderHeader;
    final visible = children.elementAt(header._compact ? 1 : 0);
    visitor(visible);
  }
}

class _HeaderParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderHeader extends RenderSliver
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderParentData>,
        RenderSliverHelpers {
  _RenderHeader(
    this._keepExpanded, {
    required bool reduceMotion,
    required this.onCompactChanged,
    // Keep the internal flag private while the construction API is named.
    // ignore: prefer_initializing_formals
  }) : _reduceMotion = reduceMotion;
  bool _keepExpanded, _compact = false, _notificationScheduled = false;
  bool _reduceMotion;
  double _expandedOffset = 0;
  double _progress = 0, _expandedScale = 1;
  double? _cycleMaximum, _layoutWidth;
  ValueChanged<bool> onCompactChanged;
  set keepExpanded(bool value) {
    if (_keepExpanded == value) return;
    _keepExpanded = value;
    markNeedsLayout();
  }

  set reduceMotion(bool value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    markNeedsLayout();
  }

  RenderBox get active => _compact ? lastChild! : firstChild!;
  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _HeaderParentData) {
      child.parentData = _HeaderParentData();
    }
  }

  @override
  void performLayout() {
    assert(constraints.axis == Axis.vertical);
    final boxes = constraints.asBoxConstraints();
    firstChild!.layout(boxes, parentUsesSize: true);
    lastChild!.layout(boxes, parentUsesSize: true);
    if (constraints.scrollOffset <= 0 ||
        _layoutWidth != constraints.crossAxisExtent) {
      _cycleMaximum = null;
      _layoutWidth = constraints.crossAxisExtent;
    }
    // Passive count/loading refreshes cannot move the collapse threshold under
    // a scrolled list. Re-measure a new cycle at the top or a width change.
    final maximum = math.max(
      _cycleMaximum ?? firstChild!.size.height,
      lastChild!.size.height,
    );
    // A keyboard or unusually tall title must never leave no reachable list.
    // In that constrained viewport, the complete expanded header scrolls in
    // normal flow until enough height is available to pin it again.
    final canPin =
        lastChild!.size.height + pikoDesign.dimension('controls.largeHeight') <=
        constraints.viewportMainAxisExtent;
    final minimum = canPin
        ? (_keepExpanded ? maximum : lastChild!.size.height)
        : 0.0;
    final extent = math.max(minimum, maximum - constraints.scrollOffset);
    _expandedOffset = _keepExpanded && canPin ? 0 : -constraints.scrollOffset;
    final completelyCompact =
        canPin &&
        !_keepExpanded &&
        constraints.scrollOffset > 0 &&
        extent <= minimum;
    _progress = canPin && !_keepExpanded && maximum > minimum
        ? (constraints.scrollOffset / (maximum - minimum)).clamp(0.0, 1.0)
        : 0;
    if (_progress > 0) _cycleMaximum ??= maximum;
    _expandedScale = _reduceMotion || !canPin || _keepExpanded
        ? 1
        : extent / maximum;
    final next = _reduceMotion ? completelyCompact : _progress >= .5;
    if (next != _compact) {
      _compact = next;
      markNeedsSemanticsUpdate();
      if (!_notificationScheduled) {
        _notificationScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notificationScheduled = false;
          if (attached) onCompactChanged(_compact);
        });
      }
    }
    final paintExtent = math.min(extent, constraints.remainingPaintExtent);
    geometry = SliverGeometry(
      scrollExtent: maximum,
      paintOrigin: constraints.overlap,
      paintExtent: paintExtent,
      layoutExtent: (maximum - constraints.scrollOffset).clamp(
        0.0,
        paintExtent,
      ),
      maxPaintExtent: maximum,
      maxScrollObstructionExtent: minimum,
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: maximum),
      hasVisualOverflow: true,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!geometry!.visible) return;
    context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTWH(0, 0, constraints.crossAxisExtent, geometry!.paintExtent),
      (context, offset) {
        if (_reduceMotion || _progress == 0 || _progress == 1) {
          _paintChild(context, offset, active, 1);
        } else {
          _paintChild(context, offset, firstChild!, 1 - _progress);
          _paintChild(context, offset, lastChild!, _progress);
        }
      },
    );
  }

  Matrix4 _childTransform(RenderObject child) {
    if (identical(child, firstChild)) {
      if (_reduceMotion || _progress == 0) {
        return Matrix4.translationValues(0, _expandedOffset, 0);
      }
      return Matrix4.identity()
        ..translateByDouble(
          constraints.crossAxisExtent * (1 - _expandedScale) / 2,
          0,
          0,
          1,
        )
        ..scaleByDouble(_expandedScale, _expandedScale, 1, 1);
    }
    return Matrix4.identity();
  }

  void _paintChild(
    PaintingContext context,
    Offset offset,
    RenderBox child,
    double opacity,
  ) {
    context.pushOpacity(offset, (255 * opacity).round(), (context, offset) {
      context.pushTransform(
        needsCompositing,
        offset,
        _childTransform(child),
        (context, offset) => context.paintChild(child, offset),
      );
    });
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) => BoxHitTestResult.wrap(result).addWithPaintTransform(
    transform: _childTransform(active),
    position: Offset(crossAxisPosition, mainAxisPosition),
    hitTest: (result, position) => active.hitTest(result, position: position),
  );
  @override
  double childMainAxisPosition(RenderObject child) =>
      identical(child, firstChild) && (_reduceMotion || _progress == 0)
      ? _expandedOffset
      : 0;
  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.multiply(_childTransform(child));
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      visitor(active);
  @override
  Rect? describeSemanticsClip(RenderObject? child) => Rect.fromLTWH(
    0,
    0,
    constraints.crossAxisExtent,
    geometry?.paintExtent ?? 0,
  );
}
