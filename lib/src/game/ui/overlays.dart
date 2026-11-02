import 'package:flutter/material.dart';

import '../../art/drift_palette.dart';
import '../../meta/drift_progress.dart';
import '../../meta/drift_theme.dart';
import '../../meta/missions.dart';
import 'hud_widgets.dart';

String formatSeconds(double seconds) {
  final s = seconds.isFinite && seconds > 0 ? seconds : 0.0;
  if (s < 60) return '${s.toStringAsFixed(1)}s';
  final m = s ~/ 60;
  final rest = (s - m * 60).floor().toString().padLeft(2, '0');
  return '$m:$rest';
}

/// Title card shown before a run; taps fall through to the playfield.
class ReadyCard extends StatelessWidget {
  const ReadyCard({super.key, required this.palette, required this.bestScore});

  final DriftPalette palette;
  final int bestScore;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: NeonPanel(
        palette: palette,
        glow: 0.5,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DriftLogo(palette: palette, size: 34),
            const SizedBox(height: 4),
            Text(
              'Dodge the pulse gates. Drift late for bonus.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textDim, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.accent, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Text(
                'Tap / press Space to start',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Arrows / A D / drag to switch lanes',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textDim, fontSize: 12),
            ),
            if (bestScore > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Best $bestScore',
                style: TextStyle(
                  color: palette.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Everything the run summary shows.
class RunReport {
  const RunReport({
    required this.score,
    required this.bestScore,
    required this.isNewBest,
    required this.seconds,
    required this.nearMisses,
    required this.peakMultiplier,
    required this.sparks,
    required this.missions,
    required this.missionsDone,
    required this.outcome,
    required this.progressBefore,
  });

  final int score;
  final int bestScore;
  final bool isNewBest;
  final double seconds;
  final int nearMisses;
  final double peakMultiplier;
  final int sparks;
  final List<Mission> missions;
  final List<bool> missionsDone;
  final RunOutcome outcome;
  final DriftProgress progressBefore;
}

/// Game-over summary. Blocks input underneath; Enter/Space play again, Esc
/// returns to the ready card.
class RunSummaryOverlay extends StatefulWidget {
  const RunSummaryOverlay({
    super.key,
    required this.report,
    required this.palette,
    required this.onPlayAgain,
    required this.onMenu,
  });

  final RunReport report;
  final DriftPalette palette;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  @override
  State<RunSummaryOverlay> createState() => _RunSummaryOverlayState();
}

class _RunSummaryOverlayState extends State<RunSummaryOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'run-summary');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final p = widget.palette;
    final outcome = r.outcome;
    final after = outcome.progress;
    final before = r.progressBefore;
    final fracBefore = outcome.leveledUp
        ? 0.0
        : before.xpIntoLevel / before.xpForNextLevel;
    final fracAfter = after.xpIntoLevel / after.xpForNextLevel;
    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) => overlayKeyHandler(
        event,
        onEnter: widget.onPlayAgain,
        onEscape: widget.onMenu,
      ),
      child: _Scrim(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: NeonPanel(
            palette: p,
            glow: 0.6,
            solid: true,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r.isNewBest ? 'NEW BEST!' : 'RUN OVER',
                  style: TextStyle(
                    color: r.isNewBest ? p.gold : p.accent2,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color: r.isNewBest ? p.gold : p.accent2,
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${r.score}',
                    style: TextStyle(
                      color: p.text,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      shadows: [Shadow(color: p.accent, blurRadius: 20)],
                    ),
                  ),
                ),
                Text(
                  'Best ${r.bestScore}',
                  style: TextStyle(
                    color: p.textDim,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: outcome.isNewBestTime ? 'Time (best!)' : 'Time',
                        value: formatSeconds(r.seconds),
                        palette: p,
                        emphasis: outcome.isNewBestTime ? p.gold : null,
                        valueSize: 18,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Close calls',
                        value: '${r.nearMisses}',
                        palette: p,
                        valueSize: 18,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Top x',
                        value: 'x${r.peakMultiplier.toStringAsFixed(1)}',
                        palette: p,
                        valueSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: HudLabel('Missions', palette: p),
                ),
                const SizedBox(height: 6),
                MissionList(
                  palette: p,
                  missions: r.missions,
                  progress: [
                    for (var i = 0; i < r.missions.length; i++)
                      r.missionsDone[i] ? r.missions[i].target : 0,
                  ],
                  done: r.missionsDone,
                  compact: true,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'PILOT LV ${after.level}',
                      style: TextStyle(
                        color: p.text,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '+${outcome.xpGained} XP',
                      style: TextStyle(
                        color: p.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LevelBar(palette: p, from: fracBefore, to: fracAfter),
                if (outcome.leveledUp) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Level up!',
                    style: TextStyle(
                      color: p.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: p.gold, blurRadius: 10)],
                    ),
                  ),
                  for (final theme in outcome.newlyUnlockedThemes)
                    Text(
                      '${theme.label} theme + ${theme.shipName} ship unlocked',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    NeonButton(
                      label: 'Play again',
                      icon: Icons.replay_rounded,
                      onPressed: widget.onPlayAgain,
                      palette: p,
                    ),
                    NeonButton(
                      label: 'Menu',
                      onPressed: widget.onMenu,
                      palette: p,
                      primary: false,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter / Space to play again, Esc for menu',
                  style: TextStyle(color: p.textDim, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Theme and ship picker. Locked themes show their required level.
class ThemePickerOverlay extends StatefulWidget {
  const ThemePickerOverlay({
    super.key,
    required this.progress,
    required this.palette,
    required this.onSelect,
    required this.onClose,
  });

  final DriftProgress progress;
  final DriftPalette palette;
  final ValueChanged<DriftTheme> onSelect;
  final VoidCallback onClose;

  @override
  State<ThemePickerOverlay> createState() => _ThemePickerOverlayState();
}

class _ThemePickerOverlayState extends State<ThemePickerOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'theme-picker');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final progress = widget.progress;
    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) => overlayKeyHandler(
        event,
        onEnter: widget.onClose,
        onEscape: widget.onClose,
      ),
      child: _Scrim(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: NeonPanel(
            palette: p,
            glow: 0.5,
            solid: true,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Themes',
                  style: TextStyle(
                    color: p.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Level up your pilot to unlock roads and ships.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textDim, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = (c.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final theme in DriftTheme.values)
                          SizedBox(
                            width: w,
                            child: _ThemeCard(
                              theme: theme,
                              selected: progress.selectedTheme == theme,
                              unlocked: progress.isThemeUnlocked(theme),
                              palette: p,
                              onTap: () => widget.onSelect(theme),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                NeonButton(
                  label: 'Done',
                  onPressed: widget.onClose,
                  palette: p,
                  primary: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.unlocked,
    required this.palette,
    required this.onTap,
  });

  final DriftTheme theme;
  final bool selected;
  final bool unlocked;
  final DriftPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final own = DriftPalette.of(theme);
    return Semantics(
      button: true,
      selected: selected,
      enabled: unlocked,
      label: '${theme.label} theme',
      child: InkWell(
        onTap: unlocked ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? own.accent : palette.panelBorder,
              width: selected ? 2.4 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: own.accent.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1.7,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ThemePreview(theme: theme, locked: !unlocked),
                    if (!unlocked)
                      Center(
                        child: Icon(Icons.lock_rounded, color: palette.text),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                theme.label,
                style: TextStyle(
                  color: unlocked ? palette.text : palette.textDim,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                unlocked
                    ? (selected ? 'Selected' : theme.shipName)
                    : 'Lv ${theme.requiredLevel}',
                style: TextStyle(
                  color: selected ? own.accent : palette.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark scrim that swallows taps and drags and centres a scrollable card.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onPanStart: (_) {},
      child: ColoredBox(
        color: const Color(0xB3000000),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
