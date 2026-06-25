import 'package:flutter/material.dart';

import 'game_balance.dart';
import 'game_controller.dart';

class GamePainter extends CustomPainter {
  const GamePainter({required this.controller}) : super(repaint: controller);

  final GameController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 2;

    final laneCenters = controller.laneCenters;
    for (final xPosition in laneCenters) {
      canvas.drawLine(
        Offset(xPosition, 0),
        Offset(xPosition, size.height),
        lanePaint,
      );
    }

    final gateFill = Paint()..color = const Color(0xFFFF914D);
    final gateStroke = Paint()
      ..color = const Color(0xFFFF523C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final gate in controller.gates) {
      for (var lane = 0; lane < laneCenters.length; lane++) {
        if (lane == gate.blockedLane) {
          continue;
        }

        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(laneCenters[lane], gate.yPosition),
            width: GameBalance.gateWidth,
            height: GameBalance.gateHeight,
          ),
          const Radius.circular(12),
        );
        canvas.drawRRect(rect, gateFill);
        canvas.drawRRect(rect, gateStroke);
      }
    }

    final sparkFill = Paint()..color = const Color(0xFF3DE8E0);
    final sparkStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final spark in controller.sparks) {
      final center = Offset(laneCenters[spark.lane], spark.yPosition);
      canvas.drawCircle(
        center,
        GameBalance.sparkRadius + 5,
        sparkFill..color = const Color(0x663DE8E0),
      );
      sparkFill.color = const Color(0xFF3DE8E0);
      canvas.drawCircle(center, GameBalance.sparkRadius, sparkFill);
      canvas.drawCircle(center, GameBalance.sparkRadius, sparkStroke);
    }

    final playerCenter = Offset(controller.playerVisualX, controller.playerY);
    final playerGlow = Paint()..color = const Color(0x6633FFE2);
    final playerFill = Paint()..color = Colors.white;
    final playerStroke = Paint()
      ..color = const Color(0xFF59FFDB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(playerCenter, GameBalance.playerRadius + 8, playerGlow);
    canvas.drawCircle(playerCenter, GameBalance.playerRadius, playerFill);
    canvas.drawCircle(playerCenter, GameBalance.playerRadius, playerStroke);
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.controller != controller;
  }
}
