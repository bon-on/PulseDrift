import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A short-lived glowing dot (spark bursts, crash debris, multiplier rings).
class FxParticle {
  FxParticle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.color,
    required this.size,
  });

  Offset position;
  Offset velocity;
  final double life;
  double age = 0;
  final Color color;
  final double size;

  double get t => (age / life).clamp(0.0, 1.0);
}

/// A ship fragment flying apart on a crash.
class FxShard {
  FxShard({
    required this.position,
    required this.velocity,
    required this.spin,
    required this.size,
    required this.seed,
  });

  Offset position;
  Offset velocity;
  double angle = 0;
  final double spin;
  final double size;
  final int seed;
}

/// Floating text such as "+25" or "Close! +15".
class FxPopup {
  FxPopup({
    required this.text,
    required this.position,
    required this.color,
    this.size = 16,
    this.life = 0.8,
  });

  final String text;
  final Offset position;
  final Color color;
  final double size;
  final double life;
  double age = 0;

  double get t => (age / life).clamp(0.0, 1.0);
}

/// Centre-screen banner (multiplier bursts, completed missions).
class FxBanner {
  FxBanner({
    required this.title,
    required this.color,
    this.subtitle,
    this.life = 1.3,
    this.big = false,
  });

  final String title;
  final String? subtitle;
  final Color color;
  final double life;
  final bool big;
  double age = 0;

  double get t => (age / life).clamp(0.0, 1.0);
}

/// Expanding ring around a point (near miss, multiplier burst).
class FxRing {
  FxRing({
    required this.center,
    required this.color,
    this.life = 0.5,
    this.maxRadius = 70,
  });

  final Offset center;
  final Color color;
  final double life;
  final double maxRadius;
  double age = 0;

  double get t => (age / life).clamp(0.0, 1.0);
}

/// Visual-only effect state for the playfield. It never touches game rules:
/// the screen reports events, [advance] ages everything once per frame, and
/// the painters read it. One instance lives as long as the screen, so the
/// effect clock survives layout switches.
class DriftFx extends ChangeNotifier {
  DriftFx({int seed = 7}) : _random = math.Random(seed);

  final math.Random _random;

  /// Seconds since the screen started; drives loops (pulses, flicker).
  double clock = 0;

  /// Pixels the road has scrolled (parallax and grid offsets).
  double scroll = 0;
  double _scrollSpeed = 70;

  /// Recent ship x positions, newest first, with their clock time.
  final List<(double, double)> trail = <(double, double)>[];

  final List<FxParticle> particles = <FxParticle>[];
  final List<FxShard> shards = <FxShard>[];
  final List<FxPopup> popups = <FxPopup>[];
  final List<FxBanner> banners = <FxBanner>[];
  final List<FxRing> rings = <FxRing>[];

  double shake = 0;
  double flash = 0;

  /// True from a crash until the next run: the ship is drawn as shards.
  bool shattered = false;

  /// Current road scroll speed in pixels per second.
  double get scrollSpeed => _scrollSpeed;

  static const double trailSeconds = 0.26;

  /// Ages every effect by [dt] seconds. [roadSpeed] is the speed the road
  /// should scroll at (world speed while running, slow drift otherwise),
  /// [shipX] the ship's current x for the trail (null hides the trail).
  void advance(double dt, {required double roadSpeed, double? shipX}) {
    if (dt <= 0) return;
    // A long frame (tab switch) must not fling effects across the screen.
    final step = math.min(dt, 0.05);
    clock += step;
    _scrollSpeed += (roadSpeed - _scrollSpeed) * math.min(1.0, step * 3);
    scroll += _scrollSpeed * step;

    if (shipX != null && !shattered) {
      trail.insert(0, (shipX, clock));
    }
    trail.removeWhere((p) => clock - p.$2 > trailSeconds);
    if (shattered) trail.clear();

    for (final p in particles) {
      p.age += step;
      p.position += p.velocity * step;
      p.velocity = p.velocity * math.pow(0.08, step).toDouble();
    }
    particles.removeWhere((p) => p.age >= p.life);

    for (final s in shards) {
      s.position += s.velocity * step;
      s.velocity =
          s.velocity * math.pow(0.35, step).toDouble() + Offset(0, 160 * step);
      s.angle += s.spin * step;
    }

    for (final p in popups) {
      p.age += step;
    }
    popups.removeWhere((p) => p.age >= p.life);
    for (final b in banners) {
      b.age += step;
    }
    banners.removeWhere((b) => b.age >= b.life);
    for (final r in rings) {
      r.age += step;
    }
    rings.removeWhere((r) => r.age >= r.life);

    shake = math.max(0, shake - step * 2.6);
    flash = math.max(0, flash - step * 2.2);
    notifyListeners();
  }

  /// Camera offset for the current shake.
  Offset get shakeOffset {
    if (shake <= 0) return Offset.zero;
    final a = shake * shake * 14;
    return Offset(math.sin(clock * 97) * a, math.cos(clock * 83) * a * 0.7);
  }

  void burst(Offset at, Color color, {int count = 14, double speed = 260}) {
    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final v = speed * (0.4 + _random.nextDouble() * 0.8);
      particles.add(
        FxParticle(
          position: at,
          velocity: Offset(math.cos(angle) * v, math.sin(angle) * v),
          life: 0.35 + _random.nextDouble() * 0.35,
          color: color,
          size: 1.6 + _random.nextDouble() * 2.4,
        ),
      );
    }
  }

  void popup(String text, Offset at, Color color, {double size = 16}) {
    popups.add(FxPopup(text: text, position: at, color: color, size: size));
  }

  void ring(Offset at, Color color, {double maxRadius = 70}) {
    rings.add(FxRing(center: at, color: color, maxRadius: maxRadius));
  }

  void banner(String title, Color color, {String? subtitle, bool big = false}) {
    // Keep at most two on screen; newer ones replace the oldest.
    if (banners.length >= 2) banners.removeAt(0);
    banners.add(
      FxBanner(
        title: title,
        subtitle: subtitle,
        color: color,
        big: big,
        life: big ? 1.0 : 1.6,
      ),
    );
  }

  /// Breaks the ship at [at] into shards and shakes the camera.
  void crash(Offset at, List<Color> colors) {
    shattered = true;
    shake = 1;
    flash = 1;
    for (var i = 0; i < 14; i++) {
      final angle = -math.pi / 2 + (_random.nextDouble() - 0.5) * math.pi * 1.8;
      final v = 120 + _random.nextDouble() * 260;
      shards.add(
        FxShard(
          position: at,
          velocity: Offset(math.cos(angle) * v, math.sin(angle) * v),
          spin: (_random.nextDouble() - 0.5) * 18,
          size: 5 + _random.nextDouble() * 9,
          seed: i,
        ),
      );
    }
    for (final color in colors) {
      burst(at, color, count: 12, speed: 340);
    }
  }

  /// Clears run effects for a fresh run (the clock and scroll keep going).
  void resetRun() {
    shattered = false;
    shards.clear();
    particles.clear();
    popups.clear();
    banners.clear();
    rings.clear();
    trail.clear();
    shake = 0;
    flash = 0;
    notifyListeners();
  }
}
