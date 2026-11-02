import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/drift_palette.dart';
import '../art/scenery.dart';
import '../art/ship_art.dart';
import '../art/track_art.dart';
import 'game_balance.dart';
import 'game_controller.dart';
import 'ui/drift_fx.dart';

/// Paints the playfield: road, gates, sparks, ship with trail, and every
/// effect in [fx]. Repaints on controller or fx changes; no widget rebuilds.
class GamePainter extends CustomPainter {
  GamePainter({
    required this.controller,
    required this.fx,
    required this.palette,
    this.running = true,
  }) : super(repaint: Listenable.merge([controller, fx]));

  final GameController controller;
  final DriftFx fx;
  final DriftPalette palette;

  /// False on the ready card: the ship hovers and no squash is applied.
  final bool running;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(fx.shakeOffset.dx, fx.shakeOffset.dy);
    final lanes = controller.laneCenters.isEmpty
        ? GameGeometry.laneCentersForWidth(size.width)
        : controller.laneCenters;
    final speedFactor = running && !controller.isGameOver
        ? ((controller.speed - GameBalance.baseSpeed) /
                  (GameBalance.maxSpeed - GameBalance.baseSpeed))
              .clamp(0.0, 1.0)
        : 0.0;
    paintRoad(
      canvas,
      size,
      palette,
      laneCenters: lanes,
      scroll: fx.scroll,
      speedFactor: 0.25 + 0.75 * speedFactor,
      time: fx.clock,
    );

    final playerY = controller.playerY == 0
        ? size.height * GameBalance.playerAnchorHeightFactor
        : controller.playerY;

    for (final gate in controller.gates) {
      final distance = (playerY - gate.yPosition).abs();
      final heat = (1 - distance / (size.height * 0.6)).clamp(0.0, 1.0);
      for (var lane = 0; lane < lanes.length; lane++) {
        final center = Offset(lanes[lane], gate.yPosition);
        if (gate.openLanes.contains(lane)) {
          if (!gate.scored) {
            paintGapHint(canvas, center, palette, alpha: 0.4 + 0.6 * heat);
          }
          continue;
        }
        paintGateSegment(
          canvas,
          Rect.fromCenter(
            center: center,
            width: GameBalance.gateWidth,
            height: GameBalance.gateHeight,
          ),
          palette,
          pulse: fx.clock + gate.yPosition * 0.002,
          heat: heat,
        );
      }
    }

    for (final spark in controller.sparks) {
      paintSpark(
        canvas,
        Offset(lanes[spark.lane], spark.yPosition),
        GameBalance.sparkRadius,
        palette,
        time: fx.clock,
      );
    }

    _paintShip(canvas, lanes, playerY);
    _paintEffects(canvas, size);
    canvas.restore();

