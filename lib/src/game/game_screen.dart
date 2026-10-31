import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ads/ad_banner.dart';
import '../ads/ad_service.dart';
import '../audio/sound_fx.dart';
import '../audio/sound_mute_store.dart';
import '../persistence/best_score_store.dart';
import '../platform/game_platform.dart';
import '../../result_registration.dart';
import 'game_controller.dart';
import 'game_input.dart';
import 'game_painter.dart';
import 'how_to_play.dart';

/// Widest the play column grows on desktop; phones use the full width.
const double maxPlayColumnWidth = 480;

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.enableAds = false,
    this.platform = const NoopGamePlatform(),
    this.tutorialStore = const SharedPrefsTutorialStore(),
    this.bestScoreStore,
    this.soundMuteStore = const SoundMuteStore(),
  });

  final bool enableAds;

  /// Portal hooks (CrazyGames SDK events, ad and leaderboard gates).
  final GamePlatform platform;
  final TutorialStore tutorialStore;

  /// Injectable for tests; defaults to `shared_preferences`.
  final BestScoreStore? bestScoreStore;

  /// Persisted user mute choice; tests inject a fake.
  final SoundMuteStore soundMuteStore;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final GameController _controller;
  late final SoundFx _sound;
  late final AppLifecycleListener _lifecycle;
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

  bool get _adsEnabled => widget.enableAds && widget.platform.allowsAds;

  @override
  void initState() {
    super.initState();
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
      onGateDodged: () => _sound.play(Sfx.pulsePass),
      onCrash: () {
        _sound.stopBackgroundLoop();
        _sound.play(Sfx.crash);
      },
      onRestarted: _sound.startBackgroundLoop,
    )..addListener(_handleGameOverAds);
    _controller.initialize();
    unawaited(_loadSoundMuted());
    _sound.startBackgroundLoop();
    _ticker = createTicker(_onTick)..start();
    unawaited(_maybeShowTutorial());
  }

  Future<void> _loadSoundMuted() async {
    try {
      await _sound.initialize();
    } catch (_) {}
    if (mounted) setState(() {});
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
  /// playing means no tutorial and a run that has not crashed.
  void _syncGameplay() {
    final wantActive =
        !_tutorialLoading && !_tutorialOpen && !_controller.isGameOver;
    if (wantActive == _gameplayActive) return;
    _gameplayActive = wantActive;
    if (wantActive) {
      widget.platform.gameplayStart();
    } else {
      widget.platform.gameplayStop();
    }
  }

  void _openTutorial() {
    if (_tutorialOpen) return;
    setState(() => _tutorialOpen = true);
    _syncGameplay();
  }

  void _closeTutorial() {
    if (!_tutorialOpen) return;
    _sound.onUserInput();
    unawaited(widget.tutorialStore.markSeen());
    setState(() => _tutorialOpen = false);
    _syncGameplay();
    _focusGameAfterFrame();
  }

  /// The game subtree is focusable again only after this frame rebuilds.
  void _focusGameAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tutorialOpen && !_tutorialLoading) {
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
    super.dispose();
  }

  void _handleGameOverAds() {
    _syncGameplay();
    if (_controller.isGameOver &&
        !_wasGameOver &&
        widget.platform.allowsResultRegistration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          offerResultRegistration(
            context,
            gameId: 'pulse-drift',
            metric: 'score',
            value: _controller.score,
            displayValue: '${_controller.score}점',
          );
        }
      });
    }
    if (!_adsEnabled) {
      _wasGameOver = _controller.isGameOver;
      return;
    }

    if (_controller.isGameOver && !_wasGameOver) {
      _completedRuns += 1;
      if (_completedRuns % 3 == 0) {
        AdService.instance.showInterstitialIfReady();
      } else {
        unawaited(AdService.instance.loadInterstitial());
      }
    }
    _wasGameOver = _controller.isGameOver;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    _sound.onUserInput();
    if (_tutorialLoading || _tutorialOpen) return KeyEventResult.ignored;
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
    final delta = laneDeltaForKey(event.logicalKey);
    if (delta != null) {
      _controller.shiftLane(delta);
      return KeyEventResult.handled;
    }
    // A held key must not restart the run right after a crash.
    if (_controller.isGameOver &&
        event is! KeyRepeatEvent &&
        isRestartKey(event.logicalKey)) {
      _controller.restart();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onTick(Duration elapsed) {
    final previousTick = _lastTick;
    _lastTick = elapsed;

    // No simulation while the tutorial is open; the tick above is still
    // recorded so closing it does not produce a large time jump.
    if (previousTick == null || _tutorialLoading || _tutorialOpen) {
      return;
    }

    final deltaSeconds =
        (elapsed - previousTick).inMicroseconds /
        Duration.microsecondsPerSecond;
    _controller.update(deltaSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      // Any pointer input unlocks web audio (the loop starts after it).
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _sound.onUserInput(),
        onPointerUp: (_) => _sound.onUserInput(),
        child: Stack(
          children: [
            Positioned.fill(
              // Ignore touches until the stored tutorial flag has been read.
              child: AbsorbPointer(
                absorbing: _tutorialLoading,
                // Keep Tab from moving focus behind the open overlay.
                child: ExcludeFocus(
                  excluding: _tutorialLoading || _tutorialOpen,
                  child: _buildGame(),
                ),
              ),
            ),
            if (_tutorialOpen)
              Positioned.fill(child: HowToPlayOverlay(onClose: _closeTutorial)),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Focus(
      focusNode: _gameFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF061019),
                  Color(0xFF0D2A31),
                  Color(0xFF130C1E),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: maxPlayColumnWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _Header(
                          controller: _controller,
                          onHelp: _openTutorial,
                          soundMuted: _sound.userMuted,
                          onToggleSound: _toggleSound,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              _controller.setViewportSize(size);

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (details) => _controller.shiftLane(
                                  laneDeltaForTap(
                                    x: details.localPosition.dx,
                                    width: size.width,
                                  ),
                                ),
                                onPanStart: (details) => _controller
                                    .handlePointerX(details.localPosition.dx),
                                onPanUpdate: (details) => _controller
                                    .handlePointerX(details.localPosition.dx),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CustomPaint(
                                      painter: GamePainter(
                                        controller: _controller,
                                      ),
                                    ),
                                    if (_controller.isGameOver)
                                      Center(
                                        child: _GameOverCard(
                                          controller: _controller,
                                          onRestart: _controller.restart,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        AdBanner(enabled: _adsEnabled),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onHelp,
    required this.soundMuted,
    required this.onToggleSound,
  });

  final GameController controller;
  final VoidCallback onHelp;
  final bool soundMuted;
  final VoidCallback onToggleSound;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pulse Drift',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onHelp,
                    tooltip: 'How to play',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.help_outline),
                  ),
                  IconButton(
                    onPressed: onToggleSound,
                    tooltip: soundMuted ? 'Sound off' : 'Sound on',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      soundMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Drag, tap left/right, or use arrow keys / A D. Grab sparks, but watch the next gate.',
                style: TextStyle(color: Color(0xCCFFFFFF), height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatBadge(label: 'Score', value: '${controller.score}'),
            const SizedBox(height: 8),
            _StatBadge(label: 'Best', value: '${controller.bestScore}'),
          ],
        ),
      ],
    );
  }
}

class _GameOverCard extends StatelessWidget {
  const _GameOverCard({required this.controller, required this.onRestart});

  final GameController controller;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xF0182129),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Run ended',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Move earlier, and weigh each spark against the next gate. Best score is saved automatically.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onRestart,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF7043),
              foregroundColor: Colors.white,
            ),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
