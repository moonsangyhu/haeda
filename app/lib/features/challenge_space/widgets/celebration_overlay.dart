import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/challenge_room_scene.dart' show ChallengeRoomColors;

/// Momentary celebration overlay shown when all members verify on the same day.
///
/// Plays a one-shot 3-second sequence:
///   0–1s  : confetti particles rain down
///   0.5–2.5s: season icon pops in the center
///   0.5–3s : banner text fades in at the bottom
///
/// The animation only runs once per false→true transition of [trigger].
class CelebrationOverlay extends StatefulWidget {
  final bool trigger;
  final Size roomSize;

  const CelebrationOverlay({
    super.key,
    required this.trigger,
    required this.roomSize,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  bool _hasShown = false;

  // Sub-animations
  late final Animation<double> _confettiProgress; // 0→1 over 0–1s
  late final Animation<double> _iconScale;         // 0→1.5→1 over 0.5–2.5s
  late final Animation<double> _bannerOpacity;     // 0→1 over 0.5–3s

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _confettiProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.33, curve: Curves.linear),
      ),
    );

    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1.5)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 1.0),
        weight: 40,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.17, 0.83, curve: Curves.linear),
      ),
    );

    _bannerOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.17, 1.0, curve: Curves.easeIn),
      ),
    );

    if (widget.trigger) {
      _hasShown = true;
      _mainController.forward();
    }
  }

  @override
  void didUpdateWidget(CelebrationOverlay old) {
    super.didUpdateWidget(old);
    if (!old.trigger && widget.trigger && !_hasShown) {
      _hasShown = true;
      _mainController.forward(from: 0);
    }
    if (!widget.trigger) {
      _hasShown = false;
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  String _seasonIcon() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return '🌸';
    if (month >= 6 && month <= 8) return '🌿';
    if (month >= 9 && month <= 11) return '🍁';
    return '❄️';
  }

  @override
  Widget build(BuildContext context) {
    if (!_mainController.isAnimating && _mainController.value == 0) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) {
        return Stack(
          children: [
            // Confetti
            if (_confettiProgress.value > 0)
              CustomPaint(
                size: widget.roomSize,
                painter: _ConfettiPainter(
                  progress: _confettiProgress.value,
                ),
              ),

            // Season icon
            if (_iconScale.value > 0)
              Center(
                child: Transform.scale(
                  scale: _iconScale.value,
                  child: Text(
                    _seasonIcon(),
                    style: TextStyle(
                      fontSize: widget.roomSize.width * 0.15,
                    ),
                    semanticsLabel: '전원 인증 완료',
                  ),
                ),
              ),

            // Banner
            if (_bannerOpacity.value > 0)
              Positioned(
                bottom: widget.roomSize.height * 0.12,
                left: widget.roomSize.width * 0.1,
                right: widget.roomSize.width * 0.1,
                child: Opacity(
                  opacity: _bannerOpacity.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ChallengeRoomColors.partyGold.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      '오늘 전원 인증 완료!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Confetti Painter ──────────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final double progress;

  static const _colors = [
    ChallengeRoomColors.partyGold,
    ChallengeRoomColors.partyPink,
    ChallengeRoomColors.verifiedGreen,
    ChallengeRoomColors.sleepyBlue,
    ChallengeRoomColors.sparkle,
  ];

  static final _rng = math.Random(42);
  static final List<_Particle> _particles = List.generate(
    20,
    (i) => _Particle(
      xStart: _rng.nextDouble(),
      xDrift: (_rng.nextDouble() - 0.5) * 0.3,
      speed: 0.4 + _rng.nextDouble() * 0.6,
      size: 4 + _rng.nextDouble() * 4,
      colorIdx: i % _colors.length,
    ),
  );

  const _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final t = (progress * p.speed).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final x = (p.xStart + p.xDrift * t) * size.width;
      // Gravity: y accelerates
      final y = t * t * size.height * 0.9;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      paint.color = _colors[p.colorIdx].withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Particle {
  final double xStart;
  final double xDrift;
  final double speed;
  final double size;
  final int colorIdx;

  const _Particle({
    required this.xStart,
    required this.xDrift,
    required this.speed,
    required this.size,
    required this.colorIdx,
  });
}
