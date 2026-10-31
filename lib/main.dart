import 'package:flutter/widgets.dart';

import 'src/ads/ad_service.dart';
import 'src/app/pulse_drift_app.dart';
import 'src/platform/game_platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = createGamePlatform();
  await platform.initialize();
  // Portal builds (CrazyGames) never initialise or show ads.
  if (platform.allowsAds) {
    await AdService.instance.initialize();
  }
  runPulseDriftApp(platform: platform);
}
