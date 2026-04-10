import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../features/character/models/character_data.dart';

/// Pixel-art character avatar rendered on a 16x16 grid via CustomPainter.
/// Equipment overlays are drawn on top of the base character.
/// EPIC items trigger an animated shimmer effect.
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
  late final Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _shimmerAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
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

  bool _hasRareItem() {
    final c = widget.character;
    if (c == null) return false;
    return [c.hat, c.top, c.bottom, c.shoes, c.accessory]
        .any((slot) => slot?.rarity == 'RARE');
  }

  @override
  Widget build(BuildContext context) {
    final isEpic = widget.showEffect && _hasEpicItem();
    final isRare = !isEpic && widget.showEffect && _hasRareItem();

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _PixelCharacterPainter(
              character: widget.character,
              shimmerValue: isEpic ? _sparkleAnimation.value : null,
            ),
          ),
        );
      },
    );
  }
}

/// Draws the pixel-art character on a 16x16 logical grid.
class _PixelCharacterPainter extends CustomPainter {
  final CharacterData? character;
  final double? shimmerValue; // null = no shimmer, 0.0-1.0 = animated

  const _PixelCharacterPainter({
    required this.character,
    this.shimmerValue,
  });

  // --- Color palette ---
  static const _skin = Color(0xFFFFCBA4);
  static const _hairBrown = Color(0xFF5D3A1A);
  static const _eyeColor = Color(0xFF2D1B00);
  static const _smileColor = Color(0xFF8B4513);
  static const _blush = Color(0xFFFFB3B3);
  static const _defaultShirt = Color(0xFFFFFFFF);
  static const _defaultPants = Color(0xFF5B88C4);
  static const _defaultShoes = Color(0xFF8B6914);
  static const _outlineColor = Color(0xFF3A2010);

  void _drawPixel(Canvas canvas, Paint paint, int x, int y, double px) {
    canvas.drawRect(
      Rect.fromLTWH(x * px, y * px, px, px),
      paint,
    );
  }

  void _drawPixels(
    Canvas canvas,
    Color color,
    List<List<int>> pixels,
    double px,
  ) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none
      ..style = PaintingStyle.fill;
    for (final p in pixels) {
      _drawPixel(canvas, paint, p[0], p[1], px);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 16.0;
    _drawBase(canvas, px);
    _drawEquipment(canvas, px);
    if (shimmerValue != null) {
      _drawSparkles(canvas, px, shimmerValue!);
    }
  }

  void _drawBase(Canvas canvas, double px) {
    // --- Hair / head top ---
    _drawPixels(canvas, _hairBrown, [
      [5, 1], [6, 1], [7, 1], [8, 1], [9, 1], [10, 1],
      [4, 2], [5, 2], [10, 2], [11, 2],
      [4, 3], [11, 3],
    ], px);

    // --- Outline for head ---
    _drawPixels(canvas, _outlineColor, [
      [5, 0], [6, 0], [7, 0], [8, 0], [9, 0], [10, 0],
      [4, 1], [11, 1],
      [3, 2], [12, 2],
      [3, 3], [12, 3],
      [3, 4], [12, 4],
      [3, 5], [12, 5],
      [4, 6], [11, 6],
      [5, 7], [10, 7],
      [6, 8], [7, 8], [8, 8], [9, 8],
    ], px);

    // --- Skin (head) ---
    _drawPixels(canvas, _skin, [
      // row 2
      [4, 2], [5, 2], [6, 2], [7, 2], [8, 2], [9, 2], [10, 2], [11, 2],
      // row 3
      [4, 3], [5, 3], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3], [11, 3],
      // row 4
      [4, 4], [5, 4], [6, 4], [7, 4], [8, 4], [9, 4], [10, 4], [11, 4],
      // row 5
      [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [9, 5], [10, 5], [11, 5],
      // row 6
      [5, 6], [6, 6], [7, 6], [8, 6], [9, 6], [10, 6],
      // row 7
      [6, 7], [7, 7], [8, 7], [9, 7],
    ], px);

    // --- Eyes ---
    _drawPixels(canvas, _eyeColor, [
      [6, 3], [9, 3],
    ], px);

    // --- Eye shine ---
    _drawPixels(canvas, Colors.white, [
      [6, 4],
    ], px);

    // --- Blush ---
    _drawPixels(canvas, _blush, [
      [5, 5], [10, 5],
    ], px);

    // --- Smile ---
    _drawPixels(canvas, _smileColor, [
      [6, 6], [7, 7], [8, 7], [9, 6],
    ], px);

    // --- Neck ---
    _drawPixels(canvas, _skin, [
      [7, 8], [8, 8],
    ], px);

    // --- Default shirt (body) - will be overridden by top equipment ---
    _drawBody(canvas, px, _defaultShirt);

    // --- Arms skin ---
    _drawPixels(canvas, _skin, [
      [4, 9], [5, 9],
      [10, 9], [11, 9],
      [4, 10], [5, 10],
      [10, 10], [11, 10],
      [4, 11], [5, 11],
      [10, 11], [11, 11],
    ], px);

    // --- Default pants ---
    _drawLegs(canvas, px, _defaultPants, false);

    // --- Default shoes ---
    _drawShoes(canvas, px, _defaultShoes);
  }

