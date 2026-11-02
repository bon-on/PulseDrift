import 'dart:math' as math;
import 'dart:ui';

import 'drift_palette.dart';

/// Builds the ship outline (nose up, centred on the origin) for [shape].
Path shipOutline(ShipShape shape) {
  final l = shape.length;
  final nose = Offset(0, -l * 0.55);
  final shoulderY = -l * 0.12;
  final tipY = -l * 0.55 + l * shape.sweep;
  final trailY = l * 0.42;
  final notchY = l * 0.28;
  final path = Path()..moveTo(nose.dx, nose.dy);
  void side(double s) {
    final shoulder = Offset(shape.bodyWidth * s, shoulderY);
    final tip = Offset(shape.wingSpan * s, tipY);
    final trailing = Offset(shape.wingSpan * 0.5 * s, trailY);
    if (s > 0) {
      path.lineTo(shoulder.dx, shoulder.dy);
      if (shape.curvedWings) {
        path.quadraticBezierTo(
          shape.wingSpan * 0.45 * s,
          shoulderY + l * 0.05,
          tip.dx,
          tip.dy,
        );
      } else {
        path.lineTo(tip.dx, tip.dy);
      }
      path.lineTo(trailing.dx, trailing.dy);
      path.lineTo(shape.bodyWidth * 0.8 * s, notchY);
    } else {
      path.lineTo(shape.bodyWidth * 0.8 * s, notchY);
      path.lineTo(trailing.dx, trailing.dy);
      path.lineTo(tip.dx, tip.dy);
      if (shape.curvedWings) {
        path.quadraticBezierTo(
          shape.wingSpan * 0.45 * s,
          shoulderY + l * 0.05,
          shoulder.dx,
          shoulder.dy,
        );
      } else {
        path.lineTo(shoulder.dx, shoulder.dy);
      }
    }
  }

  side(1);
  path.lineTo(0, notchY - l * 0.04);
  side(-1);
  path.close();
  return path;
}

/// Engine nozzle positions relative to the ship centre.
List<Offset> shipEngines(ShipShape shape) => [
  Offset(-shape.bodyWidth * 0.95, shape.length * 0.33),
  Offset(shape.bodyWidth * 0.95, shape.length * 0.33),
];

/// Paints the player ship at [center].
///
/// [tilt] (-1..1) banks toward a lane change, [squash] (0..1) stretches it
/// sideways right after one, [time] (seconds) drives the engine flicker.
void paintShip(
  Canvas canvas,
  Offset center,
  DriftPalette palette, {
  double tilt = 0,
  double squash = 0,
  double time = 0,
  double scale = 1,
  double glow = 1,
}) {
  final shape = palette.ship;
  final outline = shipOutline(shape);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(scale);
  canvas.rotate(tilt * 0.16);
  canvas.scale(
    (1 + squash * 0.22) * (1 - tilt.abs() * 0.12),
    1 - squash * 0.14,
  );

  // Under-glow so the ship reads on every road palette.
  if (glow > 0) {
    canvas.drawPath(
      outline,
      Paint()
        ..color = palette.shipAccent.withValues(alpha: 0.55 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  // Engine flames.
  final flicker = 0.75 + 0.25 * math.sin(time * 41);
  for (final engine in shipEngines(shape)) {
    final flame = Path()
      ..moveTo(engine.dx - 3.2, engine.dy - 1)
      ..quadraticBezierTo(
        engine.dx,
        engine.dy + 16 * flicker,
        engine.dx + 3.2,
        engine.dy - 1,
      )
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..color = palette.trailStart.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      engine,
      2.4,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95),
    );
  }

  // Body: lit from the side the ship banks away from.
  final bounds = outline.getBounds();
  final light = tilt.clamp(-1.0, 1.0) * 0.5;
  canvas.drawPath(
    outline,
    Paint()
      ..shader = Gradient.linear(
        Offset(bounds.left, 0),
        Offset(bounds.right, 0),
        [palette.shipShade, palette.shipBody, palette.shipShade],
        [0, (0.45 - light).clamp(0.15, 0.85), 1],
      ),
  );
  // Wing panel lines.
  final panel = Paint()
    ..color = palette.shipAccent.withValues(alpha: 0.7)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;
  final l = shape.length;
  for (final s in const [-1.0, 1.0]) {
    canvas.drawLine(
      Offset(shape.bodyWidth * s, -l * 0.02),
      Offset(shape.wingSpan * 0.72 * s, -l * 0.55 + l * shape.sweep * 0.98),
      panel,
    );
    if (shape.finLength > 0) {
      canvas.drawLine(
        Offset(shape.bodyWidth * 1.3 * s, l * 0.18),
        Offset(shape.bodyWidth * 1.7 * s, l * 0.18 + shape.finLength),
        Paint()
          ..color = palette.shipAccent
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }
  canvas.drawPath(
    outline,
    Paint()
      ..color = palette.shipAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round,
  );
  // Cockpit canopy with a highlight.
  final canopy = Rect.fromCenter(
    center: Offset(0, -l * 0.16),
    width: shape.bodyWidth * 1.5,
    height: l * 0.3,
  );
  canvas.drawOval(canopy, Paint()..color = palette.shipCockpit);
  canvas.drawOval(
    Rect.fromCenter(
      center: canopy.center.translate(-1, -canopy.height * 0.16),
      width: canopy.width * 0.38,
      height: canopy.height * 0.42,
    ),
    Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7),
  );
  canvas.restore();
}

/// Paints the engine trail from [points] (engine centre history, newest
/// first, in canvas coordinates). Older points fade and thin out.
void paintTrail(
  Canvas canvas,
  List<Offset> points,
  DriftPalette palette, {
  double width = 7,
}) {
  if (points.length < 2) return;
  final glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  final core = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final n = points.length - 1;
  for (var i = 0; i < n; i++) {
    final f = i / n;
    final color = Color.lerp(palette.trailStart, palette.trailEnd, f)!;
    final w = width * (1 - f * 0.85);
    glow
      ..color = color.withValues(alpha: 0.45 * (1 - f))
      ..strokeWidth = w * 1.8;
    core
      ..color = color.withValues(alpha: 0.9 * (1 - f))
      ..strokeWidth = w * 0.45;
    canvas.drawLine(points[i], points[i + 1], glow);
    canvas.drawLine(points[i], points[i + 1], core);
  }
}
