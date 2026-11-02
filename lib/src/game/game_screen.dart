import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ads/ad_banner.dart';
import '../ads/ad_service.dart';
import '../art/drift_palette.dart';
import '../audio/sound_fx.dart';
import '../audio/sound_mute_store.dart';
import '../meta/drift_progress.dart';
import '../meta/drift_theme.dart';
import '../meta/missions.dart';
import '../meta/progress_store.dart';
import '../persistence/best_score_store.dart';
import '../platform/game_platform.dart';
import '../../result_registration.dart';
import 'game_balance.dart';
import 'game_controller.dart';
import 'game_input.dart';
import 'game_painter.dart';
import 'how_to_play.dart';
import 'ui/drift_fx.dart';
import 'ui/hud_widgets.dart';
import 'ui/overlays.dart';

/// Widest the play column grows on desktop; phones use the full width.
const double maxPlayColumnWidth = 480;

/// Seconds between the crash and the summary (the shatter plays meanwhile).
const double summaryDelaySeconds = 0.9;

/// Values the HUD shows during a run; rebuilt only when one changes.
class _HudValues {
  const _HudValues({
    required this.score,
    required this.best,
    required this.multiplierTenths,
    required this.seconds,
    required this.missionProgress,
    required this.missionDone,
  });

  final int score;
  final int best;
  final int multiplierTenths;
  final int seconds;
  final List<int> missionProgress;
  final List<bool> missionDone;

