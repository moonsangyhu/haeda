import 'package:flutter/material.dart';
import '../../features/character/models/character_data.dart';

/// 캐릭터 아바타 위젯.
/// 실제 픽셀아트 에셋이 없으므로 캐릭터 슬롯 상태를 시각적으로 표현하는
/// 플레이스홀더 방식으로 렌더링.
class CharacterAvatar extends StatefulWidget {
  final CharacterData? character;
  final double size;
  final bool showEffect;

  const CharacterAvatar({
    super.key,
    this.character,
    this.size = 80,
    this.showEffect = false,
  });

  @override
  State<CharacterAvatar> createState() => _CharacterAvatarState();
}

class _CharacterAvatarState extends State<CharacterAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    if (widget.showEffect && _hasEpicItem()) {
      _shimmerController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CharacterAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldShimmer = widget.showEffect && _hasEpicItem();
    if (shouldShimmer && !_shimmerController.isAnimating) {
      _shimmerController.repeat(reverse: true);
    } else if (!shouldShimmer && _shimmerController.isAnimating) {
      _shimmerController.stop();
      _shimmerController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  bool _hasEpicItem() {
    final c = widget.character;
    if (c == null) return false;
    return [c.hat, c.top, c.bottom, c.shoes, c.accessory]
        .any((slot) => slot?.rarity == 'EPIC');
  }

  Color _rarityColor(String? rarity) {
    switch (rarity) {
      case 'RARE':
        return const Color(0xFF2196F3);
      case 'EPIC':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final character = widget.character;

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _shimmerController.isAnimating ? _shimmerAnimation.value : 1.0,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base character body
                _CharacterBase(size: size, character: character),
                // Hat indicator (top-center)
                if (character?.hat != null)
                  Positioned(
                    top: 0,
                    child: _SlotIndicator(
                      size: size * 0.22,
                      color: _rarityColor(character!.hat!.rarity),
                      shape: _IndicatorShape.hat,
                    ),
                  ),
                // Accessory (top-right)
                if (character?.accessory != null)
                  Positioned(
                    top: size * 0.08,
                    right: 0,
                    child: _SlotIndicator(
                      size: size * 0.18,
                      color: _rarityColor(character!.accessory!.rarity),
                      shape: _IndicatorShape.star,
                    ),
                  ),
                // Top (center left)
                if (character?.top != null)
                  Positioned(
                    left: 0,
                    top: size * 0.35,
                    child: _SlotIndicator(
                      size: size * 0.18,
                      color: _rarityColor(character!.top!.rarity),
                      shape: _IndicatorShape.circle,
                    ),
                  ),
                // Bottom (center right)
                if (character?.bottom != null)
                  Positioned(
                    right: 0,
                    top: size * 0.55,
                    child: _SlotIndicator(
                      size: size * 0.18,
                      color: _rarityColor(character!.bottom!.rarity),
                      shape: _IndicatorShape.circle,
                    ),
                  ),
                // Shoes (bottom)
                if (character?.shoes != null)
                  Positioned(
                    bottom: 0,
                    child: _SlotIndicator(
                      size: size * 0.22,
                      color: _rarityColor(character!.shoes!.rarity),
                      shape: _IndicatorShape.shoes,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CharacterBase extends StatelessWidget {
  final double size;
  final CharacterData? character;

  const _CharacterBase({required this.size, this.character});

  @override
  Widget build(BuildContext context) {
    final bodySize = size * 0.65;
    final faceSize = bodySize * 0.55;
    final eyeSize = faceSize * 0.12;

    return Container(
      width: bodySize,
      height: bodySize,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(bodySize * 0.28),
        border: Border.all(
          color: const Color(0xFFCE93D8),
          width: size > 80 ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A9C27B0),
            blurRadius: size * 0.1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: faceSize,
          height: faceSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Eyes
              Positioned(
                top: faceSize * 0.2,
                left: faceSize * 0.15,
                child: _Eye(size: eyeSize),
              ),
              Positioned(
                top: faceSize * 0.2,
                right: faceSize * 0.15,
                child: _Eye(size: eyeSize),
              ),
              // Blush
              Positioned(
                top: faceSize * 0.42,
                left: faceSize * 0.05,
                child: _Blush(size: eyeSize * 1.4),
              ),
              Positioned(
                top: faceSize * 0.42,
                right: faceSize * 0.05,
                child: _Blush(size: eyeSize * 1.4),
              ),
              // Smile
              Positioned(
                bottom: faceSize * 0.18,
                child: _Smile(width: faceSize * 0.5, height: faceSize * 0.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  final double size;
  const _Eye({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Blush extends StatelessWidget {
  final double size;
  const _Blush({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.5,
      decoration: BoxDecoration(
        color: const Color(0xFFF48FB1).withOpacity(0.5),
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}

class _Smile extends StatelessWidget {
  final double width;
  final double height;
  const _Smile({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SmilePainter(),
    );
  }
}

class _SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.6
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width / 2, size.height * 2.5, size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _IndicatorShape { hat, star, circle, shoes }

class _SlotIndicator extends StatelessWidget {
  final double size;
  final Color color;
  final _IndicatorShape shape;

  const _SlotIndicator({
    required this.size,
    required this.color,
    required this.shape,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        shape: shape == _IndicatorShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: shape != _IndicatorShape.circle
            ? BorderRadius.circular(size * 0.3)
            : null,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _emoji,
          style: TextStyle(fontSize: size * 0.55),
        ),
      ),
    );
  }

  String get _emoji {
    switch (shape) {
      case _IndicatorShape.hat:
        return '🎩';
      case _IndicatorShape.star:
        return '✨';
      case _IndicatorShape.shoes:
        return '👟';
      case _IndicatorShape.circle:
        return '👕';
    }
  }
}
