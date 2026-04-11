import 'dart:math' as math;

import 'package:flutter/material.dart';

enum _Reaction { jump, wiggle, spin, squish, bounce, headBob }

/// Wraps any child with tap-triggered Transform animations.
///
/// On each tap a random reaction is picked (never repeating the last one).
/// While animating, further taps are ignored.
class TappableCharacter extends StatefulWidget {
  const TappableCharacter({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<TappableCharacter> createState() => _TappableCharacterState();
}

class _TappableCharacterState extends State<TappableCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  _Reaction? _current;
  _Reaction? _last;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _ctrl.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _ctrl.reset();
      setState(() => _current = null);
    }
  }

  void _onTap() {
    if (!widget.enabled || _ctrl.isAnimating) return;

    final values = _Reaction.values;
    final candidates = values.where((r) => r != _last).toList();
    final picked = candidates[math.Random().nextInt(candidates.length)];

    final duration = switch (picked) {
      _Reaction.jump => const Duration(milliseconds: 400),
      _Reaction.wiggle => const Duration(milliseconds: 500),
      _Reaction.spin => const Duration(milliseconds: 600),
      _Reaction.squish => const Duration(milliseconds: 400),
      _Reaction.bounce => const Duration(milliseconds: 500),
      _Reaction.headBob => const Duration(milliseconds: 500),
    };

    setState(() {
      _last = picked;
      _current = picked;
    });
    _ctrl.duration = duration;
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => _buildTransform(child!),
        child: widget.child,
      ),
    );
  }

  Widget _buildTransform(Widget child) {
    final t = _ctrl.value;

    switch (_current) {
      case _Reaction.jump:
        return Transform.translate(
          offset: Offset(0, -math.sin(math.pi * t) * 20),
          child: child,
        );

      case _Reaction.wiggle:
        final angle = math.sin(3 * math.pi * t) * 0.15 * (1 - t);
        return Transform.rotate(angle: angle, child: child);

      case _Reaction.spin:
        return Transform.rotate(angle: t * 2 * math.pi, child: child);

      case _Reaction.squish:
        final sx = 1 + 0.2 * math.sin(math.pi * t);
        final sy = 1 - 0.2 * math.sin(math.pi * t);
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()..scale(sx, sy),
          child: child,
        );

      case _Reaction.bounce:
        final dy = -math.sin(2 * math.pi * t).abs() * 15 * (1 - t);
        return Transform.translate(offset: Offset(0, dy), child: child);

      case _Reaction.headBob:
        final dx = math.sin(4 * math.pi * t) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);

      case null:
        return child;
    }
  }
}
