import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../art/drift_palette.dart';
import '../../art/scenery.dart';
import '../../art/ship_art.dart';
import '../../meta/drift_theme.dart';
import '../../meta/missions.dart';

/// Glassy neon card used by every panel and overlay.
class NeonPanel extends StatelessWidget {
  const NeonPanel({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.glow = 0.25,
    this.borderColor,
    this.solid = false,
  });

  final DriftPalette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double glow;
  final Color? borderColor;

  /// Opaque fill for overlay cards, so nothing behind shows through.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? palette.panelBorder;
    final fill = solid ? palette.panel.withValues(alpha: 1) : palette.panel;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(fill, palette.accent2, 0.06)!, fill],
        ),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: glow),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small caps label above a value.
class HudLabel extends StatelessWidget {
  const HudLabel(this.text, {super.key, required this.palette});

  final String text;
  final DriftPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.textDim,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

/// Neon title logo.
class DriftLogo extends StatelessWidget {
  const DriftLogo({super.key, required this.palette, this.size = 30});

  final DriftPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: ShaderMask(
        shaderCallback: (rect) => LinearGradient(
          colors: [palette.accent, palette.accent2],
        ).createShader(rect),
        child: Text(
          'PULSE DRIFT',
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 2,
            shadows: [Shadow(color: palette.accent2, blurRadius: 18)],
          ),
        ),
      ),
    );
  }
}

/// Label plus a bold value; [emphasis] colours the value.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.palette,
    this.emphasis,
    this.valueSize = 22,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final DriftPalette palette;
  final Color? emphasis;
  final double valueSize;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        HudLabel(label, palette: palette),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: emphasis ?? palette.text,
              fontSize: valueSize,
              fontWeight: FontWeight.w900,
              height: 1.15,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: emphasis == null
                  ? null
                  : [Shadow(color: emphasis!, blurRadius: 10)],
            ),
          ),
        ),
      ],
    );
  }
}

/// XP bar: [from] animates to [to] (both 0..1) when they differ.
class LevelBar extends StatelessWidget {
  const LevelBar({
    super.key,
    required this.palette,
    required this.to,
    this.from,
    this.height = 10,
  });

  final DriftPalette palette;
  final double to;
  final double? from;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from ?? to, end: to),
      duration: from == null || from == to
          ? Duration.zero
          : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(height),
          border: Border.all(color: palette.panelBorder),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(
                colors: [palette.accent, palette.accent2],
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mission rows with a tick or a progress bar each.
class MissionList extends StatelessWidget {
  const MissionList({
    super.key,
    required this.palette,
    required this.missions,
    required this.progress,
    required this.done,
    this.compact = false,
  });

  final DriftPalette palette;
  final List<Mission> missions;
  final List<int> progress;
  final List<bool> done;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < missions.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : (compact ? 4 : 10)),
            child: _MissionRow(
              palette: palette,
              mission: missions[i],
              progress: i < progress.length ? progress[i] : 0,
              done: i < done.length && done[i],
              compact: compact,
            ),
          ),
      ],
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.palette,
    required this.mission,
    required this.progress,
    required this.done,
    required this.compact,
  });

  final DriftPalette palette;
  final Mission mission;
  final int progress;
  final bool done;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = done ? palette.gold : palette.text;
    final icon = Container(
      width: compact ? 16 : 20,
      height: compact ? 16 : 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? palette.gold : Colors.transparent,
        border: Border.all(
          color: done ? palette.gold : palette.textDim,
          width: 1.6,
        ),
        boxShadow: done
            ? [
                BoxShadow(
                  color: palette.gold.withValues(alpha: 0.7),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: done
          ? Icon(Icons.check, size: compact ? 12 : 14, color: Colors.black)
          : null,
    );
    final label = Text(
      mission.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: compact ? 12.5 : 14,
        fontWeight: FontWeight.w700,
        decoration: done ? TextDecoration.lineThrough : null,
        decorationColor: palette.gold,
      ),
    );
    final reward = Text(
      done
          ? '+${mission.xp} XP'
          : '${mission.kind == MissionKind.multiplier ? (progress / 10).toStringAsFixed(1) : progress}/${mission.kind == MissionKind.multiplier ? (mission.target / 10).toStringAsFixed(1) : mission.target}',
      style: TextStyle(
        color: done ? palette.gold : palette.textDim,
        fontSize: compact ? 11.5 : 12,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (compact) {
      return Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(child: label),
          const SizedBox(width: 6),
          reward,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 6),
                  reward,
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: mission.target == 0 ? 1 : progress / mission.target,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(
                    done ? palette.gold : palette.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Neon pill button; [primary] fills it with the accent gradient.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.palette,
    this.primary = true,
    this.icon,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DriftPalette palette;
  final bool primary;
  final IconData? icon;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStatePropertyAll(
        primary ? const Color(0xFF0A0418) : palette.text,
      ),
      overlayColor: WidgetStatePropertyAll(
        Colors.white.withValues(alpha: 0.12),
      ),
      side: primary
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? palette.accent
                    : palette.panelBorder,
                width: 1.4,
              ),
            ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Text(label),
      ],
    );
    final button = TextButton(
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      style: style,
      child: child,
    );
    if (!primary) return button;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(colors: [palette.accent, palette.accent2]),
        boxShadow: [
          BoxShadow(
            color: palette.accent2.withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: -2,
          ),
        ],
      ),
      child: button,
    );
  }
}

/// Round icon button with a tooltip (help, sound, themes).
class HudIconButton extends StatelessWidget {
  const HudIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.palette,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final DriftPalette palette;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: palette.panel,
        foregroundColor: palette.text,
        side: BorderSide(color: palette.panelBorder),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

/// Mini road-and-ship preview for a theme card.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.theme, this.locked = false});

  final DriftTheme theme;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ThemePreviewPainter(theme, locked));
  }
}

class _ThemePreviewPainter extends CustomPainter {
  _ThemePreviewPainter(this.theme, this.locked);

  final DriftTheme theme;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final p = DriftPalette.of(theme);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
    );
    paintBackdrop(canvas, size, p);
    final scale = (size.height / 90).clamp(0.4, 1.4);
    paintShip(
      canvas,
      Offset(size.width / 2, size.height * 0.78),
      p,
      scale: scale,
      glow: 0.8,
    );
    if (locked) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThemePreviewPainter old) =>
      old.theme != theme || old.locked != locked;
}

/// Shared overlay key handling: Enter/Space run [onEnter] (key repeats are
/// ignored so a held key never re-triggers), Esc runs [onEscape]. Host
/// shortcuts (Tab, F5, Ctrl/Meta/Alt combos) are left alone; everything else
/// stops here so it never reaches the game behind the overlay.
KeyEventResult overlayKeyHandler(
  KeyEvent event, {
  VoidCallback? onEnter,
  VoidCallback? onEscape,
}) {
  final key = event.logicalKey;
  final keyboard = HardwareKeyboard.instance;
  if (key == LogicalKeyboardKey.tab ||
      key == LogicalKeyboardKey.f5 ||
      keyboard.isControlPressed ||
      keyboard.isMetaPressed ||
      keyboard.isAltPressed) {
    return KeyEventResult.ignored;
  }
  if (event is KeyDownEvent) {
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      onEnter?.call();
    } else if (key == LogicalKeyboardKey.escape) {
      onEscape?.call();
    }
  }
  return KeyEventResult.handled;
}
