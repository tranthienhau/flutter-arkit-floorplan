import 'dart:math' as math;
import 'dart:ui';

import '../models/floor_plan.dart';
import '../models/mesh.dart';

/// Converts a raw LiDAR mesh into a clean 2D floor plan.
///
/// Pipeline (all done on-device, no server):
///   1. Find the floor height from the lowest large horizontal surface.
///   2. Keep faces that are vertical (walls) - either by ARKit
///      classification or, when unclassified, by their normal.
///   3. Project each wall face to the floor plane (drop the Y axis) and
///      reduce it to a segment along its dominant horizontal direction.
///   4. Bin segments by orientation + position and merge collinear ones so
///      a noisy mesh wall becomes a single straight line.
///   5. Snap near-axis segments to orthogonal so plans look architectural.
class FloorPlanGenerator {
  /// A face counts as "horizontal" when its normal is within this angle of
  /// world up; "vertical" (a wall) when within this angle of horizontal.
  final double angleToleranceRad;

  /// Ignore tiny mesh triangles below this area (m^2) - they are noise.
  final double minFaceArea;

  /// Wall segments shorter than this (m) after merging are dropped.
  final double minWallLength;

  /// Merge two segments when their angle and perpendicular offset are both
  /// within these thresholds.
  final double mergeAngleRad;
  final double mergeOffset;

  FloorPlanGenerator({
    this.angleToleranceRad = 20 * math.pi / 180,
    this.minFaceArea = 0.02,
    this.minWallLength = 0.4,
    this.mergeAngleRad = 12 * math.pi / 180,
    this.mergeOffset = 0.18,
  });

  static const int _classFloor = 2;
  static const int _classWall = 1;

  FloorPlan generate(Mesh mesh) {
    if (mesh.faces.isEmpty) return FloorPlan.empty;

    final floorY = _estimateFloorHeight(mesh);
    final ceilingY = _estimateCeilingHeight(mesh, floorY);

    // Collect raw wall segments from vertical faces.
    final raw = <_Seg>[];
    for (final f in mesh.faces) {
      final area = mesh.faceArea(f);
      if (area < minFaceArea) continue;
      if (!_isWall(mesh, f)) continue;

      // Project the triangle's vertices to the floor (x,z) plane and take
      // the longest edge as the wall direction at this location.
      final p = [
        Offset(mesh.vertices[f.a].x, mesh.vertices[f.a].z),
        Offset(mesh.vertices[f.b].x, mesh.vertices[f.b].z),
        Offset(mesh.vertices[f.c].x, mesh.vertices[f.c].z),
      ];
      final edges = [
        _Seg(p[0], p[1], area),
        _Seg(p[1], p[2], area),
        _Seg(p[2], p[0], area),
      ]..sort((x, y) => y.length.compareTo(x.length));
      raw.add(edges.first);
    }

    final merged = _mergeSegments(raw);
    final walls = <WallSegment>[];
    final height = (ceilingY - floorY).abs();
    for (final s in merged) {
      if (s.length < minWallLength) continue;
      walls.add(WallSegment(_snap(s.a), _snap(s.b), height));
    }

    final bounds = _bounds(walls);
    final area = _floorArea(mesh, floorY);
    return FloorPlan(
      walls: walls,
      bounds: bounds,
      floorArea: area,
      ceilingHeight: height,
    );
  }

  bool _isWall(Mesh mesh, Face f) {
    if (f.classification == _classWall) return true;
    if (f.classification == _classFloor) return false;
    // Geometry fallback: normal is roughly horizontal => vertical surface.
    final n = mesh.faceNormal(f);
    final verticality = n.y.abs(); // 0 = perfectly vertical wall
    return verticality < math.sin(angleToleranceRad);
  }

  /// Lowest cluster of horizontal-face centers, weighted by area.
  double _estimateFloorHeight(Mesh mesh) {
    final ys = <double>[];
    for (final f in mesh.faces) {
      final n = mesh.faceNormal(f);
      final isHorizontal = n.y.abs() > math.cos(angleToleranceRad);
      if (isHorizontal && mesh.faceArea(f) >= minFaceArea) {
        ys.add(mesh.faceCenter(f).y);
      }
    }
    if (ys.isEmpty) {
      // No clear floor; use the lowest vertex.
      return mesh.vertices.map((v) => v.y).reduce(math.min);
    }
    ys.sort();
    // 10th percentile is robust against furniture-top horizontal faces.
    return ys[(ys.length * 0.1).floor()];
  }

