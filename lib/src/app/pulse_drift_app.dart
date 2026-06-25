import 'package:flutter/material.dart';

import '../game/game_screen.dart';

void runPulseDriftApp({bool enableAds = true}) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PulseDriftApp(enableAds: enableAds));
}

class PulseDriftApp extends StatelessWidget {
  const PulseDriftApp({super.key, this.enableAds = false});

  final bool enableAds;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse Drift',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08111A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF25D7D9),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: GameScreen(enableAds: enableAds),
    );
  }
}