  String get key =>
      '$score|$best|$multiplierTenths|$seconds|$missionProgress|$missionDone';
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.enableAds = false,
    this.platform = const NoopGamePlatform(),
    this.tutorialStore = const SharedPrefsTutorialStore(),
    this.bestScoreStore,
    this.soundMuteStore = const SoundMuteStore(),
    this.progressStore = const ProgressStore(),
    this.random,
  });

  final bool enableAds;

  /// Portal hooks (CrazyGames SDK events, ad and leaderboard gates).
  final GamePlatform platform;
  final TutorialStore tutorialStore;

  /// Injectable for tests; defaults to `shared_preferences`.
  final BestScoreStore? bestScoreStore;

  /// Persisted user mute choice; tests inject a fake.
  final SoundMuteStore soundMuteStore;

  /// Pilot XP, best time and theme; tests inject a memory store.
  final ProgressStore progressStore;

  /// Gate and mission randomness; tests pass a seeded one.
  final math.Random? random;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final GameController _controller;
  late final SoundFx _sound;
  late final AppLifecycleListener _lifecycle;
  late final math.Random _random;
  final DriftFx _fx = DriftFx();
  Duration? _lastTick;
  bool _wasGameOver = false;
  int _completedRuns = 0;
  final FocusNode _gameFocus = FocusNode(debugLabel: 'game');
  bool _tutorialOpen = false;
  // True until the stored tutorial flag has been read: the run neither
  // simulates nor accepts input, so nothing happens before the overlay shows.
  bool _tutorialLoading = true;
  // Whether the platform currently believes gameplay is running.
  bool _gameplayActive = false;
  // False on the ready card: the first run waits for the player's first tap
  // or key press instead of starting the moment the page loads.
  bool _runStarted = false;
  bool _themesOpen = false;

  DriftProgress _progress = const DriftProgress.initial();
  bool _progressLoaded = false;
  // Runs that ended before the stored progress loaded; merged in on load.
  int _pendingXp = 0;
  int _pendingRuns = 0;
  double _pendingBestSeconds = 0;

  late MissionSet _missions;
  int _runBestBefore = 0;
  int _multiplierStep = 0;
  RunReport? _report;
  // Seconds left until the summary opens after a crash (null: none due).
  double? _summaryIn;
  bool _summaryOpen = false;
  late final ValueNotifier<_HudValues> _hud;

  bool get _adsEnabled => widget.enableAds && widget.platform.allowsAds;
  bool get _overlayOpen => _tutorialOpen || _themesOpen;
  DriftPalette get _palette => DriftPalette.of(_progress.selectedTheme);

  /// The simulation advances only while a started run is visible.
  bool get _simulating =>
      _runStarted && !_tutorialLoading && !_overlayOpen && !_summaryOpen;

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? math.Random();
    _sound = SoundFx(
      isPlatformMuted: () => widget.platform.isAudioMuted,
      store: widget.soundMuteStore,
    );
    widget.platform.addAudioMuteListener(_sound.refreshMute);
    // Hidden tab or backgrounded app: pause the loop (web reports
    // visibilitychange as hidden/resumed).
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => _sound.setAppVisible(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      ),
    );
    _controller = GameController(
      bestScoreStore: widget.bestScoreStore ?? SharedPrefsBestScoreStore(),
      random: widget.random,
      onGateDodged: _onGateDodged,
      onCrash: _onCrash,
      onRestarted: _sound.startBackgroundLoop,
      onNearMiss: _onNearMiss,
      onSparkCollected: _onSpark,
    )..addListener(_handleGameOverAds);
    _missions = MissionSet.forLevel(1, _random);
    _hud = ValueNotifier<_HudValues>(_hudValues());
    unawaited(_initializeController());
    unawaited(_loadSoundMuted());
    unawaited(_loadProgress());
    _sound.startBackgroundLoop();
    _ticker = createTicker(_onTick)..start();
    unawaited(_maybeShowTutorial());
  }

  Future<void> _initializeController() async {
    try {
      await _controller.initialize();
    } catch (_) {}
    if (!mounted) return;
    if (!_runStarted) _runBestBefore = _controller.bestScore;
    _refreshHud();
  }

  Future<void> _loadSoundMuted() async {
    try {
      await _sound.initialize();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  /// Reads the stored progress. Runs that ended meanwhile are merged in and
  /// only then saved, so an early save never overwrites the stored value.
  Future<void> _loadProgress() async {
    DriftProgress loaded;
    try {
      loaded = await widget.progressStore.load();
    } catch (_) {
      loaded = const DriftProgress.initial();
    }
    if (!mounted) return;
    final merged = _pendingRuns > 0
        ? loaded.withXp(
            _pendingXp,
            seconds: _pendingBestSeconds,
            runs: _pendingRuns,
          )
        : loaded;
    setState(() {
      _progress = merged;
      _progressLoaded = true;
      if (!_runStarted) {
        _missions = MissionSet.forLevel(_progress.level, _random);
      }
    });
    if (_pendingRuns > 0) unawaited(_saveProgress());
    _refreshHud();
  }

  Future<void> _saveProgress() async {
    try {
      await widget.progressStore.save(_progress);
    } catch (_) {}
  }

  void _toggleSound() {
    unawaited(_sound.setUserMuted(!_sound.userMuted).catchError((Object _) {}));
    setState(() {});
    _focusGameAfterFrame();
  }

  Future<void> _maybeShowTutorial() async {
    final seen = await widget.tutorialStore.isSeen();
    if (!mounted) return;
    setState(() => _tutorialLoading = false);
    if (seen) {
      _focusGameAfterFrame();
      _syncGameplay();
    } else {
      _openTutorial();
    }
  }

  /// Reports gameplay start/stop to the platform exactly on transitions:
  /// playing means a started run, no overlay and no crash.
  void _syncGameplay() {
    final wantActive =
        _runStarted &&
        !_tutorialLoading &&
        !_overlayOpen &&
        !_controller.isGameOver;
    if (wantActive == _gameplayActive) return;
    _gameplayActive = wantActive;
    if (wantActive) {
      widget.platform.gameplayStart();
    } else {
      widget.platform.gameplayStop();
    }
  }

  /// Leaves the ready card on the player's first input. Returns whether the
  /// run started now (false if it was already running or input is blocked).
  bool _startRun() {
    if (_runStarted || _tutorialLoading || _overlayOpen || _summaryOpen) {
      return false;
    }
    setState(() => _runStarted = true);
    _runBestBefore = _controller.bestScore;
    _multiplierStep = 0;
    // Drop the time spent on the ready card so the first step stays small.
    _lastTick = null;
    _syncGameplay();
    return true;
  }

  void _onPlayfieldTap(TapUpDetails details, Size size) {
    // The first tap only starts the run; later taps shift lanes.
    if (_startRun()) return;
    if (!_simulating) return;
    _controller.shiftLane(
      laneDeltaForTap(x: details.localPosition.dx, width: size.width),
    );
  }

  void _onPlayfieldDrag(double x) {
    _startRun();
    if (!_simulating) return;
    _controller.handlePointerX(x);
  }

  void _openTutorial() {
    if (_tutorialOpen) return;
    setState(() {
      _tutorialOpen = true;
      _themesOpen = false;
    });
    _syncGameplay();
  }

  void _closeTutorial() {
    if (!_tutorialOpen) return;
    _sound.onUserInput();
    unawaited(widget.tutorialStore.markSeen());
    setState(() => _tutorialOpen = false);
    _lastTick = null;
    _syncGameplay();
    _focusGameAfterFrame();
  }

  void _openThemes() {
    if (_themesOpen || _tutorialOpen) return;
    setState(() => _themesOpen = true);
    _syncGameplay();
  }

  void _closeThemes() {
    if (!_themesOpen) return;
    setState(() => _themesOpen = false);
    _lastTick = null;
    _syncGameplay();
    _focusGameAfterFrame();
  }

  void _selectTheme(DriftTheme theme) {
    // Picking before the stored progress loads could overwrite it.
    if (!_progressLoaded || !_progress.isThemeUnlocked(theme)) return;
    setState(() => _progress = _progress.withTheme(theme));
    unawaited(_saveProgress());
  }

  /// The game subtree is focusable again only after this frame rebuilds.
  void _focusGameAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_overlayOpen && !_tutorialLoading && !_summaryOpen) {
        _gameFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.removeListener(_handleGameOverAds);
    _ticker.dispose();
    _gameFocus.dispose();
    _controller.dispose();
    _sound.dispose();
    _fx.dispose();
    _hud.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Game events (rules already applied; these only add feedback)
  // ---------------------------------------------------------------------

  Offset get _shipPosition =>
      Offset(_controller.playerVisualX, _controller.playerY);

  void _onGateDodged() {
    _sound.play(Sfx.pulsePass);
    final gained = (GameBalance.baseScorePerGate * _controller.multiplier)
        .round();
    _fx.popup(
      '+$gained',
      _shipPosition.translate(0, -44),
      _palette.text.withValues(alpha: 0.85),
      size: 14,
    );
  }

  void _onNearMiss() {
    _sound.play(Sfx.nearMiss);
    _fx.popup(
      'Close! +${GameBalance.nearMissBonus.round()}',
      _shipPosition.translate(0, -62),
      _palette.gold,
      size: 19,
    );
    _fx.ring(_shipPosition, _palette.gold, maxRadius: 50);
  }

  void _onSpark(Offset at) {
    _sound.play(Sfx.spark);
    _fx.burst(at, _palette.spark, count: 18);
    _fx.popup(
      '+${GameBalance.sparkBonus}',
      at.translate(0, -26),
      _palette.spark,
    );
  }

  void _onCrash() {
    _sound.stopBackgroundLoop();
    _sound.play(Sfx.crash);
    _fx.crash(_shipPosition, [
      _palette.shipAccent,
      _palette.gateCore,
      _palette.shipBody,
    ]);
  }

  RunStats _stats() => RunStats(
    seconds: _controller.runSeconds,
    nearMisses: _controller.nearMisses,
    multiplier: _controller.multiplier,
    sparks: _controller.sparksCollected,
    gates: _controller.cleanDodges,
    score: _controller.score,
  );

  void _checkRunGoals() {
    for (final mission in _missions.update(_stats())) {
      _sound.play(Sfx.mission);
      _fx.banner('MISSION COMPLETE', _palette.gold, subtitle: mission.label);
    }
    final step = ((_controller.multiplier - 1) / 0.5 + 1e-6).floor();
    if (step > _multiplierStep) {
      _multiplierStep = step;
      _sound.play(Sfx.multiplier);
      _fx.banner(
        'x${_controller.multiplier.toStringAsFixed(1)}',
        _palette.accent2,
        subtitle: 'MULTIPLIER UP',
        big: true,
      );
      _fx.ring(_shipPosition, _palette.accent2, maxRadius: 90);
    }
  }

  /// Applies the finished run to progress and prepares the summary.
  void _finishRun() {
    _missions.update(_stats());
    final summary = RunSummary(
      score: _controller.score,
      seconds: _controller.runSeconds,
      missionXp: _missions.xpEarned,
    );
    final before = _progress;
    final outcome = before.applyRun(summary);
    _progress = outcome.progress;
    if (_progressLoaded) {
      unawaited(_saveProgress());
    } else {
      _pendingXp += outcome.xpGained;
      _pendingRuns += 1;
      _pendingBestSeconds = math.max(_pendingBestSeconds, summary.seconds);
    }
    _report = RunReport(
      score: _controller.score,
      bestScore: _controller.bestScore,
      isNewBest: _controller.score > 0 && _controller.score > _runBestBefore,
      seconds: _controller.runSeconds,
      nearMisses: _controller.nearMisses,
      peakMultiplier: _controller.multiplier,
      sparks: _controller.sparksCollected,
      missions: _missions.missions,
      missionsDone: [
        for (var i = 0; i < _missions.missions.length; i++) _missions.isDone(i),
      ],
      outcome: outcome,
      progressBefore: before,
    );
    _summaryIn = summaryDelaySeconds;
  }

  void _openSummary() {
    final report = _report;
    if (report == null) return;
    _summaryIn = null;
    setState(() => _summaryOpen = true);
    if (report.outcome.leveledUp) _sound.play(Sfx.levelUp);
    // A 0-point run has nothing worth submitting.
    if (report.score > 0 && widget.platform.allowsResultRegistration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          offerResultRegistration(
            context,
            gameId: 'pulse-drift',
            metric: 'score',
            value: report.score,
            displayValue: '${report.score}점',
          );
        }
      });
    }
  }

  void _newRun({required bool start}) {
    setState(() {
      _summaryOpen = false;
      _report = null;
      _summaryIn = null;
      _runStarted = start;
      _missions = MissionSet.forLevel(_progress.level, _random);
    });
    _fx.resetRun();
    _runBestBefore = _controller.bestScore;
    _multiplierStep = 0;
    _lastTick = null;
    _controller.restart();
    _syncGameplay();
    _refreshHud();
    _focusGameAfterFrame();
  }

  void _playAgain() => _newRun(start: true);

  void _backToMenu() => _newRun(start: false);

  void _handleGameOverAds() {
    _syncGameplay();
    if (!_adsEnabled) {
      _wasGameOver = _controller.isGameOver;
      return;
    }

    if (_controller.isGameOver && !_wasGameOver) {
      _completedRuns += 1;
      if (_completedRuns % 3 == 0) {
        // The music must not play over a full-screen ad.
        _sound.stopBackgroundLoop();
        final shown = AdService.instance.showInterstitialIfReady(
          onClosed: _resumeMusicAfterAd,
        );
        if (!shown) _resumeMusicAfterAd();
      } else {
        unawaited(AdService.instance.loadInterstitial());
      }
    }
    _wasGameOver = _controller.isGameOver;
  }

  /// After an ad the loop only comes back if a run is going again (a crash
  /// keeps it off until Play again).
  void _resumeMusicAfterAd() {
    if (!mounted || _controller.isGameOver) return;
    _sound.startBackgroundLoop();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    _sound.onUserInput();
    if (_tutorialLoading || _overlayOpen || _summaryOpen) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    // Browser/OS shortcuts (Tab, F5, Ctrl/Cmd/Alt combos) stay with the host.
    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.tab ||
        event.logicalKey == LogicalKeyboardKey.f5 ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    // While the ship shatters the summary is not up yet; swallow game keys
    // so a mashed key cannot skip it.
    if (_controller.isGameOver) {
      final gameKey =
          laneDeltaForKey(event.logicalKey) != null ||
          isRestartKey(event.logicalKey);
      return gameKey ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    final delta = laneDeltaForKey(event.logicalKey);
    if (delta != null) {
      // A lane key on the ready card starts the run and moves at once.
      _startRun();
      _controller.shiftLane(delta);
      return KeyEventResult.handled;
    }
    if (!_runStarted) {
      if (event is! KeyRepeatEvent && isRestartKey(event.logicalKey)) {
        _startRun();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onTick(Duration elapsed) {
    final previousTick = _lastTick;
    _lastTick = elapsed;
    final dt = previousTick == null
        ? 0.0
        : (elapsed - previousTick).inMicroseconds /
              Duration.microsecondsPerSecond;

    // Overlays freeze the world (simulation and effects); the tick above is
    // still recorded so closing one does not produce a large time jump.
    if (_tutorialLoading || _overlayOpen) return;

    if (_simulating && dt > 0) {
      final wasOver = _controller.isGameOver;
      _controller.update(dt);
      if (!_controller.isGameOver) {
        _checkRunGoals();
      } else if (!wasOver && _report == null) {
        _finishRun();
      }
    }

    final running = _runStarted && !_controller.isGameOver;
    _fx.advance(
      dt,
      roadSpeed: running ? _controller.speed : (_runStarted ? 0 : 80),
      shipX: _controller.laneCenters.isEmpty ? null : _controller.playerVisualX,
    );
    final due = _summaryIn;
    if (due != null) {
      _summaryIn = due - dt;
      if (_summaryIn! <= 0) _openSummary();
    }
    _refreshHud();
  }

  _HudValues _hudValues() => _HudValues(
    score: _controller.score,
    best: _controller.bestScore,
    multiplierTenths: (_controller.multiplier * 10 + 1e-6).floor(),
    seconds: _controller.runSeconds.floor(),
    missionProgress: [
      for (final m in _missions.missions) m.progressFor(_stats()),
    ],
    missionDone: [
      for (var i = 0; i < _missions.missions.length; i++) _missions.isDone(i),
    ],
  );

  void _refreshHud() {
    final next = _hudValues();
    if (next.key != _hud.value.key) _hud.value = next;
  }

  // ---------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final report = _report;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: palette.skyTop,
      // Any pointer input unlocks web audio (the loop starts after it).
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _sound.onUserInput(),
        onPointerUp: (_) => _sound.onUserInput(),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: BackdropPainter(fx: _fx, palette: palette),
                ),
              ),
            ),
            Positioned.fill(
              // Ignore touches until the stored tutorial flag has been read.
              child: AbsorbPointer(
                absorbing: _tutorialLoading,
                // Keep Tab from moving focus behind an open overlay.
                child: ExcludeFocus(
                  excluding: _tutorialLoading || _overlayOpen || _summaryOpen,
                  child: Focus(
                    focusNode: _gameFocus,
                    autofocus: true,
                    onKeyEvent: _onKey,
                    child: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, c) => _isWide(c)
                            ? _buildWide(c, palette)
                            : _buildNarrow(palette),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_summaryOpen && report != null)
              Positioned.fill(
                child: RunSummaryOverlay(
                  report: report,
                  palette: palette,
                  onPlayAgain: _playAgain,
                  onMenu: _backToMenu,
                ),
              ),
            if (_themesOpen)
              Positioned.fill(
                child: ThemePickerOverlay(
                  progress: _progress,
                  palette: palette,
                  onSelect: _selectTheme,
                  onClose: _closeThemes,
                ),
              ),
            if (_tutorialOpen)
              Positioned.fill(
                child: HowToPlayOverlay(
                  onClose: _closeTutorial,
                  palette: palette,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Wide when there is clearly more width than height (desktop, 16:9
  /// iframes, landscape phones).
  static bool _isWide(BoxConstraints c) =>
      c.maxWidth >= 760 && c.maxWidth >= c.maxHeight * 1.15;

  Widget _iconButtons(DriftPalette palette) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HudIconButton(
          icon: Icons.palette_outlined,
          tooltip: 'Themes',
          onPressed: _openThemes,
          palette: palette,
        ),
        const SizedBox(width: 6),
        HudIconButton(
          icon: Icons.help_outline,
          tooltip: 'How to play',
          onPressed: _openTutorial,
          palette: palette,
        ),
        const SizedBox(width: 6),
        HudIconButton(
          icon: _sound.userMuted
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          tooltip: _sound.userMuted ? 'Sound off' : 'Sound on',
          onPressed: _toggleSound,
          palette: palette,
        ),
      ],
    );
  }

  Widget _playfield(DriftPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.edgeGlow.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: palette.edgeGlow.withValues(alpha: 0.35),
            blurRadius: 24,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _controller.setViewportSize(size);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _onPlayfieldTap(details, size),
              onPanStart: (details) =>
                  _onPlayfieldDrag(details.localPosition.dx),
              onPanUpdate: (details) =>
                  _onPlayfieldDrag(details.localPosition.dx),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: GamePainter(
                        controller: _controller,
                        fx: _fx,
                        palette: palette,
                        running: _runStarted,
                      ),
                    ),
                  ),
                  if (!_runStarted && !_tutorialLoading && !_overlayOpen)
                    IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ReadyCard(
                              palette: palette,
                              bestScore: _controller.bestScore,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _runStats(DriftPalette palette, {required bool wide}) {
    return ValueListenableBuilder<_HudValues>(
      valueListenable: _hud,
      builder: (context, v, _) {
        final mult = 'x${(v.multiplierTenths / 10).toStringAsFixed(1)}';
        final multColor = v.multiplierTenths >= 20 ? palette.accent2 : null;
        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatTile(
                label: 'Score',
                value: '${v.score}',
                palette: palette,
                valueSize: 40,
                emphasis: palette.accent,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Multiplier',
                      value: mult,
                      palette: palette,
                      emphasis: multColor,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'Time',
                      value: '${v.seconds}s',
                      palette: palette,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              flex: 4,
              child: StatTile(
                label: 'Score',
                value: '${v.score}',
                palette: palette,
                emphasis: palette.accent,
              ),
            ),
            Expanded(
              flex: 3,
              child: StatTile(
                label: 'Best',
                value: '${v.best}',
                palette: palette,
              ),
            ),
            Expanded(
              flex: 3,
              child: StatTile(
                label: 'Multi',
                value: mult,
                palette: palette,
                emphasis: multColor,
              ),
            ),
            Expanded(
              flex: 3,
              child: StatTile(
                label: 'Time',
                value: '${v.seconds}s',
                palette: palette,
                alignEnd: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _missionPanel(DriftPalette palette, {required bool compact}) {
    return ValueListenableBuilder<_HudValues>(
      valueListenable: _hud,
      builder: (context, v, _) => MissionList(
        palette: palette,
        missions: _missions.missions,
        progress: v.missionProgress,
        done: v.missionDone,
        compact: compact,
      ),
    );
  }

  Widget _pilotPanel(DriftPalette palette) {
    final p = _progress;
    return NeonPanel(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: HudLabel('Pilot level', palette: palette)),
              Text(
                'LV ${p.level}',
                style: TextStyle(
                  color: palette.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  shadows: [Shadow(color: palette.gold, blurRadius: 8)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LevelBar(palette: palette, to: p.xpIntoLevel / p.xpForNextLevel),
          const SizedBox(height: 6),
          Text(
            '${p.xpIntoLevel} / ${p.xpForNextLevel} XP',
            style: TextStyle(color: palette.textDim, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWide(BoxConstraints c, DriftPalette palette) {
    final side = ((c.maxWidth - maxPlayColumnWidth) / 2 - 28).clamp(
      200.0,
      320.0,
    );
    final left = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriftLogo(palette: palette, size: 34),
          Text(
            'Neon lane dodger',
            style: TextStyle(color: palette.textDim, fontSize: 13),
          ),
          const SizedBox(height: 18),
          _pilotPanel(palette),
          const SizedBox(height: 12),
          NeonPanel(
            palette: palette,
            child: ValueListenableBuilder<_HudValues>(
              valueListenable: _hud,
              builder: (context, v, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatTile(
                    label: 'Best score',
                    value: '${v.best}',
                    palette: palette,
                    emphasis: palette.gold,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'Best time',
                          value: formatSeconds(_progress.bestSeconds),
                          palette: palette,
                          valueSize: 18,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          label: 'Runs',
                          value: '${_progress.runs}',
                          palette: palette,
                          valueSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          NeonPanel(
            palette: palette,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 84,
                  child: ThemePreview(theme: _progress.selectedTheme),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_progress.selectedTheme.label} / '
                        '${_progress.selectedTheme.shipName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openThemes,
                      child: Text(
                        'Change',
                        style: TextStyle(color: palette.accent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final right = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerRight, child: _iconButtons(palette)),
          const SizedBox(height: 14),
          NeonPanel(palette: palette, child: _runStats(palette, wide: true)),
          const SizedBox(height: 12),
          NeonPanel(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HudLabel('Run missions', palette: palette),
                const SizedBox(height: 10),
                _missionPanel(palette, compact: false),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Left / Right or A / D to switch lanes.\n'
            'Switch late through a gap for a Close! bonus.',
            style: TextStyle(color: palette.textDim, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
    return Row(
      children: [
        SizedBox(width: side, child: left),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: maxPlayColumnWidth,
                      ),
                      child: _playfield(palette),
                    ),
                  ),
                ),
                AdBanner(enabled: _adsEnabled),
              ],
            ),
          ),
        ),
        SizedBox(width: side, child: right),
      ],
    );
  }

  Widget _buildNarrow(DriftPalette palette) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxPlayColumnWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: DriftLogo(palette: palette, size: 24)),
                  const SizedBox(width: 6),
                  Text(
                    'LV ${_progress.level}',
                    style: TextStyle(
                      color: palette.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _iconButtons(palette),
                ],
              ),
              const SizedBox(height: 8),
              NeonPanel(
                palette: palette,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: _runStats(palette, wide: false),
              ),
              const SizedBox(height: 6),
              NeonPanel(
                palette: palette,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: _missionPanel(palette, compact: true),
              ),
              const SizedBox(height: 8),
              Expanded(child: _playfield(palette)),
              AdBanner(enabled: _adsEnabled),
            ],
          ),
        ),
      ),
    );
  }
}
