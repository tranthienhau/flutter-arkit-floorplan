import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/ui/scan_screen.dart';

void main() => runApp(const ProviderScope(child: FloorPlanApp()));

class FloorPlanApp extends StatelessWidget {
  const FloorPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARKit Floor Plan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3D7BFF),
        useMaterial3: true,
      ),
      home: const ScanScreen(),
    );
  }
}
