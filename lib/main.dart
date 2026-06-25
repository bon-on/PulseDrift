import 'package:flutter/widgets.dart';

import 'src/ads/ad_service.dart';
import 'src/app/pulse_drift_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService.instance.initialize();
  runPulseDriftApp();
}