  void _drawBody(Canvas canvas, double px, Color color) {
    _drawPixels(canvas, color, [
      [6, 8], [7, 8], [8, 8], [9, 8],
      [5, 9], [6, 9], [7, 9], [8, 9], [9, 9], [10, 9],
      [5, 10], [6, 10], [7, 10], [8, 10], [9, 10], [10, 10],
      [5, 11], [6, 11], [7, 11], [8, 11], [9, 11], [10, 11],
    ], px);
  }

  void _drawLegs(Canvas canvas, double px, Color color, bool isShorts) {
    final rows = isShorts ? [12] : [12, 13, 14];
    final pixels = <List<int>>[];
    for (final row in rows) {
      pixels.addAll([[5, row], [6, row], [7, row], [8, row], [9, row], [10, row]]);
    }
    if (!isShorts) {
      // full pants
      pixels.addAll([
        [5, 12], [6, 12], [7, 12], [8, 12], [9, 12], [10, 12],
        [5, 13], [6, 13],
        [9, 13], [10, 13],
        [5, 14], [6, 14],
        [9, 14], [10, 14],
      ]);
    } else {
      pixels.addAll([
        [5, 12], [6, 12], [7, 12], [8, 12], [9, 12], [10, 12],
      ]);
      // Bare legs for shorts
      _drawPixels(canvas, _skin, [
        [5, 13], [6, 13], [9, 13], [10, 13],
        [5, 14], [6, 14], [9, 14], [10, 14],
      ], px);
    }
    _drawPixels(canvas, color, pixels, px);
  }

  void _drawShoes(Canvas canvas, double px, Color color) {
    _drawPixels(canvas, color, [
      [4, 15], [5, 15], [6, 15],
      [9, 15], [10, 15], [11, 15],
    ], px);
  }

  void _drawEquipment(Canvas canvas, double px) {
    final c = character;
    if (c == null) return;

    // Draw top first (shirt area)
    if (c.top != null) {
      _drawTopEquipment(canvas, px, c.top!.assetKey, c.top!.rarity);
    }

    // Draw bottom (pants area)
    if (c.bottom != null) {
      _drawBottomEquipment(canvas, px, c.bottom!.assetKey);
    }

    // Draw shoes
    if (c.shoes != null) {
      _drawShoesEquipment(canvas, px, c.shoes!.assetKey, c.shoes!.rarity);
    }

    // Draw accessory (behind hat but on top of body)
    if (c.accessory != null) {
      _drawAccessoryEquipment(canvas, px, c.accessory!.assetKey, c.accessory!.rarity);
    }

    // Draw hat last (on top of everything)
    if (c.hat != null) {
      _drawHatEquipment(canvas, px, c.hat!.assetKey, c.hat!.rarity);
    }
  }

