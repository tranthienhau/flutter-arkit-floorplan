import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/scan_providers.dart';
import 'floor_plan_painter.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final supported = ref.watch(scannerSupportedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARKit LiDAR -> Floor Plan'),
        backgroundColor: const Color(0xFF1B2A4A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: state.plan.isEmpty
                ? _Empty(status: state.status, error: state.error)
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: CustomPaint(
                      painter: FloorPlanPainter(state.plan),
                      size: Size.infinite,
                    ),
                  ),
          ),
          if (state.plan.walls.isNotEmpty) _Stats(),
          _Controls(supported: supported.valueOrNull ?? false),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final ScanStatus status;
  final String? error;
  const _Empty({required this.status, this.error});

  @override
  Widget build(BuildContext context) {
    final msg = switch (status) {
      ScanStatus.scanning => 'Reconstructing mesh...',
      ScanStatus.error => 'Error: $error',
      _ => 'Scan a room with LiDAR, or load the sample mesh.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(msg, textAlign: TextAlign.center),
      ),
    );
  }
}

class _Stats extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(scanControllerProvider);
    final plan = s.plan;
    return Container(
      width: double.infinity,
      color: const Color(0xFFF1F4FA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 24,
        children: [
          _stat('Walls', '${plan.walls.length}'),
          _stat('Floor area', '${plan.floorArea.toStringAsFixed(1)} m^2'),
          _stat('Ceiling', '${plan.ceilingHeight.toStringAsFixed(2)} m'),
          _stat('Mesh tris', '${s.mesh?.triangleCount ?? 0}'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      );
}

class _Controls extends ConsumerWidget {
  final bool supported;
  const _Controls({required this.supported});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(scanControllerProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: supported ? ctrl.scan : null,
                icon: const Icon(Icons.view_in_ar),
                label: Text(supported ? 'Scan room' : 'No LiDAR'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: ctrl.loadSample,
                icon: const Icon(Icons.grid_on),
                label: const Text('Sample mesh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
