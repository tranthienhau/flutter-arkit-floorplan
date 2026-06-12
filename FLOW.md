# Screenshot capture flow

Real captures from the iOS Simulator via an integration-test driver (no mockups).

## Steps

1. Boot the simulator:
   ```bash
   xcrun simctl boot "iPhone 17 Pro"
   open -a Simulator
   ```
2. Scaffold the iOS platform folder (only needed if `ios/` is missing) and get
   dependencies:
   ```bash
   flutter create . --platforms=ios --project-name flutter_arkit_floorplan
   flutter pub get
   ```
3. Drive the screenshot test:
   ```bash
   flutter drive \
     --driver test_driver/integration_test.dart \
     --target integration_test/screenshot_test.dart \
     -d "iPhone 17 Pro"
   ```
4. Build the demo GIF from the PNGs:
   ```bash
   cd screenshots
   ffmpeg -y -framerate 1 -pattern_type glob -i '*.png' \
     -vf "scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
     -loop 0 demo.gif
   ```

PNGs + `demo.gif` are written to `screenshots/` and embedded in `README.md`.

## How it works

- `test_driver/integration_test.dart` - `integrationDriver(onScreenshot:)` writes
  each PNG to `screenshots/<name>.png`.
- `integration_test/screenshot_test.dart` - pumps `ScanScreen` inside an
  `UncontrolledProviderScope`. Real LiDAR is absent on the simulator, so the test
  calls `ScanController.loadSample()`, which runs the bundled synthetic L-shaped
  room mesh through the real `FloorPlanGenerator`. It captures:
  - `01-scan-screen` - the landing screen (no LiDAR, "Sample mesh" control),
  - `02-floor-plan` - the generated 2D plan with metric grid + wall labels,
  - `03-plan-stats` - the plan with the live stats row (walls, floor area,
    ceiling height, mesh triangles) after tapping the on-screen control.
  Each shot calls `binding.convertFlutterSurfaceToImage()` +
  `binding.takeScreenshot('NN-name')`.