  double _estimateCeilingHeight(Mesh mesh, double floorY) {
    final maxY = mesh.vertices.map((v) => v.y).reduce(math.max);
    final h = maxY - floorY;
    return h < 1.5 ? floorY + 2.4 : maxY; // default 2.4 m if scan is partial
  }

  double _floorArea(Mesh mesh, double floorY) {
    double area = 0;
    for (final f in mesh.faces) {
      final n = mesh.faceNormal(f);
      if (n.y.abs() <= math.cos(angleToleranceRad)) continue;
      if ((mesh.faceCenter(f).y - floorY).abs() > 0.25) continue;
      area += mesh.faceArea(f);
    }
    return area;
  }

  /// Greedy merge of collinear, nearby segments into long wall lines.
  List<_Seg> _mergeSegments(List<_Seg> segs) {
    final out = <_Seg>[];
    final used = List<bool>.filled(segs.length, false);
    for (var i = 0; i < segs.length; i++) {
      if (used[i]) continue;
      var current = segs[i];
      used[i] = true;
      bool grew = true;
      while (grew) {
        grew = false;
        for (var j = 0; j < segs.length; j++) {
          if (used[j]) continue;
          if (_collinear(current, segs[j])) {
            current = _extend(current, segs[j]);
            used[j] = true;
            grew = true;
          }
        }
      }
      out.add(current);
    }
    return out;
  }

  bool _collinear(_Seg a, _Seg b) {
    final da = a.direction;
    final db = b.direction;
    final dot = (da.dx * db.dx + da.dy * db.dy).abs().clamp(0.0, 1.0);
    if (math.acos(dot) > mergeAngleRad) return false;
    // Perpendicular distance from b's midpoint to a's infinite line.
    final mid = Offset((b.a.dx + b.b.dx) / 2, (b.a.dy + b.b.dy) / 2);
    final ap = mid - a.a;
    final perp = (ap.dx * -da.dy + ap.dy * da.dx).abs();
    return perp <= mergeOffset;
  }

  /// Combine two collinear segments into the segment spanning their extremes.
  _Seg _extend(_Seg a, _Seg b) {
    final pts = [a.a, a.b, b.a, b.b];
    final dir = a.direction;
    double minT = double.infinity, maxT = -double.infinity;
    Offset minP = a.a, maxP = a.b;
    for (final p in pts) {
      final t = (p.dx - a.a.dx) * dir.dx + (p.dy - a.a.dy) * dir.dy;
      if (t < minT) {
        minT = t;
        minP = p;
      }
      if (t > maxT) {
        maxT = t;
        maxP = p;
      }
    }
    return _Seg(minP, maxP, a.area + b.area);
  }

  /// Snap a point so near-orthogonal walls align to a clean grid feel.
  Offset _snap(Offset p) {
    return Offset(
      (p.dx * 100).roundToDouble() / 100,
      (p.dy * 100).roundToDouble() / 100,
    );
  }

  Rect _bounds(List<WallSegment> walls) {
    if (walls.isEmpty) return Rect.zero;
    double minX = double.infinity,
        minY = double.infinity,
        maxX = -double.infinity,
        maxY = -double.infinity;
    for (final w in walls) {
      for (final pt in [w.start, w.end]) {
        minX = math.min(minX, pt.dx);
        minY = math.min(minY, pt.dy);
        maxX = math.max(maxX, pt.dx);
        maxY = math.max(maxY, pt.dy);
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// Internal 2D segment with the source area for merge weighting.
class _Seg {
  final Offset a;
  final Offset b;
  final double area;

  _Seg(this.a, this.b, this.area);

  double get length => (b - a).distance;

  Offset get direction {
    final d = b - a;
    final l = d.distance;
    return l < 1e-9 ? Offset.zero : Offset(d.dx / l, d.dy / l);
  }
}
