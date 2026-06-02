import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_mesh.dart';
import '../models/floor_plan.dart';
import '../models/mesh.dart';
import '../services/arkit_scanner_service.dart';
import '../services/floor_plan_generator.dart';

final scannerServiceProvider = Provider((_) => ArkitScannerService());

final generatorProvider = Provider((_) => FloorPlanGenerator());

/// Whether a real LiDAR scanner is available; false drives demo mode.
final scannerSupportedProvider = FutureProvider<bool>((ref) {
  return ref.watch(scannerServiceProvider).isSupported();
});

enum ScanStatus { idle, scanning, done, error }

class ScanState {
  final ScanStatus status;
  final Mesh? mesh;
  final FloorPlan plan;
  final String? error;

  const ScanState({
    this.status = ScanStatus.idle,
    this.mesh,
    this.plan = FloorPlan.empty,
    this.error,
  });

  ScanState copyWith({
    ScanStatus? status,
    Mesh? mesh,
    FloorPlan? plan,
    String? error,
  }) {
    return ScanState(
      status: status ?? this.status,
      mesh: mesh ?? this.mesh,
      plan: plan ?? this.plan,
      error: error,
    );
  }
}

class ScanController extends StateNotifier<ScanState> {
  ScanController(this._ref) : super(const ScanState());

  final Ref _ref;

  /// Captures from the native ARKit scanner and generates the plan.
  Future<void> scan() async {
    state = state.copyWith(status: ScanStatus.scanning, error: null);
    try {
      final mesh = await _ref.read(scannerServiceProvider).captureMesh();
      _build(mesh);
    } catch (e) {
      state = state.copyWith(status: ScanStatus.error, error: '$e');
    }
  }

  /// Runs the same pipeline on the bundled synthetic mesh (no device).
  void loadSample() {
    state = state.copyWith(status: ScanStatus.scanning, error: null);
    _build(SampleMesh.build());
  }

  void _build(Mesh mesh) {
    final plan = _ref.read(generatorProvider).generate(mesh);
    state = state.copyWith(status: ScanStatus.done, mesh: mesh, plan: plan);
  }
}

final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>((ref) {
  return ScanController(ref);
});
