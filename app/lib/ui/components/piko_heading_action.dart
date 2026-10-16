import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Gives a heading its full width before moving its action to a second row.
/// Text scaling is preserved; neither the heading nor action is truncated.
class PikoHeadingAction extends MultiChildRenderObjectWidget {
  PikoHeadingAction({
    super.key,
    required Widget heading,
    required Widget action,
    required this.gap,
  }) : super(children: [heading, action]);

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _HeadingActionLayout(gap, Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBox renderObject,
  ) {
    (renderObject as _HeadingActionLayout).configure(
      gap,
      Directionality.of(context),
    );
  }
}

class _HeadingActionParentData extends ContainerBoxParentData<RenderBox> {}

class _HeadingActionLayout extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _HeadingActionLayout(this.gap, this.direction);
  double gap;
  TextDirection direction;

  void configure(double nextGap, TextDirection nextDirection) {
    if (gap == nextGap && direction == nextDirection) return;
    gap = nextGap;
    direction = nextDirection;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _HeadingActionParentData();
    }
  }

  Size _size(BoxConstraints constraints, Size heading, Size action) {
    final spacing = action.isEmpty ? 0.0 : gap;
    final rowWidth = heading.width + action.width + spacing;
    final stacked = rowWidth > constraints.maxWidth;
    return constraints.constrain(
      Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : rowWidth,
        stacked
            ? heading.height + spacing + action.height
            : (heading.height > action.height ? heading.height : action.height),
      ),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _size(
    constraints,
    firstChild!.getDryLayout(constraints.loosen()),
    lastChild!.getDryLayout(constraints.loosen()),
  );

  @override
  void performLayout() {
    final heading = firstChild!, action = lastChild!;
    heading.layout(constraints.loosen(), parentUsesSize: true);
    action.layout(constraints.loosen(), parentUsesSize: true);
    size = _size(constraints, heading.size, action.size);
    final spacing = action.size.isEmpty ? 0.0 : gap;
    final stacked =
        heading.size.width + action.size.width + spacing > size.width;
    final rtl = direction == TextDirection.rtl;
    (heading.parentData! as ContainerBoxParentData<RenderBox>).offset = Offset(
      rtl ? size.width - heading.size.width : 0,
      stacked ? 0 : (size.height - heading.size.height) / 2,
    );
    (action.parentData! as ContainerBoxParentData<RenderBox>).offset = Offset(
      rtl ? 0 : size.width - action.size.width,
      stacked
          ? heading.size.height + spacing
          : (size.height - action.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