    if (fx.flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = palette.gateCore.withValues(alpha: 0.35 * fx.flash),
      );
    }
  }

  void _paintShip(Canvas canvas, List<double> lanes, double playerY) {
    if (fx.shattered) {
      _paintShards(canvas);
      return;
    }
    final x = controller.playerVisualX == 0 && lanes.isNotEmpty
        ? lanes[controller.currentLane]
        : controller.playerVisualX;
    final spacing = lanes.length >= 2 ? lanes[1] - lanes[0] : 100.0;
    final target = lanes.isEmpty ? x : lanes[controller.currentLane];
    final tilt = ((target - x) / (spacing * 0.6)).clamp(-1.0, 1.0);
    final sinceChange = controller.runSeconds - controller.laneChangedAt;
    final squash = running && sinceChange >= 0 && sinceChange < 0.22
        ? math.sin(sinceChange / 0.22 * math.pi)
        : 0.0;
    final hover = running ? 0.0 : math.sin(fx.clock * 2.4) * 4;
    final center = Offset(x, playerY + hover);

    // Trail: engine positions from the recent x history, streaming down
    // at road speed.
    final engines = shipEngines(palette.ship);
    for (final engine in engines) {
      final points = <Offset>[
        for (final (px, at) in fx.trail)
          Offset(
            px + engine.dx,
            playerY + hover + engine.dy + (fx.clock - at) * fx.scrollSpeed,
          ),
      ];
      paintTrail(canvas, points, palette, width: 6);
    }
    paintShip(
      canvas,
      center,
      palette,
      tilt: tilt,
      squash: squash,
      time: fx.clock,
    );

    if (controller.nearMissFlash > 0) {
      final a = (controller.nearMissFlash / 0.6).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        GameBalance.playerRadius + 18 + (1 - a) * 14,
        Paint()
          ..color = palette.gold.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _paintShards(Canvas canvas) {
    final fill = Paint()..color = palette.shipBody;
    final edge = Paint()
      ..color = palette.shipAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final s in fx.shards) {
      canvas.save();
      canvas.translate(s.position.dx, s.position.dy);
      canvas.rotate(s.angle);
      final r = s.size;
      final path = Path()
        ..moveTo(0, -r)
        ..lineTo(r * (0.5 + (s.seed % 3) * 0.2), r * 0.6)
        ..lineTo(-r * 0.7, r * 0.4)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
      canvas.restore();
    }
  }

  void _paintEffects(Canvas canvas, Size size) {
    final dot = Paint();
    for (final p in fx.particles) {
      dot.color = p.color.withValues(alpha: 1 - p.t);
      canvas.drawCircle(p.position, p.size * (1 - p.t * 0.5), dot);
    }
    for (final r in fx.rings) {
      canvas.drawCircle(
        r.center,
        20 + r.maxRadius * Curves.easeOut.transform(r.t),
        Paint()
          ..color = r.color.withValues(alpha: (1 - r.t) * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - r.t) + 1,
      );
    }
    for (final p in fx.popups) {
      final rise = Curves.easeOut.transform(p.t) * 46;
      final pop = p.t < 0.15 ? 0.7 + p.t / 0.15 * 0.3 : 1.0;
      _text(
        canvas,
        p.text,
        p.position.translate(0, -rise),
        p.color.withValues(alpha: 1 - Curves.easeIn.transform(p.t)),
        p.size * pop,
      );
    }
    var y = size.height * 0.3;
    for (final b in fx.banners) {
      final appear = Curves.easeOutBack.transform((b.t / 0.18).clamp(0.0, 1.0));
      final fade = b.t > 0.75 ? 1 - (b.t - 0.75) / 0.25 : 1.0;
      _text(
        canvas,
        b.title,
        Offset(size.width / 2, y),
        b.color.withValues(alpha: fade),
        (b.big ? 44 : 22) * (0.6 + 0.4 * appear),
        glow: true,
      );
      if (b.subtitle != null) {
        _text(
          canvas,
          b.subtitle!,
          Offset(size.width / 2, y + (b.big ? 34 : 24)),
          palette.text.withValues(alpha: 0.9 * fade),
          14,
        );
      }
      y += b.big ? 76 : 58;
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double size, {
    bool glow = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: color.withValues(alpha: 0.8),
              blurRadius: glow ? 16 : 8,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center.translate(-painter.width / 2, -painter.height / 2),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.fx != fx ||
      oldDelegate.palette != palette ||
      oldDelegate.running != running;
}

/// Full-screen synthwave scenery behind the whole layout. Static by default
/// (it only repaints on a theme change) so the large blurred sun is not
/// redrawn every frame; the playfield carries the motion.
class BackdropPainter extends CustomPainter {
  BackdropPainter({
    required this.fx,
    required this.palette,
    this.animate = false,
  }) : super(repaint: animate ? fx : null);

  final DriftFx fx;
  final DriftPalette palette;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    paintBackdrop(
      canvas,
      size,
      palette,
      time: animate ? fx.clock : 0,
      scroll: animate ? fx.scroll * 0.6 : 0,
    );
  }

  @override
  bool shouldRepaint(covariant BackdropPainter oldDelegate) =>
      oldDelegate.palette != palette || oldDelegate.fx != fx;
}
