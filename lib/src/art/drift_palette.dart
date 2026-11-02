import 'dart:ui';

import '../meta/drift_theme.dart';

/// Ship silhouette parameters; every theme flies its own skin.
class ShipShape {
  const ShipShape({
    required this.wingSpan,
    required this.length,
    required this.sweep,
    required this.finLength,
    required this.bodyWidth,
    required this.curvedWings,
  });

  /// Half width from the centre line to a wing tip.
  final double wingSpan;

  /// Nose to tail.
  final double length;

  /// 0..1: how far back the wing tips sit (1 = at the tail).
  final double sweep;

  /// Length of the twin tail fins (0 = none).
  final double finLength;

  /// Half width of the fuselage.
  final double bodyWidth;

  /// Swept-curve wings instead of straight delta edges.
  final bool curvedWings;
}

/// Colours for one [DriftTheme]: backdrop scenery, road, track pieces, ship
/// and UI chrome.
class DriftPalette {
  const DriftPalette({
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.sunTop,
    required this.sunBottom,
    required this.mountain,
    required this.mountainEdge,
    required this.floorGrid,
    required this.roadTop,
    required this.roadBottom,
    required this.roadGrid,
    required this.laneLine,
    required this.edgeGlow,
    required this.star,
    required this.gateCore,
    required this.gateHot,
    required this.gateGlow,
    required this.spark,
    required this.sparkGlow,
    required this.shipBody,
    required this.shipShade,
    required this.shipCockpit,
    required this.shipAccent,
    required this.trailStart,
    required this.trailEnd,
    required this.accent,
    required this.accent2,
    required this.gold,
    required this.panel,
    required this.panelBorder,
    required this.text,
    required this.textDim,
    required this.ship,
  });

  final Color skyTop;
  final Color skyMid;
  final Color skyBottom;
  final Color sunTop;
  final Color sunBottom;
  final Color mountain;
  final Color mountainEdge;
  final Color floorGrid;
  final Color roadTop;
  final Color roadBottom;
  final Color roadGrid;
  final Color laneLine;
  final Color edgeGlow;
  final Color star;
  final Color gateCore;
  final Color gateHot;
  final Color gateGlow;
  final Color spark;
  final Color sparkGlow;
  final Color shipBody;
  final Color shipShade;
  final Color shipCockpit;
  final Color shipAccent;
  final Color trailStart;
  final Color trailEnd;

  /// Main UI accent (buttons, bars) and the secondary one (highlights).
  final Color accent;
  final Color accent2;

  /// Rewards: near misses, new bests, mission ticks.
  final Color gold;
  final Color panel;
  final Color panelBorder;
  final Color text;
  final Color textDim;
  final ShipShape ship;

  static DriftPalette of(DriftTheme theme) {
    switch (theme) {
      case DriftTheme.neon:
        return neon;
      case DriftTheme.sunset:
        return sunset;
      case DriftTheme.aurora:
        return aurora;
      case DriftTheme.voidline:
        return voidline;
    }
  }

  static const DriftPalette neon = DriftPalette(
    skyTop: Color(0xFF07021A),
    skyMid: Color(0xFF26074A),
    skyBottom: Color(0xFF6A0A6E),
    sunTop: Color(0xFFFFE45C),
    sunBottom: Color(0xFFFF2A8A),
    mountain: Color(0xFF1A0636),
    mountainEdge: Color(0xFFFF4FD8),
    floorGrid: Color(0xFFFF3BD4),
    roadTop: Color(0xFF0C0520),
    roadBottom: Color(0xFF1B0838),
    roadGrid: Color(0xFF7B2CFF),
    laneLine: Color(0xFF29F3FF),
    edgeGlow: Color(0xFFFF3BD4),
    star: Color(0xFFE9E4FF),
    gateCore: Color(0xFFFF2A6D),
    gateHot: Color(0xFFFFC2D8),
    gateGlow: Color(0xFFFF2A6D),
    spark: Color(0xFF29F3FF),
    sparkGlow: Color(0xFF29F3FF),
    shipBody: Color(0xFFEAF6FF),
    shipShade: Color(0xFF8E9BD8),
    shipCockpit: Color(0xFF2A0F5C),
    shipAccent: Color(0xFF29F3FF),
    trailStart: Color(0xFF29F3FF),
    trailEnd: Color(0xFFFF3BD4),
    accent: Color(0xFF29F3FF),
    accent2: Color(0xFFFF3BD4),
    gold: Color(0xFFFFE45C),
    panel: Color(0xCC120626),
    panelBorder: Color(0x66FF3BD4),
    text: Color(0xFFF5F0FF),
    textDim: Color(0xB3D9CCFF),
    ship: ShipShape(
      wingSpan: 23,
      length: 50,
      sweep: 0.86,
      finLength: 0,
      bodyWidth: 7,
      curvedWings: false,
    ),
  );

