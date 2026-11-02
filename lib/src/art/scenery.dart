import 'dart:math' as math;
import 'dart:ui';

import 'drift_palette.dart';

class _Star {
  const _Star(this.x, this.y, this.size, this.phase);

  final double x;
  final double y;
  final double size;
  final double phase;
}

List<_Star> _makeStars(int count, int seed) {
  final random = math.Random(seed);
  return List<_Star>.generate(
    count,
    (_) => _Star(
      random.nextDouble(),
      random.nextDouble(),
      0.5 + random.nextDouble() * 1.4,
      random.nextDouble() * math.pi * 2,
    ),
    growable: false,
  );
}

final List<_Star> _skyStars = _makeStars(90, 11);
final List<_Star> _farStars = _makeStars(46, 23);
final List<_Star> _nearStars = _makeStars(22, 37);
final List<_Star> _streaks = _makeStars(26, 51);

/// Ridge heights (0..1) for the mountain silhouettes, fixed for every run.
final List<double> _ridgeBack = _ridge(17, 5);
final List<double> _ridgeFront = _ridge(23, 9);

List<double> _ridge(int points, int seed) {
  final random = math.Random(seed);
  return List<double>.generate(
    points,
    (i) => 0.25 + random.nextDouble() * 0.75,
    growable: false,
  );
}

/// Fraction of the backdrop height where the horizon sits.
const double horizonFactor = 0.6;

/// Full-screen synthwave scenery: sky, stars, striped sun, mountains and a
/// perspective grid floor. [scroll] (pixels travelled) moves the floor and
/// [time] (seconds) twinkles the stars.
void paintBackdrop(
  Canvas canvas,
  Size size,
  DriftPalette palette, {
  double time = 0,
  double scroll = 0,
}) {
  final w = size.width;
  final h = size.height;
  if (w <= 0 || h <= 0) return;
  final horizon = h * horizonFactor;

  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, horizon + 1),
    Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        Offset(0, horizon),
        [palette.skyTop, palette.skyMid, palette.skyBottom],
        const [0, 0.55, 1],
      ),
  );

  final starPaint = Paint();
  for (final star in _skyStars) {
    final y = star.y * horizon * 0.85;
    final twinkle = 0.45 + 0.55 * math.sin(time * 1.6 + star.phase).abs();
    starPaint.color = palette.star.withValues(
      alpha: twinkle * (1 - y / horizon) * 0.9,
    );
    canvas.drawCircle(Offset(star.x * w, y), star.size * 0.8, starPaint);
  }

  // Sun with horizontal cut stripes in its lower half.
  final sunR = math.min(w * 0.17, h * 0.24);
  final sunC = Offset(w / 2, horizon - sunR * 0.42);
  canvas.drawCircle(
    sunC,
    sunR * 1.25,
    Paint()
      ..color = palette.sunBottom.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sunR * 0.35),
  );
  canvas.save();
  canvas.clipRect(Rect.fromLTWH(0, 0, w, horizon));
  final sunRect = Rect.fromCircle(center: sunC, radius: sunR);
  final sun = Path()..addOval(sunRect);
  final cuts = Path();
  for (var i = 0; i < 6; i++) {
    final y = sunC.dy + sunR * (0.08 + i * 0.16);
    final gap = 2.0 + i * 1.6;
    cuts.addRect(Rect.fromLTWH(sunRect.left - 2, y, sunRect.width + 4, gap));
  }
  canvas.drawPath(
    Path.combine(PathOperation.difference, sun, cuts),
    Paint()
      ..shader = Gradient.linear(sunRect.topCenter, sunRect.bottomCenter, [
        palette.sunTop,
        palette.sunBottom,
      ]),
  );
  canvas.restore();

  // Mountains: a pale back ridge and a dark front ridge with a neon rim.
  _paintRidge(
    canvas,
    w,
    horizon,
    _ridgeBack,
    h * 0.16,
    Color.lerp(palette.mountain, palette.skyBottom, 0.45)!,
    null,
  );
  _paintRidge(
    canvas,
    w,
    horizon,
    _ridgeFront,
    h * 0.11,
    palette.mountain,
    palette.mountainEdge,
  );

  // Floor and perspective grid.
  canvas.drawRect(
    Rect.fromLTWH(0, horizon, w, h - horizon),
    Paint()
      ..shader = Gradient.linear(Offset(0, horizon), Offset(0, h), [
        palette.mountain,
        palette.roadTop,
      ]),
  );
  final grid = Paint()..strokeWidth = 1.2;
  final depth = h - horizon;
  const rows = 12;
  final phase = (scroll / 90) % 1.0;
  for (var i = 0; i < rows; i++) {
    final f = (i + phase) / rows;
    final y = horizon + depth * f * f;
    grid.color = palette.floorGrid.withValues(alpha: 0.15 + 0.6 * f);
    canvas.drawLine(Offset(0, y), Offset(w, y), grid);
  }
  final vanish = Offset(w / 2, horizon);
  const columns = 18;
  for (var i = -columns; i <= columns; i++) {
    final x = w / 2 + i * w / 9;
    grid.color = palette.floorGrid.withValues(alpha: 0.45);
    canvas.drawLine(vanish, Offset(x, h), grid);
  }
  canvas.drawRect(
    Rect.fromLTWH(0, horizon - 1.5, w, 3),
    Paint()
      ..color = palette.mountainEdge.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
}