  void _drawHatEquipment(Canvas canvas, double px, String assetKey, String rarity) {
    switch (assetKey) {
      case 'hat/cap.png':
        // Red baseball cap
        _drawPixels(canvas, const Color(0xFFE53935), [
          [5, 0], [6, 0], [7, 0], [8, 0], [9, 0], [10, 0],
          [4, 1], [5, 1], [6, 1], [7, 1], [8, 1], [9, 1], [10, 1], [11, 1],
        ], px);
        // Brim
        _drawPixels(canvas, const Color(0xFFC62828), [
          [4, 2], [11, 2], [3, 2], [12, 2],
        ], px);
        break;

      case 'hat/beanie.png':
      case 'hat/pink_beanie.png':
        // Pink or blue beanie based on asset key
        final isP = assetKey.contains('pink');
        final beanieMain = isP ? const Color(0xFFFF80AB) : const Color(0xFF1976D2);
        final beanieLight = isP ? const Color(0xFFFFCDD2) : const Color(0xFF90CAF9);
        final pompom = isP ? const Color(0xFFFFFFFF) : Colors.white;
        // Pom-pom top
        _drawPixels(canvas, pompom, [
          [7, 0], [8, 0],
        ], px);
        // Main body
        _drawPixels(canvas, beanieMain, [
          [5, 0], [6, 0], [9, 0], [10, 0],
          [4, 1], [5, 1], [6, 1], [7, 1], [8, 1], [9, 1], [10, 1], [11, 1],
          [4, 2], [5, 2], [11, 2],
        ], px);
        // Ribbed stripe
        _drawPixels(canvas, beanieLight, [
          [5, 1], [7, 1], [9, 1], [11, 1],
        ], px);
        break;

      case 'hat/headband.png':
        // Thin yellow headband
        _drawPixels(canvas, const Color(0xFFFFD600), [
          [4, 2], [5, 2], [6, 2], [7, 2], [8, 2], [9, 2], [10, 2], [11, 2],
        ], px);
        // Bow accent
        _drawPixels(canvas, const Color(0xFFFF8F00), [
          [7, 1], [8, 1],
        ], px);
        break;

      case 'hat/fedora.png':
        // Brown wide-brim fedora
        _drawPixels(canvas, const Color(0xFF795548), [
          [6, 0], [7, 0], [8, 0], [9, 0],
          [5, 1], [6, 1], [7, 1], [8, 1], [9, 1], [10, 1],
        ], px);
        // Wide brim
        _drawPixels(canvas, const Color(0xFF5D4037), [
          [3, 2], [4, 2], [5, 2], [6, 2], [7, 2],
          [8, 2], [9, 2], [10, 2], [11, 2], [12, 2],
        ], px);
        // Band
        _drawPixels(canvas, const Color(0xFFFFCC80), [
          [5, 1], [10, 1],
        ], px);
        break;

      case 'hat/beret.png':
        // Dark red beret tilted left
        _drawPixels(canvas, const Color(0xFF8D1515), [
          [5, 0], [6, 0], [7, 0], [8, 0], [9, 0], [10, 0],
          [4, 1], [5, 1], [6, 1], [7, 1], [8, 1], [9, 1], [10, 1],
          [4, 2], [5, 2],
        ], px);
        // Highlight
        _drawPixels(canvas, const Color(0xFFB71C1C), [
          [8, 0], [9, 0],
        ], px);
        break;

      case 'hat/crown.png':
        // Golden crown with points - EPIC
        final goldColor = rarity == 'EPIC'
            ? const Color(0xFFFFD700)
            : const Color(0xFFE6B800);
        // Crown points
        _drawPixels(canvas, goldColor, [
          [5, -1 < 0 ? 0 : 0], [7, 0], [9, 0], [11, 0],
          [5, 0], [6, 0], [7, 0], [8, 0], [9, 0], [10, 0], [11, 0],
          [4, 1], [5, 1], [6, 1], [7, 1], [8, 1], [9, 1], [10, 1], [11, 1], [12, 1],
        ], px);
        // Jewel accents
        _drawPixels(canvas, const Color(0xFFE91E63), [
          [7, 1],
        ], px);
        _drawPixels(canvas, const Color(0xFF2196F3), [
          [9, 1],
        ], px);
        // Crown shine
        _drawPixels(canvas, Colors.white, [
          [5, 0], [11, 0],
        ], px);
        break;

      default:
        // Generic hat - grey cap
        _drawPixels(canvas, const Color(0xFF9E9E9E), [
          [5, 0], [6, 0], [7, 0], [8, 0], [9, 0], [10, 0],
          [4, 1], [5, 1], [6, 1], [7, 1], [8, 1], [9, 1], [10, 1], [11, 1],
        ], px);
    }
  }

