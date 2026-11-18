import 'package:flutter/widgets.dart';

/// Page-snapping physics whose drag distance and fling threshold scale with
/// [sensitivity] (0.5 = harder to flip, 2.0 = flips on a short drag).
class ReaderSwipePhysics extends PageScrollPhysics {
  const ReaderSwipePhysics({this.sensitivity = 1.0, super.parent});

  final double sensitivity;

  @override
  ReaderSwipePhysics applyTo(ScrollPhysics? ancestor) => ReaderSwipePhysics(
    sensitivity: sensitivity,
    parent: buildParent(ancestor),
  );

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset) * sensitivity;

  @override
  Tolerance toleranceFor(ScrollMetrics metrics) {
    final base = super.toleranceFor(metrics);
    return Tolerance(
      distance: base.distance,
      time: base.time,
      velocity: base.velocity / sensitivity,
    );
  }
}

/// The physics for [sensitivity], or `null` (framework default) at 1.0.
ScrollPhysics? readerSwipePhysics(double sensitivity) =>
    (sensitivity - 1.0).abs() < 0.01
    ? null
    : ReaderSwipePhysics(sensitivity: sensitivity);
