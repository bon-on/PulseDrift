import 'package:flutter/material.dart';

import '../game/game_screen.dart';
import '../platform/game_platform.dart';

void runPulseDriftApp({
  bool enableAds = true,
  GamePlatform platform = const NoopGamePlatform(),
}) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    PulseDriftApp(
      enableAds: enableAds && platform.allowsAds,
      platform: platform,
    ),
  );
}

class PulseDriftApp extends StatelessWidget {
  const PulseDriftApp({
    super.key,
    this.enableAds = false,
    this.platform = const NoopGamePlatform(),
  });

  final bool enableAds;
  final GamePlatform platform;

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
      home: GameScreen(enableAds: enableAds, platform: platform),
    );
  }
}
