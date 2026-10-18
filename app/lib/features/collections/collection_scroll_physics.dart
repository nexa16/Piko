import 'package:flutter/widgets.dart';

/// Direct drags retain Android's native response. Selection-footer contraction
/// can keep a settled viewport offset until the user's next scrolling intent;
/// this does not add content or retain an invisible footer.
class CollectionScrollPhysics extends ClampingScrollPhysics {
  const CollectionScrollPhysics({
    super.parent,
    this.retainSelectionOffset,
    this.onUserScroll,
  });
  final bool Function()? retainSelectionOffset;
  final VoidCallback? onUserScroll;
  @override
  CollectionScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      CollectionScrollPhysics(
        parent: buildParent(ancestor),
        retainSelectionOffset: retainSelectionOffset,
        onUserScroll: onUserScroll,
      );
  @override
  double get maxFlingVelocity => 3000;
  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (retainSelectionOffset?.call() == true &&
        !isScrolling &&
        oldPosition.pixels > newPosition.maxScrollExtent &&
        newPosition.maxScrollExtent < oldPosition.maxScrollExtent) {
      return oldPosition.pixels;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (retainSelectionOffset?.call() == true &&
        velocity == 0 &&
        position.outOfRange) {
      return null;
    }
    if (velocity != 0) onUserScroll?.call();
    return super.createBallisticSimulation(position, velocity);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    onUserScroll?.call();
    return super.applyPhysicsToUserOffset(position, offset);
  }
}
