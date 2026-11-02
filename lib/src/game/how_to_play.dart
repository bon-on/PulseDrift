import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../art/drift_palette.dart';
import 'ui/hud_widgets.dart';

/// Remembers whether the first-run tutorial has been seen.
abstract class TutorialStore {
  Future<bool> isSeen();

  Future<void> markSeen();
}

/// `shared_preferences` store. Storage failures are swallowed so play never
/// depends on local storage: a read failure shows the tutorial, a write
/// failure just closes it.
class SharedPrefsTutorialStore implements TutorialStore {
  const SharedPrefsTutorialStore();

  static const String key = 'tutorial_seen_v1';

  @override
  Future<bool> isSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {
      // The tutorial is a convenience; ignore storage errors.
    }
  }
}

class HowToPlayStep {
  const HowToPlayStep(this.icon, this.text);

  final IconData icon;
  final String text;
}

const List<HowToPlayStep> howToPlaySteps = [
  HowToPlayStep(
    Icons.swap_horiz,
    'Switch between the three lanes to slip through each gate gap. Hitting a wall ends the run.',
  ),
  HowToPlayStep(
    Icons.touch_app,
    'Drag, or tap the left/right half to shift a lane. On a keyboard use Left/Right or A/D.',
  ),
  HowToPlayStep(
    Icons.bolt,
    'Grab sparks for +25, but plan the next gate. A late switch into the gap earns a near-miss bonus.',
  ),
];

/// Full-screen scrim with a "How to play" card. Blocks all input underneath.
class HowToPlayOverlay extends StatefulWidget {
  const HowToPlayOverlay({
    super.key,
    required this.onClose,
    this.steps = howToPlaySteps,
    this.palette = DriftPalette.neon,
  });

  final VoidCallback onClose;
  final List<HowToPlayStep> steps;
  final DriftPalette palette;

  @override
  State<HowToPlayOverlay> createState() => _HowToPlayOverlayState();
}

class _HowToPlayOverlayState extends State<HowToPlayOverlay> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'how-to-play');
  int _step = 0;

  bool get _last => _step == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    // Take keyboard focus from the game (or a tapped button) so keys stop here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      widget.onClose();
    } else {
      setState(() => _step++);
    }
  }

  void _previous() {
    if (_step > 0) setState(() => _step--);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    // Browser/OS shortcuts (Tab, F5, Ctrl/Cmd/Alt combos) stay with the host.
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
        _next();
      } else if (key == LogicalKeyboardKey.escape) {
        widget.onClose();
      } else if (key == LogicalKeyboardKey.arrowRight) {
        if (!_last) _next();
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _previous();
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_step];
    final p = widget.palette;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          onPanStart: (_) {},
          child: ColoredBox(
            color: const Color(0xCC000000),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Material(
                    type: MaterialType.transparency,
                    child: NeonPanel(
                      palette: p,
                      glow: 0.5,
                      solid: true,
                      padding: EdgeInsets.zero,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'How to play',
                              style: TextStyle(
                                color: p.text,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: p.accent, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: p.accent.withValues(alpha: 0.45),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: Icon(step.icon, size: 40, color: p.accent),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              step.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: p.text.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < widget.steps.length; i++)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: i == _step ? 20 : 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: i == _step
                                          ? p.accent
                                          : Colors.white.withValues(
                                              alpha: 0.25,
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: widget.onClose,
                                  child: Text(
                                    'Skip',
                                    style: TextStyle(color: p.textDim),
                                  ),
                                ),
                                NeonButton(
                                  label: _last ? 'Play' : 'Next',
                                  onPressed: _next,
                                  palette: p,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
