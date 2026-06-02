import 'dart:math' as math;

import '../models/mesh.dart';

/// Synthesises a LiDAR-like mesh of a small L-shaped room so the pipeline
/// runs end-to-end on the simulator, Android, or desktop with no device.
///
/// Walls are emitted as many small, slightly jittered quads (split into
/// triangles) to mimic raw ARKit reconstruction - the generator must merge
/// them back into clean lines. Some faces carry no classification (0) to
/// exercise the geometry fallback.
class SampleMesh {
  static Mesh build() {
    final rnd = math.Random(7);
    final vertices = <Vec3>[];
    final faces = <Face>[];

    int addVertex(double x, double y, double z) {
      // Small jitter to imitate LiDAR noise.
      vertices.add(Vec3(
        x + (rnd.nextDouble() - 0.5) * 0.01,
        y + (rnd.nextDouble() - 0.5) * 0.01,
        z + (rnd.nextDouble() - 0.5) * 0.01,
      ));
      return vertices.length - 1;
    }

    const wallHeight = 2.5;
    const segLen = 0.25; // raw mesh resolution per wall strip

    void addWall(double x0, double z0, double x1, double z1, int cls) {
      final dx = x1 - x0;
      final dz = z1 - z0;
      final dist = math.sqrt(dx * dx + dz * dz);
      final steps = math.max(1, (dist / segLen).round());
      for (var i = 0; i < steps; i++) {
        final t0 = i / steps;
        final t1 = (i + 1) / steps;
        final ax = x0 + dx * t0, az = z0 + dz * t0;
        final bx = x0 + dx * t1, bz = z0 + dz * t1;
        final v0 = addVertex(ax, 0, az);
        final v1 = addVertex(bx, 0, bz);
        final v2 = addVertex(bx, wallHeight, bz);
        final v3 = addVertex(ax, wallHeight, az);
        faces.add(Face(v0, v1, v2, classification: cls));
        faces.add(Face(v0, v2, v3, classification: cls));
      }
    }

    void addFloorTile(double x0, double z0, double x1, double z1) {
      final v0 = addVertex(x0, 0, z0);
      final v1 = addVertex(x1, 0, z0);
      final v2 = addVertex(x1, 0, z1);
      final v3 = addVertex(x0, 0, z1);
      faces.add(Face(v0, v1, v2, classification: 2)); // floor
      faces.add(Face(v0, v2, v3, classification: 2));
    }

    // L-shaped room outline (meters). Some walls classified, some not (0).
    addWall(0, 0, 4, 0, 1); // classified wall
    addWall(4, 0, 4, 3, 0); // unclassified -> geometry fallback
    addWall(4, 3, 2, 3, 1);
    addWall(2, 3, 2, 5, 0);
    addWall(2, 5, 0, 5, 1);
    addWall(0, 5, 0, 0, 0);

    // Floor tiles across the footprint.
    for (double x = 0; x < 4; x += 0.5) {
      for (double z = 0; z < 5; z += 0.5) {
        if (x >= 2 || z < 3) addFloorTile(x, z, x + 0.5, z + 0.5);
      }
    }

    // A piece of furniture: a horizontal table-top at 0.75 m that must NOT
    // be mistaken for the floor, plus its short vertical sides.
    addFloorTile(1, 1, 2, 2); // will sit at y=0; raise it:
    final base = vertices.length - 8;
    for (var i = base; i < vertices.length; i++) {
      vertices[i] = Vec3(vertices[i].x, 0.75, vertices[i].z);
    }

    return Mesh(vertices: vertices, faces: faces);
  }
}
