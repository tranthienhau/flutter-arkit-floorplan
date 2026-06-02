import 'dart:math' as math;

/// A 3D point in ARKit world space (meters). ARKit uses a right-handed
/// coordinate system: +x right, +y up, -z forward.
class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final l = length;
    if (l < 1e-9) return const Vec3(0, 0, 0);
    return Vec3(x / l, y / l, z / l);
  }
}

/// A single triangle, referenced by vertex indices into [Mesh.vertices].
class Face {
  final int a;
  final int b;
  final int c;

  /// ARKit ARMeshClassification (0 none, 1 wall, 2 floor, 3 ceiling,
  /// 4 table, 5 seat, 6 window, 7 door). May be 0 when LiDAR has no
  /// semantic guess; the generator then falls back to geometry.
  final int classification;

  const Face(this.a, this.b, this.c, {this.classification = 0});
}

/// Raw LiDAR mesh captured from ARKit (ARMeshAnchor) or RoomPlan.
class Mesh {
  final List<Vec3> vertices;
  final List<Face> faces;

  const Mesh({required this.vertices, required this.faces});

  /// Geometric normal of a face (not normalized to unit by the caller).
  Vec3 faceNormal(Face f) {
    final p0 = vertices[f.a];
    final p1 = vertices[f.b];
    final p2 = vertices[f.c];
    return (p1 - p0).cross(p2 - p0).normalized();
  }

  Vec3 faceCenter(Face f) {
    final p0 = vertices[f.a];
    final p1 = vertices[f.b];
    final p2 = vertices[f.c];
    return (p0 + p1 + p2) * (1.0 / 3.0);
  }

  /// Area of a triangle, used to weight large surfaces over mesh noise.
  double faceArea(Face f) {
    final p0 = vertices[f.a];
    final p1 = vertices[f.b];
    final p2 = vertices[f.c];
    return (p1 - p0).cross(p2 - p0).length * 0.5;
  }

  int get triangleCount => faces.length;
  int get vertexCount => vertices.length;
}
