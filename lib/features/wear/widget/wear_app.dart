import 'package:flutter/material.dart';
import 'package:hiddify/features/wear/widget/wear_root.dart';

/// Root MaterialApp for the Wear OS build. Dark, OLED-friendly theme; the whole
/// widget tree runs inside the bootstrap [ProviderScope], so screens read the
/// real Hiddify providers.
class WearApp extends StatelessWidget {
  const WearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hiddify Watch',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3446A5),
          brightness: Brightness.dark,
        ),
      ),
      home: const WearRoot(),
    );
  }
}
