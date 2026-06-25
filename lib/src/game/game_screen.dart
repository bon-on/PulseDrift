import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ads/ad_banner.dart';
import '../ads/ad_service.dart';
import '../audio/audio_controller.dart';
import '../persistence/best_score_store.dart';
import 'game_controller.dart';
import 'game_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.enableAds = false});

  final bool enableAds;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final GameController _controller;
  late final AudioController _audioController;
  Duration? _lastTick;
  bool _wasGameOver = false;
  int _completedRuns = 0;

  @override
  void initState() {
    super.initState();
    _audioController = AudioController();
    _controller = GameController(
      bestScoreStore: SharedPrefsBestScoreStore(),
      onGateDodged: () => unawaited(_audioController.playPulsePass()),
      onCrash: () => unawaited(_audioController.stopBackgroundLoop()),
      onRestarted: () => unawaited(_audioController.startBackgroundLoop()),
    )..addListener(_handleGameOverAds);
    _controller.initialize();
    unawaited(_audioController.startBackgroundLoop());
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleGameOverAds);
    _ticker.dispose();
    _controller.dispose();
    unawaited(_audioController.dispose());
    super.dispose();
  }

  void _handleGameOverAds() {
    if (!widget.enableAds) {
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

  void _onTick(Duration elapsed) {
    final previousTick = _lastTick;
    _lastTick = elapsed;

    if (previousTick == null) {
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
      body: AnimatedBuilder(
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
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _Header(controller: _controller),
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
                            onTapDown: (details) => _controller.handlePointerX(
                              details.localPosition.dx,
                            ),
                            onPanStart: (details) => _controller.handlePointerX(
                              details.localPosition.dx,
                            ),
                            onPanUpdate: (details) => _controller
                                .handlePointerX(details.localPosition.dx),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(
                                  painter: GamePainter(controller: _controller),
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
                    AdBanner(enabled: widget.enableAds),
                  ],
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
  const _Header({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pulse Drift',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                'Drag across the lanes. Catch the line early and ride the gaps.',
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
            'Drag sooner across the lanes. Best score is saved automatically.',
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