  void _drawTopEquipment(Canvas canvas, double px, String assetKey, String rarity) {
    switch (assetKey) {
      case 'top/white_tee.png':
        _drawBody(canvas, px, const Color(0xFFF5F5F5));
        // Collar outline
        _drawPixels(canvas, const Color(0xFFCCCCCC), [
          [7, 8], [8, 8],
        ], px);
        break;

      case 'top/striped_tee.png':
        // Alternating blue/white stripes
        _drawPixels(canvas, const Color(0xFF1976D2), [
          [6, 8], [7, 8], [8, 8], [9, 8],
          [5, 10], [6, 10], [7, 10], [8, 10], [9, 10], [10, 10],
        ], px);
        _drawPixels(canvas, Colors.white, [
          [5, 9], [6, 9], [7, 9], [8, 9], [9, 9], [10, 9],
          [5, 11], [6, 11], [7, 11], [8, 11], [9, 11], [10, 11],
        ], px);
        break;

      case 'top/check_shirt.png':
        // Red-white checkered flannel shirt
        const red = Color(0xFFD32F2F);
        const darkRed = Color(0xFFB71C1C);
        const cream = Color(0xFFFFF8E1);
        // Checkerboard pattern on torso
        _drawPixels(canvas, red, [
          [6, 8], [8, 8],
          [5, 9], [7, 9], [9, 9],
          [6, 10], [8, 10], [10, 10],
          [5, 11], [7, 11], [9, 11],
        ], px);
        _drawPixels(canvas, cream, [
          [7, 8], [9, 8],
          [6, 9], [8, 9], [10, 9],
          [5, 10], [7, 10], [9, 10],
          [6, 11], [8, 11], [10, 11],
        ], px);
        // Collar
        _drawPixels(canvas, darkRed, [
          [6, 8], [9, 8],
        ], px);
        break;

      case 'top/sleeveless.png':
        // Green sleeveless - narrower shoulders
        _drawPixels(canvas, const Color(0xFF388E3C), [
          [6, 8], [7, 8], [8, 8], [9, 8],
          [6, 9], [7, 9], [8, 9], [9, 9],
          [6, 10], [7, 10], [8, 10], [9, 10],
          [6, 11], [7, 11], [8, 11], [9, 11],
        ], px);
        break;

      case 'top/hoodie.png':
        // Blue hoodie with hood shape
        _drawPixels(canvas, const Color(0xFF1565C0), [
          [5, 8], [6, 8], [7, 8], [8, 8], [9, 8], [10, 8],
          [5, 9], [6, 9], [7, 9], [8, 9], [9, 9], [10, 9],
          [5, 10], [6, 10], [7, 10], [8, 10], [9, 10], [10, 10],
          [5, 11], [6, 11], [7, 11], [8, 11], [9, 11], [10, 11],
        ], px);
        // Hood shadow
        _drawPixels(canvas, const Color(0xFF0D47A1), [
          [6, 8], [9, 8],
        ], px);
        // Pouch
        _drawPixels(canvas, const Color(0xFF1976D2), [
          [7, 11], [8, 11],
        ], px);
        break;

      case 'top/cardigan.png':
        // Brown open-front cardigan
        _drawPixels(canvas, const Color(0xFF8D6E63), [
          [5, 8], [6, 8], [9, 8], [10, 8],
          [5, 9], [6, 9], [9, 9], [10, 9],
          [5, 10], [6, 10], [9, 10], [10, 10],
          [5, 11], [6, 11], [9, 11], [10, 11],
        ], px);
        // Inner shirt color
        _drawPixels(canvas, const Color(0xFFFFF9C4), [
          [7, 8], [8, 8],
          [7, 9], [8, 9],
          [7, 10], [8, 10],
          [7, 11], [8, 11],
        ], px);
        // Buttons
        _drawPixels(canvas, const Color(0xFF5D4037), [
          [7, 9], [7, 11],
        ], px);
        break;

      case 'top/tuxedo.png':
        // Black tuxedo with white bowtie - EPIC
        _drawPixels(canvas, const Color(0xFF212121), [
          [5, 8], [6, 8], [9, 8], [10, 8],
          [5, 9], [6, 9], [9, 9], [10, 9],
          [5, 10], [6, 10], [9, 10], [10, 10],
          [5, 11], [6, 11], [9, 11], [10, 11],
        ], px);
        // White shirt front
        _drawPixels(canvas, Colors.white, [
          [7, 8], [8, 8],
          [7, 9], [8, 9],
          [7, 10], [8, 10],
          [7, 11], [8, 11],
        ], px);
        // Bowtie
        _drawPixels(canvas, const Color(0xFFFF1744), [
          [7, 8], [8, 8],
        ], px);
        // Buttons
        _drawPixels(canvas, const Color(0xFFBDBDBD), [
          [7, 10], [8, 11],
        ], px);
        break;

      default:
        _drawBody(canvas, px, _defaultShirt);
    }
  }

  void _drawBottomEquipment(Canvas canvas, double px, String assetKey) {
    switch (assetKey) {
      case 'bottom/jeans.png':
        _drawPixels(canvas, const Color(0xFF1565C0), [
          [5, 12], [6, 12], [7, 12], [8, 12], [9, 12], [10, 12],
          [5, 13], [6, 13], [9, 13], [10, 13],
          [5, 14], [6, 14], [9, 14], [10, 14],
        ], px);
        // Pockets
        _drawPixels(canvas, const Color(0xFF0D47A1), [
          [5, 12], [10, 12],
        ], px);
        break;

      case 'bottom/shorts.png':
        // Khaki shorts, shorter
        _drawPixels(canvas, const Color(0xFFC8A96E), [
          [5, 12], [6, 12], [7, 12], [8, 12], [9, 12], [10, 12],
          [5, 13], [6, 13], [9, 13], [10, 13],
        ], px);
        // Bare legs
        _drawPixels(canvas, _skin, [
          [5, 14], [6, 14], [9, 14], [10, 14],
        ], px);
        break;

      case 'bottom/chinos.png':
        // Beige chinos
        _drawPixels(canvas, const Color(0xFFD4B896), [
          [5, 12], [6, 12], [7, 12], [8, 12], [9, 12], [10, 12],
          [5, 13], [6, 13], [9, 13], [10, 13],
          [5, 14], [6, 14], [9, 14], [10, 14],
        ], px);
        break;

      case 'bottom/skirt.png':
        // Pink skirt - triangle shape
        _drawPixels(canvas, const Color(0xFFEC407A), [
          [6, 12], [7, 12], [8, 12], [9, 12],
          [5, 13], [6, 13], [7, 13], [8, 13], [9, 13], [10, 13],
          [4, 14], [5, 14], [6, 14], [7, 14], [8, 14], [9, 14], [10, 14], [11, 14],
        ], px);
        // Ruffle detail
        _drawPixels(canvas, const Color(0xFFF48FB1), [
          [4, 14], [11, 14],
        ], px);
        break;

      case 'bottom/cargo.png':
        // Olive green cargo pants, wider
        _drawPixels(canvas, const Color(0xFF558B2F), [
          [4, 12], [5, 12], [6, 12], [7, 12], [8, 12], [9, 12], [10, 12], [11, 12],
          [4, 13], [5, 13], [10, 13], [11, 13],
          [4, 14], [5, 14], [10, 14], [11, 14],
        ], px);
        // Cargo pockets
        _drawPixels(canvas, const Color(0xFF33691E), [
          [4, 13], [11, 13],
        ], px);
        break;

      case 'bottom/golden_pants.png':
        // Gold pants - EPIC
        _drawPixels(canvas, const Color(0xFFFFD700), [
          [5, 12], [6, 12], [7, 12], [8, 12], [9, 12], [10, 12],
          [5, 13], [6, 13], [9, 13], [10, 13],
          [5, 14], [6, 14], [9, 14], [10, 14],
        ], px);
        // Gold shine
        _drawPixels(canvas, Colors.white, [
          [6, 12], [9, 12],
        ], px);
        _drawPixels(canvas, const Color(0xFFFF8F00), [
          [5, 13], [10, 13],
        ], px);
        break;

      default:
        _drawLegs(canvas, px, _defaultPants, false);
    }
  }

