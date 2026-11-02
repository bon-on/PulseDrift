import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/art/drift_palette.dart';
import 'package:pulse_drift/src/art/scenery.dart';
import 'package:pulse_drift/src/art/ship_art.dart';
import 'package:pulse_drift/src/art/track_art.dart';
import 'package:pulse_drift/src/meta/drift_theme.dart';

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.theme, this.piece);

  final DriftTheme theme;
  final String piece;

  @override
  void paint(Canvas canvas, Size size) {
    final p = DriftPalette.of(theme);
    final c = size.center(Offset.zero);
    switch (piece) {
      case 'backdrop':
        paintBackdrop(canvas, size, p, time: 2, scroll: 400);
      case 'road':
        paintRoad(
          canvas,
          size,
          p,
          laneCenters: [size.width / 4, size.width / 2, size.width * 3 / 4],
          scroll: 900,
          speedFactor: 1,
          time: 3,
        );
      case 'gate':
        paintGateSegment(
          canvas,
          Rect.fromCenter(center: c, width: 78, height: 24),
          p,
          pulse: 1.3,
          heat: 1,
        );
        paintGapHint(canvas, c.translate(0, 40), p);
      case 'spark':
        paintSpark(canvas, c, 12, p, time: 0.7);
      case 'ship':
        paintShip(canvas, c, p, tilt: -0.6, squash: 0.5, time: 1.1);
      case 'trail':
        paintTrail(canvas, [
          for (var i = 0; i < 12; i++) c.translate(0, i * 6.0),
        ], p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  const pieces = ['backdrop', 'road', 'gate', 'spark', 'ship', 'trail'];
  for (final theme in DriftTheme.values) {
    for (final piece in pieces) {
      testWidgets('$piece paints for ${theme.label}', (tester) async {
        await tester.pumpWidget(
          Center(
            child: CustomPaint(
              size: const Size(320, 480),
              painter: _PiecePainter(theme, piece),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('every theme has a distinct palette and ship skin', () {
    final palettes = DriftTheme.values.map(DriftPalette.of).toList();
    expect(palettes.toSet().length, DriftTheme.values.length);
    expect(
      palettes.map((p) => p.ship).toSet().length,
      DriftTheme.values.length,
    );
  });

  test('ship outline is a closed shape around the centre', () {
    for (final theme in DriftTheme.values) {
      final bounds = shipOutline(DriftPalette.of(theme).ship).getBounds();
      expect(bounds.contains(Offset.zero), isTrue);
      expect(bounds.width, greaterThan(30));
      expect(bounds.height, greaterThan(30));
    }
  });

  test('scenery tolerates an empty canvas size', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintBackdrop(canvas, Size.zero, DriftPalette.neon);
    paintRoad(canvas, Size.zero, DriftPalette.neon, laneCenters: const []);
    recorder.endRecording().dispose();
  });
}
