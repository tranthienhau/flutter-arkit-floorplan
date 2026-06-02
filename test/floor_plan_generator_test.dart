import 'package:flutter_arkit_floorplan/src/data/sample_mesh.dart';
import 'package:flutter_arkit_floorplan/src/models/floor_plan.dart';
import 'package:flutter_arkit_floorplan/src/models/mesh.dart';
import 'package:flutter_arkit_floorplan/src/services/floor_plan_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generator = FloorPlanGenerator();

  test('empty mesh yields empty plan', () {
    final plan = generator.generate(const Mesh(vertices: [], faces: []));
    expect(plan.isEmpty, isTrue);
  });

  group('sample L-shaped room', () {
    late FloorPlan plan;

    setUp(() => plan = generator.generate(SampleMesh.build()));

    test('produces wall segments', () {
      expect(plan.walls, isNotEmpty);
    });

    test('merges noisy strips into a handful of long walls', () {
      // The synthetic room has 6 wall runs split into ~0.25 m strips;
      // merging must collapse the hundreds of triangles back to few lines.
      expect(plan.walls.length, lessThan(30));
    });

    test('recovers a plausible ceiling height (~2.5 m)', () {
      expect(plan.ceilingHeight, greaterThan(2.0));
      expect(plan.ceilingHeight, lessThan(3.0));
    });

    test('reports a positive floor area', () {
      expect(plan.floorArea, greaterThan(0));
    });

    test('does not treat the 0.75 m table top as the floor', () {
      // If the table were taken as floor, ceiling height would collapse.
      expect(plan.ceilingHeight, greaterThan(1.5));
    });
  });

  test('two collinear noisy strips merge into one longer wall', () {
    // Two short vertical wall quads along x, slightly offset in y noise.
    final v = <Vec3>[
      const Vec3(0, 0, 0),
      const Vec3(1, 0, 0),
      const Vec3(1, 2.5, 0),
      const Vec3(0, 2.5, 0),
      const Vec3(1, 0, 0),
      const Vec3(2, 0, 0),
      const Vec3(2, 2.5, 0),
      const Vec3(1, 2.5, 0),
    ];
    final faces = [
      const Face(0, 1, 2, classification: 1),
      const Face(0, 2, 3, classification: 1),
      const Face(4, 5, 6, classification: 1),
      const Face(4, 6, 7, classification: 1),
    ];
    final plan = generator.generate(Mesh(vertices: v, faces: faces));
    expect(plan.walls.length, 1);
    expect(plan.walls.first.length, closeTo(2.0, 0.05));
  });
}
