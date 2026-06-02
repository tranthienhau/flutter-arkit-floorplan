import 'dart:ui';

/// A wall projected to the floor plane as a 2D segment (meters, top-down).
class WallSegment {
  final Offset start;
  final Offset end;
  final double height;

  const WallSegment(this.start, this.end, this.height);

  double get length => (end - start).distance;
}

/// Final 2D floor plan: wall segments plus the bounding extent so the UI
/// can fit-to-view. Coordinates are in meters in the floor (x,z) plane.
class FloorPlan {
  final List<WallSegment> walls;
  final Rect bounds;
  final double floorArea;
  final double ceilingHeight;

  const FloorPlan({
    required this.walls,
    required this.bounds,
    required this.floorArea,
    required this.ceilingHeight,
  });

  static const empty = FloorPlan(
    walls: [],
    bounds: Rect.zero,
    floorArea: 0,
    ceilingHeight: 0,
  );

  bool get isEmpty => walls.isEmpty;
}
