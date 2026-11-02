import 'dart:math' as math;
import 'dart:ui';

import 'drift_palette.dart';

/// Paints one walled lane of a pulse gate into [rect].
///
/// [pulse] (seconds) drives the travelling energy band; [heat] (0..1)
/// brightens the gate as it nears the ship.
void paintGateSegment(
  Canvas canvas,
  Rect rect,
  DriftPalette palette, {
  double pulse = 0,
  double heat = 0,
}) {
  final radius = Radius.circular(rect.height / 2);
  final rrect = RRect.fromRectAndRadius(rect, radius);
  final glowAlpha = 0.5 + 0.3 * heat + 0.12 * math.sin(pulse * 9);
  canvas.drawRRect(
    rrect.inflate(3),
    Paint()
      ..color = palette.gateGlow.withValues(alpha: glowAlpha.clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [
          Color.lerp(palette.gateCore, palette.gateHot, 0.35 + 0.3 * heat)!,
          palette.gateCore,
          Color.lerp(palette.gateCore, const Color(0xFF000000), 0.35)!,
        ],
        const [0, 0.55, 1],
      ),
  );
  // Energy band sweeping along the bar.
  canvas.save();
  canvas.clipRRect(rrect);
  final sweep = (pulse * 1.6) % 1.0;
  final bandX = rect.left - rect.width * 0.4 + sweep * rect.width * 1.8;
  canvas.drawRect(
    Rect.fromLTWH(bandX, rect.top, rect.width * 0.28, rect.height),
    Paint()
      ..shader = Gradient.linear(
        Offset(bandX, 0),
        Offset(bandX + rect.width * 0.28, 0),
        [
          palette.gateHot.withValues(alpha: 0),
          palette.gateHot.withValues(alpha: 0.75),
          palette.gateHot.withValues(alpha: 0),
        ],
        const [0, 0.5, 1],
      ),
  );
  // Hazard chevrons.
  final chevron = Paint()
    ..color = const Color(0xFF000000).withValues(alpha: 0.22)
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;
  for (var x = rect.left + 6.0; x < rect.right; x += 12) {
    canvas.drawLine(Offset(x, rect.bottom), Offset(x + 6, rect.top), chevron);
  }
  canvas.restore();
  // Bright core line and rim.
  canvas.drawLine(
    Offset(rect.left + rect.height / 2, rect.center.dy - rect.height * 0.18),
    Offset(rect.right - rect.height / 2, rect.center.dy - rect.height * 0.18),
    Paint()
      ..color = palette.gateHot.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = palette.gateHot.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
}

/// Small upward chevrons marking an open gap of a gate.
void paintGapHint(
  Canvas canvas,
  Offset center,
  DriftPalette palette, {
  double alpha = 1,
}) {
  final paint = Paint()
    ..color = palette.laneLine.withValues(alpha: 0.55 * alpha)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  for (var i = 0; i < 2; i++) {
    final y = center.dy + 4 - i * 7;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 7, y + 4)
        ..lineTo(center.dx, y - 2)
        ..lineTo(center.dx + 7, y + 4),
      paint,
    );
  }
}

/// Four-point star spark at [center]; [time] spins and pulses it.
void paintSpark(
  Canvas canvas,
  Offset center,
  double radius,
  DriftPalette palette, {
  double time = 0,
}) {
  final pulse = 1 + 0.12 * math.sin(time * 7);
  canvas.drawCircle(
    center,
    radius * 1.5 * pulse,
    Paint()
      ..color = palette.sparkGlow.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(time * 1.8);
  final r = radius * 1.15 * pulse;
  final inner = r * 0.32;
  final star = Path();
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4 - math.pi / 2;
    final d = i.isEven ? r : inner;
    final p = Offset(math.cos(a) * d, math.sin(a) * d);
    if (i == 0) {
      star.moveTo(p.dx, p.dy);
    } else {
      star.lineTo(p.dx, p.dy);
    }
  }
  star.close();
  canvas.drawPath(star, Paint()..color = palette.spark);
  canvas.drawPath(
    star,
    Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
  canvas.drawCircle(
    Offset.zero,
    inner * 0.9,
    Paint()..color = const Color(0xFFFFFFFF),
  );
  canvas.restore();
}
