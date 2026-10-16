import 'package:flutter/widgets.dart';

/// Direct drags retain Android's native response. Limit only the release
/// velocity so a quick flick does not skip several screens of vocabulary.
class CollectionScrollPhysics extends ClampingScrollPhysics {
  const CollectionScrollPhysics({super.parent});

  @override
  CollectionScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      CollectionScrollPhysics(parent: buildParent(ancestor));

  @override
  double get maxFlingVelocity => 3000;
}
