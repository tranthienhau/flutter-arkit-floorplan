import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_arkit_floorplan/src/ui/scan_screen.dart';
import 'package:flutter_arkit_floorplan/src/providers/scan_providers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot(WidgetTester tester, String name) async {
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Widget app() => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF3D7BFF),
          useMaterial3: true,
        ),
        home: const ScanScreen(),
      );

  testWidgets('capture ARKit floor-plan flow', (tester) async {
    // Real LiDAR is absent on the simulator, so seed the controller with the
    // bundled synthetic mesh to show the full pipeline output (walls + stats).
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(),
      ),
    );
    await tester.pumpAndSettle();

    // 01 - intro / scan landing screen.
    await shoot(tester, '01-scan-screen');

    // Run the on-device generator on the synthetic LiDAR mesh.
    container.read(scanControllerProvider.notifier).loadSample();
    await tester.pumpAndSettle();

    // 02 - generated 2D floor plan with metric grid + wall labels.
    await shoot(tester, '02-floor-plan');

    // 03 - drive the real on-screen control: tap the "Sample mesh" button so
    // the capture shows the interactive button row + the rendered plan/stats.
    await tester.tap(find.text('Sample mesh'));
    await tester.pumpAndSettle();
    await shoot(tester, '03-plan-stats');
  });
}