void _paintRidge(
  Canvas canvas,
  double w,
  double horizon,
  List<double> ridge,
  double height,
  Color fill,
  Color? rim,
) {
  final path = Path()..moveTo(0, horizon);
  final step = w / (ridge.length - 1);
  for (var i = 0; i < ridge.length; i++) {
    // Keep the middle low so the sun stays visible.
    final mid = (i * step - w / 2).abs() / (w / 2);
    final damp = 0.25 + 0.75 * math.min(1.0, mid * 1.6);
    path.lineTo(i * step, horizon - ridge[i] * height * damp);
  }
  path
    ..lineTo(w, horizon)
    ..close();
  canvas.drawPath(path, Paint()..color = fill);
  if (rim != null) {
    canvas.drawPath(
      path,
      Paint()
        ..color = rim.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }
}

/// Top-down neon road behind the lanes: parallax stars, a scrolling grid,
/// glowing lane dividers and edges, and speed streaks. [laneCenters] are the
/// gameplay lane centres; [speedFactor] (0..1) scales the streaks.
void paintRoad(
  Canvas canvas,
  Size size,
  DriftPalette palette, {
  required List<double> laneCenters,
  double scroll = 0,
  double speedFactor = 0,
  double time = 0,
}) {
  final w = size.width;
  final h = size.height;
  if (w <= 0 || h <= 0) return;
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = Gradient.linear(Offset.zero, Offset(0, h), [
        palette.roadTop,
        palette.roadBottom,
      ]),
  );

  final starPaint = Paint();
  void layer(List<_Star> stars, double parallax, double alpha) {
    for (final star in stars) {
      final y = (star.y * h + scroll * parallax) % h;
      starPaint.color = palette.star.withValues(alpha: alpha);
      canvas.drawCircle(Offset(star.x * w, y), star.size, starPaint);
    }
  }

  layer(_farStars, 0.12, 0.35);
  layer(_nearStars, 0.3, 0.6);

  // Road grid.
  const cell = 46.0;
  final grid = Paint()
    ..color = palette.roadGrid.withValues(alpha: 0.3)
    ..strokeWidth = 1;
  final offset = scroll % cell;
  for (var y = offset - cell; y < h; y += cell) {
    canvas.drawLine(Offset(0, y), Offset(w, y), grid);
  }
  final spacing = laneCenters.length >= 2
      ? laneCenters[1] - laneCenters[0]
      : w / 4;
  final left = laneCenters.isEmpty ? 0.0 : laneCenters.first - spacing / 2;
  final right = laneCenters.isEmpty ? w : laneCenters.last + spacing / 2;
  for (var x = left; x <= right + 0.5; x += spacing / 2) {
    canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
  }

  // Lane surfaces: a faint glassy strip per lane.
  final strip = Paint()..color = palette.laneLine.withValues(alpha: 0.035);
  for (final c in laneCenters) {
    canvas.drawRect(
      Rect.fromLTWH(c - spacing * 0.42, 0, spacing * 0.84, h),
      strip,
    );
  }

  // Speed streaks.
  if (speedFactor > 0.01) {
    final streak = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final s in _streaks) {
      final len = 30 + 90 * speedFactor * s.size / 1.9;
      final y = (s.y * (h + len) + scroll * (1.6 + s.size)) % (h + len) - len;
      streak.color = palette.laneLine.withValues(
        alpha: 0.08 + 0.32 * speedFactor * (s.size / 1.9),
      );
      canvas.drawLine(Offset(s.x * w, y), Offset(s.x * w, y + len), streak);
    }
  }

  // Dashed lane dividers.
  final dividerGlow = Paint()
    ..color = palette.laneLine.withValues(alpha: 0.5)
    ..strokeWidth = 4
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final divider = Paint()
    ..color = palette.laneLine.withValues(alpha: 0.85)
    ..strokeWidth = 1.6;
  const dash = 26.0;
  const gap = 18.0;
  final dashOffset = scroll % (dash + gap);
  for (var i = 0; i < laneCenters.length - 1; i++) {
    final x = (laneCenters[i] + laneCenters[i + 1]) / 2;
    for (var y = dashOffset - dash - gap; y < h; y += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dash), dividerGlow);
      canvas.drawLine(Offset(x, y), Offset(x, y + dash), divider);
    }
  }

  // Road edges.
  final edgeGlow = Paint()
    ..color = palette.edgeGlow.withValues(alpha: 0.75)
    ..strokeWidth = 6
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  final edge = Paint()
    ..color = Color.lerp(palette.edgeGlow, const Color(0xFFFFFFFF), 0.35)!
    ..strokeWidth = 2;
  for (final x in [left, right]) {
    canvas.drawLine(Offset(x, 0), Offset(x, h), edgeGlow);
    canvas.drawLine(Offset(x, 0), Offset(x, h), edge);
  }

  // Fade at the top so gates rise out of the dark.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h * 0.18),
    Paint()
      ..shader = Gradient.linear(Offset.zero, Offset(0, h * 0.18), [
        palette.roadTop,
        palette.roadTop.withValues(alpha: 0),
      ]),
  );
}