  void _drawShoesEquipment(Canvas canvas, double px, String assetKey, String rarity) {
    Color shoeColor;
    switch (assetKey) {
      case 'shoes/sneakers.png':
        shoeColor = const Color(0xFF42A5F5);
        break;
      case 'shoes/boots.png':
        shoeColor = const Color(0xFF5D4037);
        break;
      case 'shoes/heels.png':
        shoeColor = const Color(0xFFE91E63);
        break;
      case 'shoes/loafers.png':
        shoeColor = const Color(0xFF37474F);
        break;
      case 'shoes/sandals.png':
        shoeColor = const Color(0xFFD4A017);
        break;
      case 'shoes/golden_shoes.png':
        shoeColor = const Color(0xFFFFD700);
        break;
      default:
        shoeColor = _defaultShoes;
    }

    _drawShoes(canvas, px, shoeColor);

    // Sparkle for EPIC shoes
    if (rarity == 'EPIC') {
      _drawPixels(canvas, Colors.white, [
        [4, 15], [11, 15],
      ], px);
    }
  }

  void _drawAccessoryEquipment(Canvas canvas, double px, String assetKey, String rarity) {
    switch (assetKey) {
      case 'accessory/watch.png':
        // Small dot on left wrist
        _drawPixels(canvas, const Color(0xFF78909C), [
          [4, 10],
        ], px);
        _drawPixels(canvas, const Color(0xFFFFFFFF), [
          [4, 10],
        ], px);
        break;

      case 'accessory/sunglasses.png':
        // Colored pixels over eyes
        _drawPixels(canvas, const Color(0xFF37474F), [
          [5, 3], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3],
        ], px);
        // Lens colors
        _drawPixels(canvas, const Color(0xFF4DB6AC), [
          [6, 3], [7, 3],
        ], px);
        _drawPixels(canvas, const Color(0xFF4DB6AC), [
          [8, 3], [9, 3],
        ], px);
        // Bridge
        _drawPixels(canvas, const Color(0xFF37474F), [
          [7, 3], [8, 3],
        ], px);
        break;

      case 'accessory/angel_wings.png':
        // White wing shapes on sides - EPIC
        _drawPixels(canvas, Colors.white, [
          // Left wing
          [2, 8], [3, 8],
          [1, 9], [2, 9], [3, 9],
          [2, 10], [3, 10],
          [2, 11], [3, 11],
          // Right wing
          [12, 8], [13, 8],
          [12, 9], [13, 9], [14, 9],
          [12, 10], [13, 10],
          [12, 11], [13, 11],
        ], px);
        // Wing feather detail
        _drawPixels(canvas, const Color(0xFFE3F2FD), [
          [2, 9], [13, 9],
        ], px);
        break;

      case 'accessory/necklace.png':
        _drawPixels(canvas, const Color(0xFFFFD700), [
          [7, 8], [8, 8],
        ], px);
        break;

      default:
        break;
    }
  }

  void _drawSparkles(Canvas canvas, double px, double animValue) {
    // Sparkle positions rotate based on animation
    final sparklePaint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;

    final sparklePositions = [
      [2, 2], [13, 2], [1, 8], [14, 7], [3, 13], [12, 14],
    ];

    for (var i = 0; i < sparklePositions.length; i++) {
      final phase = (animValue + i / sparklePositions.length) % 1.0;
      if (phase < 0.3) {
        final alpha = (phase / 0.3 * 255).round().clamp(0, 255);
        sparklePaint.color = Colors.white.withAlpha(alpha);
        final x = sparklePositions[i][0];
        final y = sparklePositions[i][1];
        canvas.drawRect(Rect.fromLTWH(x * px, y * px, px, px), sparklePaint);
      }
    }

    // Also draw gold shimmer accent on crown if equipped
    if (character?.hat?.assetKey == 'hat/crown.png') {
      final shimmerAlpha = (255 * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(animValue * 2 * math.pi)))).round().clamp(0, 255);
      final goldPaint = Paint()
        ..color = Color.fromARGB(shimmerAlpha, 0xFF, 0xFF, 0xCC)
        ..isAntiAlias = false;
      for (final p in [[7, 0], [8, 0], [9, 0]]) {
        canvas.drawRect(
          Rect.fromLTWH(p[0] * px, p[1] * px, px, px),
          goldPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PixelCharacterPainter oldDelegate) {
    return oldDelegate.character != character ||
        oldDelegate.shimmerValue != shimmerValue;
  }
}

