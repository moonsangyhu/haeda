import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/challenge_room_scene.dart' show ChallengeRoomColors;
import '../../../core/widgets/tappable_character.dart';
import '../../character/models/character_data.dart';
import 'speech_bubble.dart';

/// A character widget rendered inside [ChallengeRoomScene].
///
/// Verified characters bounce gently and show a green check badge.
/// Unverified characters are desaturated, tilted, and show floating "Zzz".
/// The creator gets a crown label; self gets a larger scale.
class RoomCharacter extends StatefulWidget {
  final CharacterData? character;
  final double size;
  final bool isVerified;
  final bool isSelf;
  final bool isCreator;
  final String nickname;
  final bool celebrationJump;
  final VoidCallback? onTap;
  final String? speechText;
  final double bubbleOpacity;
  final double bubbleScale;

  const RoomCharacter({
    super.key,
    this.character,
    required this.size,
    required this.isVerified,
    required this.isSelf,
    required this.isCreator,
    required this.nickname,
    this.celebrationJump = false,
    this.onTap,
    this.speechText,
    this.bubbleOpacity = 0.0,
    this.bubbleScale = 1.0,
  });

  @override
  State<RoomCharacter> createState() => _RoomCharacterState();
}

class _RoomCharacterState extends State<RoomCharacter>
    with TickerProviderStateMixin {
  // Verified: gentle bounce
  late final AnimationController _bounceController;
  // Unverified: floating Zzz
  late final AnimationController _zzzController;
  // Wave reaction (tap on verified other)
  late final AnimationController _waveController;
  // Celebration jump
  late final AnimationController _jumpController;

  bool _showBubble = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _zzzController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startAnimations();
  }

  void _startAnimations() {
    if (widget.isVerified) {
      _bounceController.repeat();
      _zzzController.stop();
      _zzzController.reset();
    } else {
      _zzzController.repeat();
      _bounceController.stop();
      _bounceController.reset();
    }
    if (widget.celebrationJump) {
      _jumpController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(RoomCharacter old) {
    super.didUpdateWidget(old);
    if (old.isVerified != widget.isVerified ||
        old.celebrationJump != widget.celebrationJump) {
      _startAnimations();
    }
    if (!old.celebrationJump && widget.celebrationJump) {
      _jumpController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _zzzController.dispose();
    _waveController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isSelf) return;
    if (widget.isVerified) {
      // Wave reaction
      _waveController.forward(from: 0);
      setState(() => _showBubble = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showBubble = false);
      });
    } else {
      widget.onTap?.call();
    }
  }

  bool get _hasSpeech =>
      widget.speechText != null && widget.bubbleOpacity > 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isSelf ? null : _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size * 1.2,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Speech bubble (above everything)
                if (_hasSpeech)
                  Positioned(
                    top: -widget.size * 0.45,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SpeechBubble(
                        text: widget.speechText!,
                        opacity: widget.bubbleOpacity,
                        scale: widget.bubbleScale,
                        semanticsNickname: widget.nickname,
                        maxWidth: widget.size * 3,
                      ),
                    ),
                  ),

                // Crown for creator
                if (widget.isCreator)
                  Positioned(
                    top: -4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        '👑',
                        style: TextStyle(fontSize: widget.size * 0.14),
                        semanticsLabel: '방장',
                      ),
                    ),
                  ),

                // Character body with animations
                _buildAnimatedCharacter(),

                // Wave bubble — suppressed when speech bubble is active
                if (_showBubble && !_hasSpeech)
                  Positioned(
                    top: -widget.size * 0.25,
                    right: -widget.size * 0.1,
                    child: _WaveBubble(size: widget.size * 0.3),
                  ),

                // Zzz for unverified
                if (!widget.isVerified) _buildZzzOverlay(),

                // Verified check badge
                if (widget.isVerified)
                  Positioned(
                    top: widget.isCreator ? widget.size * 0.08 : 0,
                    right: 0,
                    child: _VerifiedBadge(size: widget.size * 0.22),
                  ),
              ],
            ),
          ),

          // Nickname
          const SizedBox(height: 2),
          _buildNicknameLabel(context),
        ],
      ),
    );
  }

  Widget _buildAnimatedCharacter() {
    final avatar = widget.isVerified
        ? CharacterAvatar(character: widget.character, size: widget.size)
        : _DesaturatedAvatar(
            character: widget.character,
            size: widget.size,
          );

    final wrapped = widget.isSelf && widget.isVerified
        ? TappableCharacter(child: avatar)
        : avatar;

    // Celebration jump takes priority
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bounceController,
        _waveController,
        _jumpController,
      ]),
      builder: (context, child) {
        double dy = 0;
        double angle = 0;

        if (_jumpController.isAnimating || _jumpController.value > 0) {
          dy = -math.sin(math.pi * _jumpController.value) * 20;
        } else if (widget.isVerified && _bounceController.isAnimating) {
          dy = -math.sin(math.pi * _bounceController.value) * 3;
        }

        if (_waveController.isAnimating) {
          angle = math.sin(3 * math.pi * _waveController.value) *
              0.15 *
              (1 - _waveController.value);
        }

        Widget result = child!;
        if (dy != 0) result = Transform.translate(offset: Offset(0, dy), child: result);
        if (angle != 0) result = Transform.rotate(angle: angle, child: result);
        return result;
      },
      child: wrapped,
    );
  }

  Widget _buildZzzOverlay() {
    return Positioned(
      top: 0,
      right: -widget.size * 0.15,
      child: AnimatedBuilder(
        animation: _zzzController,
        builder: (context, _) {
          return Column(
            children: List.generate(3, (i) {
              final phase = (_zzzController.value + i * 0.33) % 1.0;
              final opacity = 0.3 + 0.7 * phase;
              final dy = -8.0 * phase;
              final fontSize = widget.size * 0.12 + i * 1.0;
              return Transform.translate(
                offset: Offset(0, dy),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Text(
                    'Z',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: ChallengeRoomColors.sleepyBlue,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildNicknameLabel(BuildContext context) {
    final theme = Theme.of(context);
    final prefix = widget.isCreator ? '👑 ' : '';
    return SizedBox(
      width: widget.size * 1.2,
      child: Text(
        '$prefix${widget.nickname}',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight:
              widget.isSelf ? FontWeight.w700 : FontWeight.normal,
          color: widget.isSelf
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ─── Desaturated Avatar ────────────────────────────────────────────────────

class _DesaturatedAvatar extends StatelessWidget {
  final CharacterData? character;
  final double size;

  const _DesaturatedAvatar({this.character, required this.size});

  static List<double> _desaturateMatrix(double saturation) {
    final s = saturation;
    final sr = 0.2126 * (1 - s);
    final sg = 0.7152 * (1 - s);
    final sb = 0.0722 * (1 - s);
    return <double>[
      sr + s, sg,     sb,     0, 0,
      sr,     sg + s, sb,     0, 0,
      sr,     sg,     sb + s, 0, 0,
      0,      0,      0,      1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.087, // ~5 degrees
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(_desaturateMatrix(0.6)),
        child: CharacterAvatar(character: character, size: size),
      ),
    );
  }
}

// ─── Verified Badge ────────────────────────────────────────────────────────

class _VerifiedBadge extends StatelessWidget {
  final double size;

  const _VerifiedBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: ChallengeRoomColors.verifiedGreen,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check,
        size: size * 0.65,
        color: Colors.white,
      ),
    );
  }
}

// ─── Wave Bubble ───────────────────────────────────────────────────────────

class _WaveBubble extends StatelessWidget {
  final double size;

  const _WaveBubble({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 2,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(size * 0.4),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '👋',
          style: TextStyle(fontSize: size * 0.65),
        ),
      ),
    );
  }
}
