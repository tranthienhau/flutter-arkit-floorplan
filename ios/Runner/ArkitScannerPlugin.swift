import ARKit
import Flutter
import Foundation

/// Native LiDAR scanner that drives ARKit scene reconstruction and returns
/// the reconstructed mesh (vertices, faces, per-face classification) to
/// Flutter over a MethodChannel.
///
/// Flow:
///   - `isSupported` -> true only on LiDAR devices that support scene mesh.
///   - `captureMesh` -> starts an ARSession with sceneReconstruction = .mesh
///     and .sceneDepth, collects ARMeshAnchors for `captureSeconds`, then
///     flattens every anchor's geometry into world space and replies once.
///
/// The Dart side (FloorPlanGenerator) turns this raw mesh into a clean 2D
/// plan, so all the heavy geometry math stays cross-platform and testable.
final class ArkitScannerPlugin: NSObject, ARSessionDelegate {
  private let channel: FlutterMethodChannel
  private let session = ARSession()
  private var pending: FlutterResult?
  private let captureSeconds: TimeInterval = 8

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.tranthienhau/arkit_floorplan",
      binaryMessenger: messenger)
    super.init()
    session.delegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh))
    case "captureMesh":
      startCapture(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startCapture(_ result: @escaping FlutterResult) {
    guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
      result(FlutterError(code: "unsupported",
                          message: "LiDAR scene mesh not available", details: nil))
      return
    }
    pending = result
    let config = ARWorldTrackingConfiguration()
    config.sceneReconstruction = .mesh
    config.frameSemantics = .sceneDepth
    session.run(config, options: [.resetTracking, .removeExistingAnchors])

    DispatchQueue.main.asyncAfter(deadline: .now() + captureSeconds) { [weak self] in
      self?.finish()
    }
  }

  private func finish() {
    guard let result = pending else { return }
    pending = nil

    var vertices: [Float] = []
    var faces: [Int32] = []
    var classes: [Int32] = []
    var indexBase: Int32 = 0

    for anchor in session.currentFrame?.anchors ?? [] {
      guard let mesh = anchor as? ARMeshAnchor else { continue }
      let geometry = mesh.geometry
      let transform = mesh.transform

      // Vertices -> world space.
      let verts = geometry.vertices
      for i in 0..<verts.count {
        let local = verts.value(at: i)
        let world = transform * SIMD4<Float>(local.0, local.1, local.2, 1)
        vertices.append(world.x)
        vertices.append(world.y)
        vertices.append(world.z)
      }

      // Faces (triangles) + classification per face.
      let faceCount = geometry.faces.count
      for f in 0..<faceCount {
        let idx = geometry.faces.indices(at: f)
        faces.append(indexBase + Int32(idx[0]))
        faces.append(indexBase + Int32(idx[1]))
        faces.append(indexBase + Int32(idx[2]))
        classes.append(classification(of: geometry, face: f))
      }
      indexBase += Int32(verts.count)
    }

    session.pause()
    result([
      "vertices": vertices,
      "faces": faces,
      "classes": classes,
    ])
  }

  private func classification(of geometry: ARMeshGeometry, face: Int) -> Int32 {
    guard let source = geometry.classification else { return 0 }
    let pointer = source.buffer.contents()
      .advanced(by: source.offset + source.stride * face)
    return Int32(pointer.assumingMemoryBound(to: UInt8.self).pointee)
  }
}

// MARK: - ARMeshGeometry accessors

private extension ARGeometrySource {
  /// Reads a packed Float3 vertex at `index` from the geometry buffer.
  func value(at index: Int) -> (Float, Float, Float) {
    let pointer = buffer.contents().advanced(by: offset + stride * index)
    let floats = pointer.assumingMemoryBound(to: Float.self)
    return (floats[0], floats[1], floats[2])
  }
}

private extension ARGeometryElement {
  /// Reads the three vertex indices of triangle `face`.
  func indices(at face: Int) -> [Int] {
    let perFace = indexCountPerPrimitive // 3 for triangles
    let pointer = buffer.contents()
      .advanced(by: face * perFace * bytesPerIndex)
    if bytesPerIndex == MemoryLayout<UInt16>.size {
      let p = pointer.assumingMemoryBound(to: UInt16.self)
      return (0..<perFace).map { Int(p[$0]) }
    } else {
      let p = pointer.assumingMemoryBound(to: UInt32.self)
      return (0..<perFace).map { Int(p[$0]) }
    }
  }
}