// ─── Item Preview: standalone pixel-art icon for each item ───

/// Renders a single item as a standalone pixel-art icon on an 8x8 grid.
class ItemPreview extends StatelessWidget {
  final String assetKey;
  final String rarity;
  final double size;

  const ItemPreview({
    super.key,
    required this.assetKey,
    required this.rarity,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ItemIconPainter(assetKey: assetKey, rarity: rarity),
    );
  }
}

class _ItemIconPainter extends CustomPainter {
  final String assetKey;
  final String rarity;
  const _ItemIconPainter({required this.assetKey, required this.rarity});

  void _px(Canvas c, Paint p, int x, int y, double s) {
    c.drawRect(Rect.fromLTWH(x * s, y * s, s, s), p);
  }

  void _draw(Canvas c, Color color, List<List<int>> pts, double s) {
    final p = Paint()
      ..color = color
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;
    for (final pt in pts) {
      _px(c, p, pt[0], pt[1], s);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 8.0;

    // Background — subtle rarity tint
    final bg = Paint()..color = const Color(0xFFF5F5F5)..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s)),
      bg,
    );

    switch (assetKey) {
      // ─── HATS ───
      case 'hat/cap.png':
        _draw(canvas, const Color(0xFFE53935), [[2,2],[3,2],[4,2],[5,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[1,4],[6,4]], s);
        _draw(canvas, const Color(0xFFC62828), [[0,4],[1,4],[6,4],[7,4]], s); // brim
        break;
      case 'hat/beanie.png':
      case 'hat/pink_beanie.png':
        final isP = assetKey.contains('pink');
        final m = isP ? const Color(0xFFFF80AB) : const Color(0xFF1976D2);
        final l = isP ? const Color(0xFFFFCDD2) : const Color(0xFF90CAF9);
        _draw(canvas, Colors.white, [[3,1],[4,1]], s); // pompom
        _draw(canvas, m, [[2,2],[3,2],[4,2],[5,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[1,4],[2,4],[5,4],[6,4]], s);
        _draw(canvas, l, [[2,3],[4,3],[6,3]], s); // stripes
        break;
      case 'hat/headband.png':
        _draw(canvas, const Color(0xFFFFD600), [[1,3],[2,3],[3,3],[4,3],[5,3],[6,3]], s);
        _draw(canvas, const Color(0xFFFF8F00), [[3,2],[4,2]], s); // bow
        break;
      case 'hat/fedora.png':
        _draw(canvas, const Color(0xFF795548), [[3,1],[4,1],[2,2],[3,2],[4,2],[5,2]], s);
        _draw(canvas, const Color(0xFF5D4037), [[0,3],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3]], s);
        _draw(canvas, const Color(0xFFFFCC80), [[2,2],[5,2]], s); // band
        break;
      case 'hat/beret.png':
        _draw(canvas, const Color(0xFF8D1515), [[2,1],[3,1],[4,1],[5,1],[1,2],[2,2],[3,2],[4,2],[5,2],[1,3],[2,3]], s);
        _draw(canvas, const Color(0xFFB71C1C), [[4,1],[5,1]], s);
        break;
      case 'hat/crown.png':
        _draw(canvas, const Color(0xFFFFD700), [[1,1],[3,1],[5,1],[7,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3]], s);
        _draw(canvas, const Color(0xFFE91E63), [[3,3]], s);
        _draw(canvas, const Color(0xFF2196F3), [[5,3]], s);
        _draw(canvas, Colors.white, [[1,1],[7,1]], s);
        break;

      // ─── TOPS ───
      case 'top/white_tee.png':
        _draw(canvas, const Color(0xFFF5F5F5), [[3,1],[4,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[2,3],[3,3],[4,3],[5,3],[2,4],[3,4],[4,4],[5,4],[2,5],[3,5],[4,5],[5,5]], s);
        _draw(canvas, const Color(0xFFE0E0E0), [[1,2],[6,2],[3,1],[4,1]], s); // collar/sleeves
        break;
      case 'top/striped_tee.png':
        _draw(canvas, const Color(0xFF1976D2), [[3,1],[4,1],[1,2],[3,2],[5,2],[2,3],[4,3],[2,5],[4,5]], s);
        _draw(canvas, Colors.white, [[2,2],[4,2],[6,2],[3,3],[5,3],[2,4],[3,4],[4,4],[5,4],[3,5],[5,5]], s);
        break;
      case 'top/check_shirt.png':
        const r = Color(0xFFD32F2F);
        const cr = Color(0xFFFFF8E1);
        _draw(canvas, r, [[3,1],[4,1],[1,2],[3,2],[5,2],[2,3],[4,3],[2,5],[4,5]], s);
        _draw(canvas, cr, [[2,2],[4,2],[6,2],[3,3],[5,3],[3,4],[5,4],[3,5],[5,5]], s);
        _draw(canvas, const Color(0xFFB71C1C), [[3,1],[4,1]], s);
        break;
      case 'top/sleeveless.png':
        _draw(canvas, const Color(0xFF388E3C), [[3,1],[4,1],[3,2],[4,2],[3,3],[4,3],[3,4],[4,4],[3,5],[4,5]], s);
        _draw(canvas, const Color(0xFF2E7D32), [[3,1],[4,1]], s);
        break;
      case 'top/hoodie.png':
        _draw(canvas, const Color(0xFF1565C0), [[2,1],[3,1],[4,1],[5,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[2,3],[3,3],[4,3],[5,3],[2,4],[3,4],[4,4],[5,4],[2,5],[3,5],[4,5],[5,5]], s);
        _draw(canvas, const Color(0xFF0D47A1), [[2,1],[5,1]], s); // hood
        _draw(canvas, const Color(0xFF1976D2), [[3,5],[4,5]], s); // pouch
        break;
      case 'top/cardigan.png':
        _draw(canvas, const Color(0xFF8D6E63), [[1,2],[2,2],[5,2],[6,2],[2,3],[5,3],[2,4],[5,4],[2,5],[5,5]], s);
        _draw(canvas, const Color(0xFFFFF9C4), [[3,2],[4,2],[3,3],[4,3],[3,4],[4,4],[3,5],[4,5]], s);
        _draw(canvas, const Color(0xFF5D4037), [[3,3],[3,5]], s); // buttons
        break;
      case 'top/tuxedo.png':
        _draw(canvas, const Color(0xFF212121), [[1,2],[2,2],[5,2],[6,2],[2,3],[5,3],[2,4],[5,4],[2,5],[5,5]], s);
        _draw(canvas, Colors.white, [[3,2],[4,2],[3,3],[4,3],[3,4],[4,4],[3,5],[4,5]], s);
        _draw(canvas, const Color(0xFFFF1744), [[3,2],[4,2]], s); // bowtie
        break;

      // ─── BOTTOMS ───
      case 'bottom/jeans.png':
        _draw(canvas, const Color(0xFF1565C0), [[2,1],[3,1],[4,1],[5,1],[2,2],[3,2],[4,2],[5,2],[2,3],[3,3],[4,3],[5,3],[2,4],[3,4],[4,4],[5,4]], s);
        _draw(canvas, const Color(0xFF0D47A1), [[2,1],[5,1],[2,4],[5,4]], s); // pockets/hem
        break;
      case 'bottom/shorts.png':
        _draw(canvas, const Color(0xFFC8A96E), [[2,1],[3,1],[4,1],[5,1],[2,2],[3,2],[4,2],[5,2],[2,3],[3,3],[4,3],[5,3]], s);
        break;
      case 'bottom/chinos.png':
        _draw(canvas, const Color(0xFFD4B896), [[2,1],[3,1],[4,1],[5,1],[2,2],[3,2],[4,2],[5,2],[2,3],[3,3],[4,3],[5,3],[2,4],[3,4],[4,4],[5,4]], s);
        break;
      case 'bottom/skirt.png':
        _draw(canvas, const Color(0xFFEC407A), [[3,1],[4,1],[2,2],[3,2],[4,2],[5,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4]], s);
        _draw(canvas, const Color(0xFFF48FB1), [[1,4],[6,4]], s);
        break;
      case 'bottom/cargo.png':
        _draw(canvas, const Color(0xFF558B2F), [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[1,2],[2,2],[5,2],[6,2],[1,3],[2,3],[5,3],[6,3],[1,4],[2,4],[5,4],[6,4]], s);
        _draw(canvas, const Color(0xFF33691E), [[1,2],[6,2]], s); // pockets
        break;
      case 'bottom/golden_pants.png':
        _draw(canvas, const Color(0xFFFFD700), [[2,1],[3,1],[4,1],[5,1],[2,2],[3,2],[4,2],[5,2],[2,3],[3,3],[4,3],[5,3],[2,4],[3,4],[4,4],[5,4]], s);
        _draw(canvas, Colors.white, [[3,1],[4,1]], s);
        break;

      // ─── SHOES ───
      case 'shoes/slippers.png':
        _draw(canvas, const Color(0xFFBDBDBD), [[1,3],[2,3],[3,3],[5,3],[6,3],[7,3],[1,4],[2,4],[3,4],[5,4],[6,4],[7,4]], s);
        break;
      case 'shoes/sneakers.png':
        _draw(canvas, const Color(0xFF42A5F5), [[1,3],[2,3],[3,3],[5,3],[6,3],[7,3],[0,4],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4]], s);
        _draw(canvas, Colors.white, [[1,3],[5,3]], s); // stripe
        break;
      case 'shoes/sandals.png':
        _draw(canvas, const Color(0xFFD4A017), [[1,3],[3,3],[5,3],[7,3],[1,4],[2,4],[3,4],[5,4],[6,4],[7,4]], s);
        break;
      case 'shoes/boots.png':
        _draw(canvas, const Color(0xFF5D4037), [[1,2],[2,2],[3,2],[5,2],[6,2],[7,2],[1,3],[2,3],[3,3],[5,3],[6,3],[7,3],[0,4],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4]], s);
        break;
      case 'shoes/hightops.png':
        _draw(canvas, const Color(0xFF37474F), [[1,2],[2,2],[3,2],[5,2],[6,2],[7,2],[1,3],[2,3],[3,3],[5,3],[6,3],[7,3],[1,4],[2,4],[3,4],[5,4],[6,4],[7,4]], s);
        _draw(canvas, Colors.white, [[2,2],[6,2]], s);
        break;
      case 'shoes/winged_shoes.png':
        _draw(canvas, const Color(0xFFFFD700), [[1,3],[2,3],[3,3],[5,3],[6,3],[7,3],[0,4],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4]], s);
        _draw(canvas, Colors.white, [[0,2],[0,3],[4,2],[4,3]], s); // wings
        break;

      // ─── ACCESSORIES ───
      case 'accessory/watch.png':
        _draw(canvas, const Color(0xFF78909C), [[3,2],[4,2],[3,3],[4,3],[3,4],[4,4]], s); // band
        _draw(canvas, const Color(0xFFE0E0E0), [[3,3],[4,3]], s); // face
        break;
      case 'accessory/bag.png':
        _draw(canvas, const Color(0xFF8D6E63), [[2,1],[3,1],[4,1],[5,1],[2,2],[3,2],[4,2],[5,2],[2,3],[3,3],[4,3],[5,3],[2,4],[3,4],[4,4],[5,4]], s);
        _draw(canvas, const Color(0xFFD7CCC8), [[3,1],[4,1]], s); // handle
        _draw(canvas, const Color(0xFF5D4037), [[3,3],[4,3]], s); // clasp
        break;
      case 'accessory/scarf.png':
        _draw(canvas, const Color(0xFFE53935), [[2,2],[3,2],[4,2],[5,2],[3,3],[4,3],[3,4],[4,4],[4,5],[4,6]], s);
        _draw(canvas, const Color(0xFFC62828), [[2,2],[5,2],[4,5]], s);
        break;
      case 'accessory/sunglasses.png':
        _draw(canvas, const Color(0xFF37474F), [[1,3],[2,3],[3,3],[4,3],[5,3],[6,3]], s); // frame
        _draw(canvas, const Color(0xFF4DB6AC), [[2,3],[3,3],[5,3],[6,3]], s); // lenses
        _draw(canvas, const Color(0xFF263238), [[1,2],[6,2]], s); // arms
        break;
      case 'accessory/earphones.png':
        _draw(canvas, const Color(0xFF424242), [[2,2],[5,2],[1,3],[2,3],[5,3],[6,3],[2,4],[3,4],[4,4],[5,4]], s);
        _draw(canvas, Colors.white, [[2,3],[5,3]], s); // earpad
        break;
      case 'accessory/angel_wings.png':
        _draw(canvas, Colors.white, [[0,1],[1,1],[6,1],[7,1],[0,2],[1,2],[2,2],[5,2],[6,2],[7,2],[0,3],[1,3],[6,3],[7,3],[1,4],[6,4]], s);
        _draw(canvas, const Color(0xFFE3F2FD), [[1,2],[6,2]], s);
        break;

      default:
        // Generic item — question mark
        _draw(canvas, const Color(0xFF9E9E9E), [[2,1],[3,1],[4,1],[5,1],[5,2],[4,3],[3,3],[3,5]], s);
    }
  }

  @override
  bool shouldRepaint(_ItemIconPainter old) =>
      old.assetKey != assetKey || old.rarity != rarity;
}
