import 'package:flutter/services.dart';

import '../models/mesh.dart';

/// Bridges to the native iOS ARKit/RoomPlan scanner over a MethodChannel.
///
/// The Swift side (ios/Runner/ArkitScannerPlugin.swift) runs an
/// ARWorldTrackingConfiguration with sceneReconstruction = .mesh on
/// LiDAR devices, gathers ARMeshAnchor geometry + classifications, and
/// returns a flat payload:
///   { "vertices": [x,y,z, x,y,z, ...],
///     "faces":    [a,b,c, a,b,c, ...],
///     "classes":  [c, c, ...] }   // one class per face
///
/// On Android or the simulator the channel is absent, so callers fall
/// back to [SampleMesh] for a runnable demo.
class ArkitScannerService {
  static const _channel = MethodChannel('com.tranthienhau/arkit_floorplan');

  /// True when a LiDAR-capable scanner is available on this device.
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Starts a live capture and resolves with the reconstructed mesh once
  /// the user finishes scanning on the native side.
  Future<Mesh> captureMesh() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('captureMesh');
    if (raw == null) {
      throw StateError('Native scanner returned no mesh');
    }
    return _decode(raw);
  }

  Mesh _decode(Map<String, dynamic> raw) {
    final v = (raw['vertices'] as List).cast<num>();
    final f = (raw['faces'] as List).cast<num>();
    final classes = (raw['classes'] as List?)?.cast<num>();

    final vertices = <Vec3>[];
    for (var i = 0; i + 2 < v.length; i += 3) {
      vertices.add(Vec3(v[i].toDouble(), v[i + 1].toDouble(), v[i + 2].toDouble()));
    }

    final faces = <Face>[];
    for (var i = 0, fi = 0; i + 2 < f.length; i += 3, fi++) {
      faces.add(Face(
        f[i].toInt(),
        f[i + 1].toInt(),
        f[i + 2].toInt(),
        classification: classes != null && fi < classes.length
            ? classes[fi].toInt()
            : 0,
      ));
    }
    return Mesh(vertices: vertices, faces: faces);
  }
}