  static const DriftPalette sunset = DriftPalette(
    skyTop: Color(0xFF1A0B2E),
    skyMid: Color(0xFF7A1F5C),
    skyBottom: Color(0xFFFF7A3D),
    sunTop: Color(0xFFFFF1A1),
    sunBottom: Color(0xFFFF5E3A),
    mountain: Color(0xFF3A0F35),
    mountainEdge: Color(0xFFFFA14F),
    floorGrid: Color(0xFFFF9E5E),
    roadTop: Color(0xFF1B0B22),
    roadBottom: Color(0xFF34112F),
    roadGrid: Color(0xFFB8436B),
    laneLine: Color(0xFFFFC46B),
    edgeGlow: Color(0xFFFF7A3D),
    star: Color(0xFFFFE6CC),
    gateCore: Color(0xFFFF3B5C),
    gateHot: Color(0xFFFFD6C2),
    gateGlow: Color(0xFFFF5E3A),
    spark: Color(0xFFFFE66D),
    sparkGlow: Color(0xFFFFC46B),
    shipBody: Color(0xFFFFF3E3),
    shipShade: Color(0xFFD9937A),
    shipCockpit: Color(0xFF4A1238),
    shipAccent: Color(0xFFFF9E5E),
    trailStart: Color(0xFFFFD166),
    trailEnd: Color(0xFFFF3B5C),
    accent: Color(0xFFFFB347),
    accent2: Color(0xFFFF4F7B),
    gold: Color(0xFFFFE66D),
    panel: Color(0xCC24091F),
    panelBorder: Color(0x66FFA14F),
    text: Color(0xFFFFF4EA),
    textDim: Color(0xB3FFD9C2),
    ship: ShipShape(
      wingSpan: 26,
      length: 46,
      sweep: 0.7,
      finLength: 12,
      bodyWidth: 8,
      curvedWings: false,
    ),
  );

  static const DriftPalette aurora = DriftPalette(
    skyTop: Color(0xFF010B14),
    skyMid: Color(0xFF04343C),
    skyBottom: Color(0xFF13705E),
    sunTop: Color(0xFFE8FFF8),
    sunBottom: Color(0xFF3DDC97),
    mountain: Color(0xFF032128),
    mountainEdge: Color(0xFF7CFFCB),
    floorGrid: Color(0xFF3DDC97),
    roadTop: Color(0xFF020E16),
    roadBottom: Color(0xFF05262E),
    roadGrid: Color(0xFF1C8A7A),
    laneLine: Color(0xFF7CFFCB),
    edgeGlow: Color(0xFFB967FF),
    star: Color(0xFFDDFFF4),
    gateCore: Color(0xFFB967FF),
    gateHot: Color(0xFFF0DCFF),
    gateGlow: Color(0xFFB967FF),
    spark: Color(0xFFE3FF73),
    sparkGlow: Color(0xFFB8FF5C),
    shipBody: Color(0xFFE6FFF7),
    shipShade: Color(0xFF7FBFB0),
    shipCockpit: Color(0xFF0B3540),
    shipAccent: Color(0xFF3DDC97),
    trailStart: Color(0xFF7CFFCB),
    trailEnd: Color(0xFFB967FF),
    accent: Color(0xFF5CFFC0),
    accent2: Color(0xFFB967FF),
    gold: Color(0xFFE3FF73),
    panel: Color(0xCC03161C),
    panelBorder: Color(0x667CFFCB),
    text: Color(0xFFF0FFFA),
    textDim: Color(0xB3BFEDE0),
    ship: ShipShape(
      wingSpan: 25,
      length: 48,
      sweep: 0.95,
      finLength: 0,
      bodyWidth: 6,
      curvedWings: true,
    ),
  );

  static const DriftPalette voidline = DriftPalette(
    skyTop: Color(0xFF000000),
    skyMid: Color(0xFF06060E),
    skyBottom: Color(0xFF1A0F38),
    sunTop: Color(0xFFFFFFFF),
    sunBottom: Color(0xFF6F5BFF),
    mountain: Color(0xFF05040C),
    mountainEdge: Color(0xFF8C7BFF),
    floorGrid: Color(0xFF5B49FF),
    roadTop: Color(0xFF010104),
    roadBottom: Color(0xFF0A0820),
    roadGrid: Color(0xFF2E2680),
    laneLine: Color(0xFF9D8CFF),
    edgeGlow: Color(0xFFFF2E63),
    star: Color(0xFFFFFFFF),
    gateCore: Color(0xFFFF2E63),
    gateHot: Color(0xFFFFD0DC),
    gateGlow: Color(0xFFFF2E63),
    spark: Color(0xFFFFFFFF),
    sparkGlow: Color(0xFF9D8CFF),
    shipBody: Color(0xFF262438),
    shipShade: Color(0xFF12111E),
    shipCockpit: Color(0xFFFF2E63),
    shipAccent: Color(0xFF9D8CFF),
    trailStart: Color(0xFF9D8CFF),
    trailEnd: Color(0xFFFF2E63),
    accent: Color(0xFF9D8CFF),
    accent2: Color(0xFFFF2E63),
    gold: Color(0xFFFFE45C),
    panel: Color(0xCC07061A),
    panelBorder: Color(0x669D8CFF),
    text: Color(0xFFF4F2FF),
    textDim: Color(0xB3C9C2FF),
    ship: ShipShape(
      wingSpan: 24,
      length: 54,
      sweep: 1.0,
      finLength: 8,
      bodyWidth: 5,
      curvedWings: false,
    ),
  );
}
