import 'package:flutter/material.dart';

import 'screens/library_screen.dart';
import 'services/background_reading.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sets up reading-with-the-screen-locked on Android (does nothing on
  // Windows, where a minimized app keeps running anyway).
  await BackgroundReading.init();
  runApp(const IdealReaderApp());
}

class IdealReaderApp extends StatelessWidget {
  const IdealReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ideal Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E5943),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E5943),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const LibraryScreen(),
    );
  }
}
