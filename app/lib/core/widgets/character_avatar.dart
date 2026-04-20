import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../features/character/models/character_data.dart';
import 'accessory_renderer.dart';
export 'item_icon_painter.dart';

/// Centralized 3-tone pixel art palette for the 32×32 character.
/// (spec §6 lines 192-248)
class CharacterPalette {
  // Skin 3 tones × 3 skintones (spec §6)
  static const skinFairShadow = Color(0xFFF2B891);
  static const skinFairBase = Color(0xFFFFCBA4);
  static const skinFairHighlight = Color(0xFFFFE1C7);
  static const skinLightShadow = Color(0xFFF7D9B8);
  static const skinLightBase = Color(0xFFFFF0DB);
  static const skinLightHighlight = Color(0xFFFFF8EC);
  static const skinDarkShadow = Color(0xFF6B3E18);
  static const skinDarkBase = Color(0xFF8D5524);
  static const skinDarkHighlight = Color(0xFFB47B4A);

  // Hair (spec §6)
  static const hairOutline = Color(0xFF3A2010);
  static const hairShadow = Color(0xFF4A2812);
  static const hairBase = Color(0xFF5D3A1A);
  static const hairHighlight = Color(0xFF8B5A2B);

  // Face features (spec §6)
  static const eyeOutline = Color(0xFF2D1B00);
  static const eyePupil = Color(0xFF3A1F0A);
  static const eyeWhite = Color(0xFFFFFFFF);
  static const eyeShine = Color(0xFFFFF8E1);
  static const blushBase = Color(0xFFFFB3B3);
  static const blushSoft = Color(0xFFFFD9D9);
  static const mouthLine = Color(0xFF8B4513);
  static const mouthDark = Color(0xFF6B3A10);
  static const lipTint = Color(0xFFD26B6B);

  // Default clothing fallback (spec §6)
  static const defaultShirtBase = Color(0xFFF5F5F5);
  static const defaultShirtShadow = Color(0xFFDCDCDC);
  static const defaultShirtHighlight = Color(0xFFFFFFFF);
  static const defaultShirtOutline = Color(0xFFA9A9A9);
  static const defaultPantsBase = Color(0xFF5B88C4);
  static const defaultPantsShadow = Color(0xFF3E6CA3);
  static const defaultPantsHighlight = Color(0xFF7FA5D6);
  static const defaultPantsOutline = Color(0xFF2F4E7A);
  static const defaultShoesBase = Color(0xFF8B6914);
  static const defaultShoesShadow = Color(0xFF5F4508);
  static const defaultShoesHighlight = Color(0xFFB08838);
  static const defaultShoesOutline = Color(0xFF3E2C04);

  // Effects (spec §6)
  static const sparkleWhite = Color(0xCCFFFFFF);
  static const sparkleGold = Color(0xFFFFF4B3);
}

/// Pixel-art character avatar rendered on a 32×32 logical grid via CustomPainter.
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
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;
  late final Animation<double> _sparkleAnimation;
  late final AnimationController _accessoryAnimController;

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

    _accessoryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    if (widget.showEffect && _hasEpicItem()) {
      _shimmerController.repeat(reverse: true);
    }
    if (_hasAnimatedAccessory()) {
      _accessoryAnimController.repeat();
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

    final shouldAnimAccessory = _hasAnimatedAccessory();
    if (shouldAnimAccessory && !_accessoryAnimController.isAnimating) {
      _accessoryAnimController.repeat();
    } else if (!shouldAnimAccessory && _accessoryAnimController.isAnimating) {
      _accessoryAnimController.stop();
      _accessoryAnimController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _accessoryAnimController.dispose();
    super.dispose();
  }

  bool _hasEpicItem() {
    final c = widget.character;
    if (c == null) return false;
    return [c.hat, c.top, c.bottom, c.shoes, c.accessory]
        .any((slot) => slot?.rarity == 'EPIC');
  }

  bool _hasAnimatedAccessory() {
    final key = widget.character?.accessory?.assetKey;
    return key == 'accessory/duck_watergun.png' ||
        key == 'accessory/laptop.png';
  }

  @override
  Widget build(BuildContext context) {
    final isEpic = widget.showEffect && _hasEpicItem();
    final animated = _hasAnimatedAccessory();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_shimmerAnimation, _accessoryAnimController]),
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _PixelCharacterPainter(
              character: widget.character,
              shimmerValue: isEpic ? _sparkleAnimation.value : null,
              accessoryAnimValue: animated ? _accessoryAnimController.value : null,
              isDark: isDark,
            ),
          ),
        );
      },
    );
  }
}

/// Draws the pixel-art character on a 32×32 logical grid.
/// All coordinates are verbatim from docs/design/specs/character-cyworld-style.md
class _PixelCharacterPainter extends CustomPainter {
  final CharacterData? character;
  final double? shimmerValue;
  final double? accessoryAnimValue;
  final bool isDark;

  const _PixelCharacterPainter({
    required this.character,
    this.shimmerValue,
    this.accessoryAnimValue,
    this.isDark = false,
  });

  // Returns [shadow, base, highlight] for skin tone
  static List<Color> _getSkinTones(String skinTone) {
    switch (skinTone) {
      case 'light':
        return [
          CharacterPalette.skinLightShadow,
          CharacterPalette.skinLightBase,
          CharacterPalette.skinLightHighlight,
        ];
      case 'dark':
        return [
          CharacterPalette.skinDarkShadow,
          CharacterPalette.skinDarkBase,
          CharacterPalette.skinDarkHighlight,
        ];
      default: // fair
        return [
          CharacterPalette.skinFairShadow,
          CharacterPalette.skinFairBase,
          CharacterPalette.skinFairHighlight,
        ];
    }
  }

  // Returns {outline, white, eyelash} pixel lists (spec §7.1)
  static Map<String, List<List<int>>> _getEyePattern(String eyeStyle) {
    switch (eyeStyle) {
      case 'sharp':
        // L outline: (12,10)(13,10)(14,10)(15,10)(12,11), eyelash: (15,11), whites: (13,11)(14,11)
        // R mirror: x' = 31 - x
        return {
          'outlineL': [[12,10],[13,10],[14,10],[15,10],[12,11]],
          'eyelashL': [[15,11]],
          'whiteL': [[13,11],[14,11]],
          'outlineR': [[16,10],[17,10],[18,10],[19,10],[19,11]],
          'eyelashR': [[16,11]],
          'whiteR': [[17,11],[18,11]],
        };
      case 'sleepy':
        // L outline: (12,11)(13,11)(14,11)(15,11), whites: (13,12)(14,12)
        // R mirror
        return {
          'outlineL': [[12,11],[13,11],[14,11],[15,11]],
          'eyelashL': [],
          'whiteL': [[13,12],[14,12]],
          'outlineR': [[16,11],[17,11],[18,11],[19,11]],
          'eyelashR': [],
          'whiteR': [[17,12],[18,12]],
        };
      default: // round
        // L outline: (12,10)(13,10)(14,10)(12,11)(14,11)(12,12)(13,12)(14,12), white: (13,11), shine: (12,10)
        // R mirror
        return {
          'outlineL': [[12,10],[13,10],[14,10],[12,11],[14,11],[12,12],[13,12],[14,12]],
          'eyelashL': [],
          'whiteL': [[13,11]],
          'shineL': [[12,10]],
          'outlineR': [[17,10],[18,10],[19,10],[17,11],[19,11],[17,12],[18,12],[19,12]],
          'eyelashR': [],
          'whiteR': [[18,11]],
          'shineR': [[19,10]],
        };
    }
  }

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
    if (pixels.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none
      ..style = PaintingStyle.fill;
    for (final p in pixels) {
      _drawPixel(canvas, paint, p[0], p[1], px);
    }
  }

  // 3-tone painting helper (spec §3)
  void _paintLayer(
    Canvas canvas,
    double px, {
    required List<List<int>> base,
    List<List<int>> shadow = const [],
    List<List<int>> highlight = const [],
    required Color baseColor,
    required Color shadowColor,
    required Color highlightColor,
  }) {
    _drawPixels(canvas, baseColor, base, px);
    _drawPixels(canvas, shadowColor, shadow, px);
    _drawPixels(canvas, highlightColor, highlight, px);
  }

  // Expand a range [(colStart,row)-(colEnd,row)] inclusive to pixel list
  static List<List<int>> _row(int colStart, int colEnd, int row) {
    return [for (int c = colStart; c <= colEnd; c++) [c, row]];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 32.0; // ★ 32-grid
    _drawBase(canvas, px);
    _drawEquipment(canvas, px);
    if (shimmerValue != null) {
      _drawSparkles(canvas, px, shimmerValue!);
    }
  }

  void _drawBase(Canvas canvas, double px) {
    final skinTones = _getSkinTones(character?.skinTone ?? 'fair');
    final skinShadow = skinTones[0];
    final skinBase = skinTones[1];
    final skinHighlight = skinTones[2];
    final eyePattern = _getEyePattern(character?.eyeStyle ?? 'round');
    final hairStyle = character?.hairStyle ?? 'short';

    // --- Hair ---
    _drawHair(canvas, px, hairStyle);

    // --- Face skin (spec §9 Body/Skin Layers) ---
    // base: rows 5-14, cols 11-20 + row 15 (col 12-19)
    final faceSkinBase = <List<int>>[
      ..._row(11, 20, 5),
      ..._row(11, 20, 6),
      ..._row(11, 20, 7),
      ..._row(11, 20, 8),
      ..._row(11, 20, 9),
      ..._row(11, 20, 10),
      ..._row(11, 20, 11),
      ..._row(11, 20, 12),
      ..._row(11, 20, 13),
      ..._row(11, 20, 14),
      ..._row(12, 19, 15),
    ];
    // shadow: right/chin side
    final faceSkinShadow = <List<int>>[
      [20,6],[20,7],[20,8],[19,9],[19,10],[19,11],[19,12],[19,13],[19,14],[18,15],
    ];
    // highlight: upper-left
    final faceSkinHighlight = <List<int>>[
      [11,5],[12,5],[11,6],
    ];
    _paintLayer(canvas, px,
      base: faceSkinBase,
      shadow: faceSkinShadow,
      highlight: faceSkinHighlight,
      baseColor: skinBase,
      shadowColor: skinShadow,
      highlightColor: skinHighlight,
    );

    // --- Eyes (spec §7.1) ---
    _drawEyes(canvas, px, eyePattern);

    // --- Blush (spec §7 Blush) ---
    // L base: (12,13)(13,13), L soft: (11,13)(14,13), R mirror
    _drawPixels(canvas, CharacterPalette.blushBase, [[12,13],[13,13],[18,13],[19,13]], px);
    _drawPixels(canvas, CharacterPalette.blushSoft, [[11,13],[14,13],[17,13],[20,13]], px);

    // --- Mouth (spec §7.2) ---
    _drawMouth(canvas, px);

    // --- Neck & Shoulders Skin (spec §9) ---
    // neck base: (14,14)(15,14)(16,14)(17,14)(15,15)(16,15), shadow: (17,14)
    _drawPixels(canvas, skinBase, [
      [14,14],[15,14],[16,14],[17,14],[15,15],[16,15],
    ], px);
    _drawPixels(canvas, skinShadow, [[17,14]], px);

    // --- Default body (shirt) - will be overridden by top equipment ---
    _drawBody(canvas, px, CharacterPalette.defaultShirtBase);

    // --- Arms Skin (spec §9) ---
    // L arm base: (9,17)(10,17)...(9,22)(10,22), shadow: (10,20)(10,21)(10,22)
    final armSkinBase = <List<int>>[
      [9,17],[10,17],[9,18],[10,18],[9,19],[10,19],
      [9,20],[10,20],[9,21],[10,21],[9,22],[10,22],
    ];
    final armSkinShadow = <List<int>>[[10,20],[10,21],[10,22]];
    // R arm mirror: x' = 31 - x
    final armSkinBaseR = <List<int>>[
      [21,17],[22,17],[21,18],[22,18],[21,19],[22,19],
      [21,20],[22,20],[21,21],[22,21],[21,22],[22,22],
    ];
    final armSkinShadowR = <List<int>>[[21,20],[21,21],[21,22]];
    _paintLayer(canvas, px,
      base: armSkinBase,
      shadow: armSkinShadow,
      highlight: [],
      baseColor: skinBase,
      shadowColor: skinShadow,
      highlightColor: skinHighlight,
    );
    _paintLayer(canvas, px,
      base: armSkinBaseR,
      shadow: armSkinShadowR,
      highlight: [],
      baseColor: skinBase,
      shadowColor: skinShadow,
      highlightColor: skinHighlight,
    );

    // --- Default pants ---
    _drawLegs(canvas, px, CharacterPalette.defaultPantsBase,
      CharacterPalette.defaultPantsShadow, CharacterPalette.defaultPantsHighlight, false, skinBase);

    // --- Default shoes ---
    _drawShoes(canvas, px, CharacterPalette.defaultShoesBase,
      CharacterPalette.defaultShoesShadow, CharacterPalette.defaultShoesHighlight);
  }

  void _drawHair(Canvas canvas, double px, String hairStyle) {
    // All hair styles include short as base, then extend
    // spec §8 short hair
    final shortOutline = <List<int>>[
      // row 2 top outline
      [10,2],[11,2],[12,2],[13,2],[14,2],[15,2],[16,2],[17,2],[18,2],[19,2],[20,2],[21,2],
      // row 3 sides
      [10,3],[11,3],[20,3],[21,3],
      // row 4 sides
      [9,4],[10,4],[21,4],[22,4],
    ];
    final shortBase = <List<int>>[
      // row 3 front fringe
      [11,3],[12,3],[13,3],[14,3],[15,3],[16,3],[17,3],[18,3],[19,3],[20,3],
      // row 4 fringe with split
      [12,4],[13,4],[14,4],[17,4],[18,4],[19,4],
    ];
    final shortHighlight = <List<int>>[[13,3],[14,3]];

    _drawPixels(canvas, CharacterPalette.hairOutline, shortOutline, px);
    _drawPixels(canvas, CharacterPalette.hairBase, shortBase, px);
    _drawPixels(canvas, CharacterPalette.hairHighlight, shortHighlight, px);

    if (hairStyle == 'long') {
      // spec §8 long: short + side locks
      final longOutline = <List<int>>[
        [9,5],[9,6],[9,7],[22,5],[22,6],[22,7],
        [10,8],[10,9],[21,8],[21,9],
      ];
      final longBase = <List<int>>[
        [10,5],[10,6],[10,7],[21,5],[21,6],[21,7],
      ];
      final longHighlight = <List<int>>[[10,5],[21,5]];
      _drawPixels(canvas, CharacterPalette.hairOutline, longOutline, px);
      _drawPixels(canvas, CharacterPalette.hairBase, longBase, px);
      _drawPixels(canvas, CharacterPalette.hairHighlight, longHighlight, px);
    } else if (hairStyle == 'curly') {
      // spec §8 curly: wavy outline + volume
      final curlyOutline = <List<int>>[
        [10,2],[13,2],[16,2],[19,2],[11,1],[14,1],[17,1],[20,1],
        [9,3],[9,4],[22,3],[22,4],[9,5],[22,5],
      ];
      final curlyBase = <List<int>>[
        [10,3],[11,3],[12,3],[13,3],[14,3],[15,3],[16,3],[17,3],[18,3],[19,3],[20,3],[21,3],
        [10,4],[11,4],[12,4],[19,4],[20,4],[21,4],
      ];
      final curlyHighlight = <List<int>>[[11,2],[14,2],[17,2],[20,2]];
      _drawPixels(canvas, CharacterPalette.hairOutline, curlyOutline, px);
      _drawPixels(canvas, CharacterPalette.hairBase, curlyBase, px);
      _drawPixels(canvas, CharacterPalette.hairHighlight, curlyHighlight, px);
    }
  }

  void _drawEyes(Canvas canvas, double px, Map<String, List<List<int>>> ep) {
    _drawPixels(canvas, CharacterPalette.eyeOutline, ep['outlineL'] ?? [], px);
    _drawPixels(canvas, CharacterPalette.eyeOutline, ep['outlineR'] ?? [], px);
    _drawPixels(canvas, CharacterPalette.eyeWhite, ep['whiteL'] ?? [], px);
    _drawPixels(canvas, CharacterPalette.eyeWhite, ep['whiteR'] ?? [], px);
    _drawPixels(canvas, CharacterPalette.eyeOutline, ep['eyelashL'] ?? [], px);
    _drawPixels(canvas, CharacterPalette.eyeOutline, ep['eyelashR'] ?? [], px);
    _drawPixels(canvas, CharacterPalette.eyeShine, ep['shineL'] ?? [], px);
    _drawPixels(canvas, CharacterPalette.eyeShine, ep['shineR'] ?? [], px);
  }

  void _drawMouth(Canvas canvas, double px) {
    // Default: smile. mouth style can be extended via character data in future.
    // spec §7.2: smile: (14,15)(17,15) + (15,16)(16,16) with outer corners darker
    _drawPixels(canvas, CharacterPalette.mouthDark, [[14,15],[17,15]], px);
    _drawPixels(canvas, CharacterPalette.mouthLine, [[15,16],[16,16]], px);
  }

  void _drawBody(Canvas canvas, double px, Color color) {
    // Torso bounding box: cols 11-20, rows 17-23 (spec §5 Torso)
    final bodyPixels = <List<int>>[
      ..._row(11, 20, 17),
      ..._row(11, 20, 18),
      ..._row(11, 20, 19),
      ..._row(11, 20, 20),
      ..._row(11, 20, 21),
      ..._row(11, 20, 22),
      ..._row(12, 19, 23), // hem slightly narrower
    ];
    _drawPixels(canvas, color, bodyPixels, px);
  }

  void _drawLegs(
    Canvas canvas,
    double px,
    Color baseColor,
    Color shadowColor,
    Color highlightColor,
    bool isShorts, [
    Color? skinBase,
  ]) {
    final resolvedSkin = skinBase ?? CharacterPalette.skinFairBase;
    // spec: bottom bounding box cols 11-20, rows 22-28
    // belt row 22, hip 23-24, legs L: (12,25-28)(13,25-28)(14,25-28), R: (17,25-28)(18,25-28)(19,25-28)
    final beltHip = <List<int>>[
      ..._row(11, 20, 22), // belt
      ..._row(11, 20, 23), // hip
      ..._row(11, 20, 24),
    ];
    _drawPixels(canvas, baseColor, beltHip, px);

    if (isShorts) {
      // 1 row of legs only
      _drawPixels(canvas, baseColor, [
        ..._row(12, 14, 25), ..._row(17, 19, 25),
      ], px);
      // Expose skin rows 26-28
      _drawPixels(canvas, resolvedSkin, [
        ..._row(12, 14, 26), ..._row(17, 19, 26),
        ..._row(12, 14, 27), ..._row(17, 19, 27),
        ..._row(12, 14, 28), ..._row(17, 19, 28),
      ], px);
    } else {
      // Full legs rows 25-28
      final legsPixels = <List<int>>[
        ..._row(12, 14, 25), ..._row(17, 19, 25),
        ..._row(12, 14, 26), ..._row(17, 19, 26),
        ..._row(12, 14, 27), ..._row(17, 19, 27),
        ..._row(12, 14, 28), ..._row(17, 19, 28),
      ];
      _drawPixels(canvas, baseColor, legsPixels, px);
      // Shadow on right side of each leg
      _drawPixels(canvas, shadowColor, [
        [14,25],[14,26],[14,27],[14,28],
        [19,25],[19,26],[19,27],[19,28],
      ], px);
      // Highlight on left front of each leg
      _drawPixels(canvas, highlightColor, [
        [12,25],[12,26],[17,25],
      ], px);
    }
  }

  void _drawShoes(Canvas canvas, double px, Color baseColor, Color shadowColor, Color highlightColor) {
    // Left foot: cols 11-13, rows 29-30. Right foot: cols 18-20 (mirror).
    // spec shoes: upper row 29, toe row 30
    _drawPixels(canvas, baseColor, [
      [11,29],[12,29],[13,29], // left upper
      [18,29],[19,29],[20,29], // right upper
    ], px);
    _drawPixels(canvas, shadowColor, [
      [11,30],[12,30],[13,30], // left sole
      [18,30],[19,30],[20,30], // right sole
    ], px);
    _drawPixels(canvas, highlightColor, [
      [11,29],[18,29], // left/right highlight on upper
    ], px);
  }

  void _drawEquipment(Canvas canvas, double px) {
    final c = character;
    if (c == null) return;

    if (c.top != null) {
      _drawTopEquipment(canvas, px, c.top!.assetKey, c.top!.rarity);
    }
    if (c.bottom != null) {
      _drawBottomEquipment(canvas, px, c.bottom!.assetKey, c.bottom!.rarity);
    }
    if (c.shoes != null) {
      _drawShoesEquipment(canvas, px, c.shoes!.assetKey, c.shoes!.rarity);
    }
    if (c.accessory != null) {
      drawAccessoryOnCharacter(
        canvas, px,
        c.accessory!.assetKey,
        c.accessory!.rarity,
        accessoryAnimValue,
      );
    }
    if (c.hat != null) {
      _drawHatEquipment(canvas, px, c.hat!.assetKey, c.hat!.rarity);
    }
  }

  void _drawHatEquipment(Canvas canvas, double px, String assetKey, String rarity) {
    switch (assetKey) {
      case 'hat/cap.png':
        // spec §10 hat/cap — red baseball cap
        // base crown #E53935
        _drawPixels(canvas, const Color(0xFFE53935), [
          ..._row(10, 21, 2),
          ..._row(9, 22, 3),
          [9,4],[10,4],[11,4],[12,4],[19,4],[20,4],[21,4],[22,4],
        ], px);
        // brim shadow #B71C1C
        _drawPixels(canvas, const Color(0xFFB71C1C), [
          [7,5],[8,5],[9,5],[10,5],[11,5],[12,5],[13,5],
          [7,6],[8,6],[9,6],
        ], px);
        // brim base #C62828
        _drawPixels(canvas, const Color(0xFFC62828), [
          [14,5],[15,5],[16,5],[17,5],[18,5],
        ], px);
        // outline #8B1515
        _drawPixels(canvas, const Color(0xFF8B1515), [
          ..._row(10, 21, 1),
          [8,2],[23,2],[8,3],[23,3],
          [6,5],[14,6],
        ], px);
        // highlight #FFCDD2
        _drawPixels(canvas, const Color(0xFFFFCDD2), [
          [11,3],[12,3],[13,3],[9,5],
        ], px);
        // logo dot #FFFFFF
        _drawPixels(canvas, Colors.white, [[15,3]], px);
        break;

      case 'hat/beanie.png':
      case 'hat/pink_beanie.png':
        final isP = assetKey.contains('pink');
        final beanieMain = isP ? const Color(0xFFFF80AB) : const Color(0xFF1976D2);
        final beanieLight = isP ? const Color(0xFFFFCDD2) : const Color(0xFF90CAF9);
        // pom-pom white
        _drawPixels(canvas, Colors.white, [
          [14,0],[15,0],[16,0],[17,0],
          [13,1],[14,1],[15,1],[16,1],[17,1],[18,1],
        ], px);
        _drawPixels(canvas, Colors.white.withAlpha(180), [[14,0]], px); // highlight
        // shadow on pom edges
        _drawPixels(canvas, beanieLight, [[13,1],[18,1]], px);
        // crown base
        _drawPixels(canvas, beanieMain, [
          ..._row(11, 20, 1),
          ..._row(10, 21, 2),
          ..._row(9, 22, 3),
          ..._row(9, 22, 4),
        ], px);
        // brim shadow
        _drawPixels(canvas, beanieMain.withAlpha(200), [
          ..._row(9, 22, 5),
        ], px);
        // ribbed stripe
        _drawPixels(canvas, beanieLight, [
          [11,2],[13,2],[15,2],[17,2],[19,2],
          [11,4],[13,4],[15,4],[17,4],[19,4],
        ], px);
        break;

      case 'hat/headband.png':
        // spec §10 hat/headband — yellow headband + right-side bow
        // band base #FFD600
        _drawPixels(canvas, const Color(0xFFFFD600), [
          ..._row(10, 21, 3),
          ..._row(10, 21, 4),
        ], px);
        // ribbon bow #FF8F00
        _drawPixels(canvas, const Color(0xFFFF8F00), [
          [20,1],[21,1],[22,1],[23,1],
          [20,2],[21,2],[22,2],[23,2],
        ], px);
        // bow outline (darker)
        _drawPixels(canvas, const Color(0xFFB58900), [
          [19,1],[24,1],[19,2],[24,2],[20,3],[21,3],[22,3],[23,3],
        ], px);
        // bow knot accent
        _drawPixels(canvas, const Color(0xFF8D6000), [[21,2],[22,2]], px);
        // band highlight #FFF59D
        _drawPixels(canvas, const Color(0xFFFFF59D), [[11,3],[12,3]], px);
        break;

      case 'hat/fedora.png':
        // spec §10 hat/fedora — brown wide-brim fedora
        // crown base #795548
        _drawPixels(canvas, const Color(0xFF795548), [
          ..._row(12, 19, 1),
          ..._row(11, 20, 2),
          ..._row(11, 20, 3),
        ], px);
        // dimple shadow #5D4037
        _drawPixels(canvas, const Color(0xFF5D4037), [
          [15,1],[16,1],[15,2],[16,2],
        ], px);
        // brim base #5D4037
        _drawPixels(canvas, const Color(0xFF5D4037), [
          [8,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],
          [16,4],[17,4],[18,4],[19,4],[20,4],[21,4],[22,4],[23,4],
        ], px);
        // brim shadow #3E2723
        _drawPixels(canvas, const Color(0xFF3E2723), [[8,5],[9,5],[22,5],[23,5]], px);
        // band #FFCC80
        _drawPixels(canvas, const Color(0xFFFFCC80), [
          ..._row(11, 20, 3),
        ], px);
        // accent knot #E65100
        _drawPixels(canvas, const Color(0xFFE65100), [[15,3],[16,3]], px);
        // outline #3E2723
        _drawPixels(canvas, const Color(0xFF3E2723), [
          ..._row(12, 19, 0),
          [10,1],[21,1],[10,2],[21,2],
        ], px);
        // highlight #A1887F
        _drawPixels(canvas, const Color(0xFFA1887F), [[12,2],[13,2],[20,3]], px);
        break;

      case 'hat/beret.png':
        // spec §10 hat/beret — dark red beret tilted left
        // base #8D1515
        _drawPixels(canvas, const Color(0xFF8D1515), [
          ..._row(9, 21, 2),
          ..._row(8, 21, 3),
          [8,4],[9,4],[10,4],[11,4],[12,4],
        ], px);
        // stem
        _drawPixels(canvas, const Color(0xFF8D1515), [[9,1],[10,1]], px);
        // stem outline
        _drawPixels(canvas, const Color(0xFF5C0F0F), [[8,1],[11,1],[9,0],[10,0]], px);
        // highlight #B71C1C
        _drawPixels(canvas, const Color(0xFFB71C1C), [
          [11,2],[12,2],[13,2],[9,1],
        ], px);
        // outline #5C0F0F
        _drawPixels(canvas, const Color(0xFF5C0F0F), [
          [8,2],[22,2],[7,3],[22,3],[7,4],[13,4],
        ], px);
        break;

      case 'hat/crown.png':
        // spec §10 hat/crown — golden crown (EPIC)
        final goldColor = rarity == 'EPIC'
            ? const Color(0xFFFFD700)
            : const Color(0xFFE6B800);
        // band
        _drawPixels(canvas, goldColor, [
          ..._row(10, 21, 3),
          ..._row(10, 21, 4),
        ], px);
        // points
        _drawPixels(canvas, goldColor, [
          [10,2],[11,2],              // point 1
          [13,1],[13,2],[14,1],        // point 2
          [15,0],[16,0],[15,1],[16,1],[15,2],[16,2], // center high point
          [17,1],[18,1],[18,2],        // point 4
          [20,2],[21,2],              // point 5
        ], px);
        // jewels
        _drawPixels(canvas, const Color(0xFFE91E63), [[14,4]], px); // ruby
        _drawPixels(canvas, const Color(0xFF2196F3), [[17,4]], px); // sapphire
        // highlight
        _drawPixels(canvas, Colors.white, [[10,3],[15,0],[21,3]], px);
        // outline #B8860B
        _drawPixels(canvas, const Color(0xFFB8860B), [
          [9,3],[22,3],[9,2],[22,2],
          [14,0],[17,0],[12,1],[19,1],
        ], px);
        break;

      default:
        // Generic grey cap
        _drawPixels(canvas, const Color(0xFF9E9E9E), [
          ..._row(10, 21, 2),
          ..._row(9, 22, 3),
          ..._row(9, 22, 4),
        ], px);
    }
  }

  void _drawTopEquipment(Canvas canvas, double px, String assetKey, String rarity) {
    switch (assetKey) {
      case 'top/white_tee.png':
        // spec §11 top/white_tee
        // body base #F5F5F5
        _drawPixels(canvas, const Color(0xFFF5F5F5), [
          ..._row(11, 20, 17),
          ..._row(11, 20, 18),
          ..._row(11, 20, 19),
          ..._row(11, 20, 20),
          ..._row(11, 20, 21),
          ..._row(11, 20, 22),
          ..._row(12, 19, 23),
        ], px);
        // sleeves
        _drawPixels(canvas, const Color(0xFFF5F5F5), [
          [9,18],[10,18],[9,19],[10,19],[9,20],[10,20],
          [21,18],[22,18],[21,19],[22,19],[21,20],[22,20],
        ], px);
        // body shadow #DCDCDC
        _drawPixels(canvas, const Color(0xFFDCDCDC), [
          [20,19],[20,20],[20,21],[20,22],
          [11,23],[19,23],
        ], px);
        // highlight #FFFFFF
        _drawPixels(canvas, Colors.white, [[12,17],[13,17],[11,18]], px);
        // outline #A9A9A9
        _drawPixels(canvas, const Color(0xFFA9A9A9), [
          [11,17],[20,17],
          [10,18],[10,19],[10,20],[10,21],[10,22],
          [21,18],[21,19],[21,20],[21,21],[21,22],
          [12,23],[19,23],
        ], px);
        // collar accent #CCCCCC
        _drawPixels(canvas, const Color(0xFFCCCCCC), [
          [14,17],[15,17],[16,17],[17,17],[15,18],[16,18],
        ], px);
        break;

      case 'top/striped_tee.png':
        // spec §11 top/striped_tee — blue/white stripes per row
        // white_tee body footprint, blue on rows 17,19,21,23
        for (int row = 17; row <= 23; row++) {
          final isBlue = (row % 2 == 1);
          final color = isBlue ? const Color(0xFF1976D2) : Colors.white;
          final start = row == 23 ? 12 : 11;
          final end = row == 23 ? 19 : 20;
          _drawPixels(canvas, color, _row(start, end, row), px);
        }
        // sleeves same stripe rule
        for (int row = 18; row <= 22; row++) {
          final color = (row % 2 == 0) ? Colors.white : const Color(0xFF1976D2);
          _drawPixels(canvas, color, [[9,row],[10,row],[21,row],[22,row]], px);
        }
        // shadow (darker blue on right col of blue rows)
        _drawPixels(canvas, const Color(0xFF0D47A1), [
          [20,17],[20,19],[20,21],
        ], px);
        // highlight
        _drawPixels(canvas, Colors.white, [[12,18]], px);
        // collar
        _drawPixels(canvas, Colors.white, [[15,17],[16,17]], px);
        break;

      case 'top/check_shirt.png':
        // spec §11 top/check_shirt — 2x2 tile red/cream checkerboard
        const red = Color(0xFFD32F2F);
        const cream = Color(0xFFFFF8E1);
        const darkRed = Color(0xFFB71C1C);
        for (int row = 17; row <= 23; row++) {
          final start = row == 23 ? 12 : 11;
          final end = row == 23 ? 19 : 20;
          for (int col = start; col <= end; col++) {
            final isRed = ((col - 11) ~/ 2 + (row - 17) ~/ 2) % 2 == 0;
            _drawPixels(canvas, isRed ? red : cream, [[col, row]], px);
          }
        }
        // collar
        _drawPixels(canvas, darkRed, [
          [13,17],[14,17],[17,17],[18,17],[14,18],[17,18],
        ], px);
        _drawPixels(canvas, cream, [[15,18],[16,18]], px);
        // buttons
        _drawPixels(canvas, const Color(0xFF8B1515), [
          [15,19],[15,21],[15,23],
        ], px);
        // sleeves same pattern
        for (int row = 17; row <= 22; row++) {
          for (final col in [9, 10, 21, 22]) {
            final isRed = ((col - 9) ~/ 2 + (row - 17) ~/ 2) % 2 == 0;
            _drawPixels(canvas, isRed ? red : cream, [[col, row]], px);
          }
        }
        break;

      case 'top/sleeveless.png':
        // spec §11 top/sleeveless — green, narrow shoulders
        _drawPixels(canvas, const Color(0xFF388E3C), [
          ..._row(12, 19, 17),
          ..._row(12, 19, 18),
          ..._row(12, 19, 19),
          ..._row(12, 19, 20),
          ..._row(12, 19, 21),
          ..._row(12, 19, 22),
          ..._row(13, 18, 23),
        ], px);
        // straps only: (13,17)(14,17)(17,17)(18,17), skin in center (15,17)(16,17)
        _drawPixels(canvas, const Color(0xFF388E3C), [[13,17],[14,17],[17,17],[18,17]], px);
        final skinBase = _getSkinTones(character?.skinTone ?? 'fair')[1];
        _drawPixels(canvas, skinBase, [[15,17],[16,17]], px);
        // no sleeves: arm skin already drawn
        // shadow
        _drawPixels(canvas, const Color(0xFF1B5E20), [
          [19,19],[19,20],[19,21],[19,22],[18,23],
        ], px);
        // highlight
        _drawPixels(canvas, const Color(0xFF81C784), [[13,17],[14,17]], px);
        // outline
        _drawPixels(canvas, const Color(0xFF1B5E20), [
          [12,17],[19,17],[11,18],[11,19],[11,20],[11,21],[11,22],
          [20,18],[20,19],[20,20],[20,21],[20,22],
        ], px);
        break;

      case 'top/hoodie.png':
        // spec §11 top/hoodie — blue hoodie
        _drawPixels(canvas, const Color(0xFF1565C0), [
          ..._row(10, 21, 17),
          ..._row(10, 21, 18),
          ..._row(11, 20, 19),
          ..._row(11, 20, 20),
          ..._row(11, 20, 21),
          ..._row(11, 20, 22),
          ..._row(12, 19, 23),
        ], px);
        // hood volume sides
        _drawPixels(canvas, const Color(0xFF1565C0), [
          [8,13],[9,13],[22,13],[23,13],
          [8,14],[9,14],[22,14],[23,14],
          [8,15],[9,15],[22,15],[23,15],[10,15],[21,15],
          ..._row(10, 21, 16),
        ], px);
        // hood shadow
        _drawPixels(canvas, const Color(0xFF0D47A1), [
          [9,14],[9,15],[22,14],[22,15],[15,16],[16,16],
        ], px);
        // drawstrings
        _drawPixels(canvas, Colors.white, [[14,16],[15,16],[16,16],[17,16]], px);
        _drawPixels(canvas, const Color(0xFF5D4037), [[14,17],[17,17]], px);
        // pouch pocket
        _drawPixels(canvas, const Color(0xFF1976D2), [
          ..._row(13, 18, 20), [13,21],[18,21],
        ], px);
        // sleeve cuffs
        _drawPixels(canvas, const Color(0xFF1565C0), [
          [9,21],[10,21],[21,21],[22,21],
          [9,22],[10,22],[21,22],[22,22],
        ], px);
        // highlight
        _drawPixels(canvas, const Color(0xFF90CAF9), [[11,17],[12,17],[13,17]], px);
        // outline
        _drawPixels(canvas, const Color(0xFF0A3880), [
          [10,17],[21,17],[9,18],[22,18],[9,19],[22,19],[9,20],[22,20],
          [9,21],[22,21],[9,22],[22,22],
        ], px);
        break;

      case 'top/cardigan.png':
        // spec §11 top/cardigan — brown open cardigan + yellow inner
        // cardigan panels (L/R only)
        const cardiganBase = Color(0xFF8D6E63);
        for (int row = 17; row <= 23; row++) {
          if (row < 23) {
            _drawPixels(canvas, cardiganBase, [
              [11,row],[12,row],[13,row],[18,row],[19,row],[20,row],
            ], px);
          } else {
            _drawPixels(canvas, cardiganBase, [[12,23],[13,23],[18,23],[19,23]], px);
          }
        }
        // inner shirt #FFF9C4
        for (int row = 17; row <= 23; row++) {
          _drawPixels(canvas, const Color(0xFFFFF9C4), _row(14, 17, row), px);
        }
        // buttons #5D4037
        _drawPixels(canvas, const Color(0xFF5D4037), [[15,19],[15,21],[15,23]], px);
        // sleeves
        _drawPixels(canvas, cardiganBase, [
          [9,17],[10,17],[21,17],[22,17],
          [9,18],[10,18],[21,18],[22,18],
          [9,19],[10,19],[21,19],[22,19],
          [9,20],[10,20],[21,20],[22,20],
          [9,21],[10,21],[21,21],[22,21],
          [9,22],[10,22],[21,22],[22,22],
        ], px);
        // shadow on inner edge of cardigan panels
        _drawPixels(canvas, const Color(0xFF6D4C41), [
          [13,18],[13,19],[13,20],[13,21],[13,22],
          [18,18],[18,19],[18,20],[18,21],[18,22],
        ], px);
        // highlight
        _drawPixels(canvas, const Color(0xFFBCAAA4), [[11,17],[12,17]], px);
        // outline
        _drawPixels(canvas, const Color(0xFF4E342E), [
          [11,17],[20,17],[10,18],[10,19],[10,20],[10,21],[10,22],
          [21,18],[21,19],[21,20],[21,21],[21,22],
        ], px);
        break;

      case 'top/tuxedo.png':
        // spec §11 top/tuxedo — EPIC black tuxedo + white shirt + red bowtie
        const jacketBase = Color(0xFF212121);
        // jacket panels
        for (int row = 17; row <= 23; row++) {
          if (row < 23) {
            _drawPixels(canvas, jacketBase, [
              [11,row],[12,row],[13,row],[18,row],[19,row],[20,row],
            ], px);
          } else {
            _drawPixels(canvas, jacketBase, [[11,23],[19,23]], px);
          }
        }
        // white shirt center
        for (int row = 17; row <= 23; row++) {
          _drawPixels(canvas, Colors.white, _row(14, 17, row), px);
        }
        // collar/lapel
        _drawPixels(canvas, const Color(0xFF0A0A0A), [
          [13,17],[18,17],[13,18],[18,18],
        ], px);
        // bowtie
        _drawPixels(canvas, const Color(0xFFFF1744), [
          [14,17],[15,17],[16,17],[17,17],[14,18],[17,18],
        ], px);
        _drawPixels(canvas, const Color(0xFFB71C1C), [[15,18],[16,18]], px);
        // buttons (double-breasted)
        _drawPixels(canvas, const Color(0xFFBDBDBD), [
          [13,20],[18,20],[13,22],[18,22],
        ], px);
        // sleeves
        _drawPixels(canvas, jacketBase, [
          [9,17],[10,17],[21,17],[22,17],
          [9,18],[10,18],[21,18],[22,18],
          [9,19],[10,19],[21,19],[22,19],
          [9,20],[10,20],[21,20],[22,20],
          [9,21],[10,21],[21,21],[22,21],
          [9,22],[10,22],[21,22],[22,22],
        ], px);
        // cuff white line
        _drawPixels(canvas, Colors.white, [[9,22],[10,22],[21,22],[22,22]], px);
        // shadow
        _drawPixels(canvas, Colors.black, [[13,22],[13,23],[18,22],[18,23]], px);
        // highlight
        _drawPixels(canvas, const Color(0xFF424242), [[11,17],[20,17]], px);
        break;

      default:
        _drawBody(canvas, px, CharacterPalette.defaultShirtBase);
    }
  }

  void _drawBottomEquipment(Canvas canvas, double px, String assetKey, String rarity) {
    switch (assetKey) {
      case 'bottom/jeans.png':
        // spec §12 bottom/jeans — dark blue denim
        const base = Color(0xFF1565C0);
        // belt + hip
        _drawPixels(canvas, base, [
          ..._row(11, 20, 22), ..._row(11, 20, 23), ..._row(11, 20, 24),
        ], px);
        // legs L + R
        _drawPixels(canvas, base, [
          ..._row(12, 14, 25), ..._row(17, 19, 25),
          ..._row(12, 14, 26), ..._row(17, 19, 26),
          ..._row(12, 14, 27), ..._row(17, 19, 27),
          ..._row(12, 14, 28), ..._row(17, 19, 28),
        ], px);
        // crotch gap shadow
        _drawPixels(canvas, const Color(0xFF0D47A1), [
          [15,25],[15,26],[15,27],[15,28],[16,25],[16,26],[16,27],[16,28],
        ], px);
        // shadow on right cols
        _drawPixels(canvas, const Color(0xFF0D47A1), [
          [20,23],[20,24],[14,25],[14,26],[14,27],[14,28],
          [19,25],[19,26],[19,27],[19,28],
        ], px);
        // highlight
        _drawPixels(canvas, const Color(0xFF42A5F5), [
          [11,22],[12,22],[11,23],[12,25],[12,26],[17,25],
        ], px);
        // outline
        _drawPixels(canvas, const Color(0xFF0A3880), [
          [11,22],[20,22],[11,23],[20,23],[11,28],[20,28],
          [11,29],[12,29],[19,29],[20,29],
        ], px);
        // pockets
        _drawPixels(canvas, const Color(0xFF0A3880), [
          [11,23],[20,23],[11,24],[12,24],[19,24],[20,24],
        ], px);
        // belt buckle
        _drawPixels(canvas, const Color(0xFFFFD700), [[15,22]], px);
        break;

      case 'bottom/shorts.png':
        // spec §12 bottom/shorts — khaki shorts
        const base = Color(0xFFC8A96E);
        _drawPixels(canvas, base, [
          ..._row(11, 20, 22), ..._row(11, 20, 23), ..._row(11, 20, 24),
          ..._row(12, 14, 25), ..._row(17, 19, 25),
        ], px);
        final skinBase = _getSkinTones(character?.skinTone ?? 'fair')[1];
        final skinShadow = _getSkinTones(character?.skinTone ?? 'fair')[0];
        _drawPixels(canvas, skinBase, [
          ..._row(12, 14, 26), ..._row(17, 19, 26),
          ..._row(12, 14, 27), ..._row(17, 19, 27),
          ..._row(12, 14, 28), ..._row(17, 19, 28),
        ], px);
        // skin shadow
        _drawPixels(canvas, skinShadow, [
          [14,26],[14,27],[14,28],[19,26],[19,27],[19,28],
        ], px);
        // shorts shadow
        _drawPixels(canvas, const Color(0xFF8B7A50), [
          [20,23],[20,24],[14,25],[19,25],
        ], px);
        // highlight
        _drawPixels(canvas, const Color(0xFFE6D4A8), [[11,22],[12,22]], px);
        // drawstring
        _drawPixels(canvas, const Color(0xFF6D5F3E), [[15,22],[16,22]], px);
        // outline
        _drawPixels(canvas, const Color(0xFF6D5F3E), [
          [11,22],[20,22],[11,25],[20,25],
        ], px);
        break;

      case 'bottom/chinos.png':
        // spec §12 bottom/chinos — beige chinos
        const base = Color(0xFFD4B896);
        _drawPixels(canvas, base, [
          ..._row(11, 20, 22), ..._row(11, 20, 23), ..._row(11, 20, 24),
          ..._row(12, 14, 25), ..._row(17, 19, 25),
          ..._row(12, 14, 26), ..._row(17, 19, 26),
          ..._row(12, 14, 27), ..._row(17, 19, 27),
          ..._row(12, 14, 28), ..._row(17, 19, 28),
        ], px);
        // shadow
        _drawPixels(canvas, const Color(0xFFA68B5F), [
          [20,23],[20,24],[14,25],[14,26],[14,27],[14,28],
          [19,25],[19,26],[19,27],[19,28],
          [15,25],[15,26],[15,27],[15,28],[16,25],[16,26],[16,27],[16,28],
        ], px);
        // highlight
        _drawPixels(canvas, const Color(0xFFEAD3AE), [
          [11,22],[12,22],[12,25],[17,25],
        ], px);
        // outline
        _drawPixels(canvas, const Color(0xFF8B7345), [
          [11,22],[20,22],[11,28],[20,28],
        ], px);
        // belt loops
        _drawPixels(canvas, const Color(0xFF8B7345), [[13,22],[17,22]], px);
        // center pleat lines
        _drawPixels(canvas, const Color(0xFFA68B5F), [
          [13,25],[13,26],[13,27],[13,28],[18,25],[18,26],[18,27],[18,28],
        ], px);
        break;

      case 'bottom/skirt.png':
        // spec §12 bottom/skirt — pink A-line skirt
        // ruffle hem first (skirt then shoes on top)
        _drawPixels(canvas, const Color(0xFFF48FB1), [
          [9,29],[10,29],[11,29],[20,29],[21,29],[22,29],
        ], px);
        // A-line expansion
        _drawPixels(canvas, const Color(0xFFEC407A), [
          ..._row(12, 19, 22),
          ..._row(12, 19, 23),
          ..._row(11, 20, 24), ..._row(11, 20, 25),
          ..._row(10, 21, 26), ..._row(10, 21, 27),
          ..._row(9, 22, 28),
        ], px);
        // pleat lines (shadow)
        _drawPixels(canvas, const Color(0xFFAD1457), [
          [13,24],[16,24],[19,24],
          [13,25],[16,25],[19,25],
          [13,26],[16,26],[19,26],
          [13,27],[16,27],[19,27],
          [13,28],[16,28],[19,28],
        ], px);
        // highlight
        _drawPixels(canvas, const Color(0xFFF8BBD0), [
          [12,22],[13,22],[12,27],
        ], px);
        // outline
        _drawPixels(canvas, const Color(0xFF880E4F), [
          [12,22],[19,22],[9,28],[22,28],
        ], px);
        break;

      case 'bottom/cargo.png':
        // spec §12 bottom/cargo — olive cargo pants (2px wider)
        const base = Color(0xFF558B2F);
        _drawPixels(canvas, base, [
          ..._row(10, 21, 22), ..._row(10, 21, 23), ..._row(10, 21, 24),
          ..._row(10, 14, 25), ..._row(17, 21, 25),
          ..._row(10, 14, 26), ..._row(17, 21, 26),
          ..._row(10, 14, 27), ..._row(17, 21, 27),
          ..._row(10, 14, 28), ..._row(17, 21, 28),
        ], px);
        // cargo pockets
        _drawPixels(canvas, const Color(0xFF33691E), [
          [10,24],[11,24],[10,25],[11,25],[10,26],[11,26],
          [20,24],[21,24],[20,25],[21,25],[20,26],[21,26],
        ], px);
        // pocket buttons
        _drawPixels(canvas, const Color(0xFF8D6E63), [[11,25],[20,25]], px);
        // shadow
        _drawPixels(canvas, const Color(0xFF2E5420), [
          [21,23],[21,24],[14,25],[14,26],[14,27],[14,28],
          [17,25],[17,26],[17,27],[17,28],
          [15,25],[15,26],[15,27],[15,28],[16,25],[16,26],[16,27],[16,28],
        ], px);
        // highlight
        _drawPixels(canvas, const Color(0xFF8BC34A), [
          [11,22],[12,22],[11,25],[20,25],
        ], px);
        // outline
        _drawPixels(canvas, const Color(0xFF1B3D0E), [
          [10,22],[21,22],[10,28],[21,28],
        ], px);
        break;

      case 'bottom/golden_pants.png':
        // spec §12 bottom/golden_pants — EPIC gold pants (jeans footprint + gold)
        const base = Color(0xFFFFD700);
        _drawPixels(canvas, base, [
          ..._row(11, 20, 22), ..._row(11, 20, 23), ..._row(11, 20, 24),
          ..._row(12, 14, 25), ..._row(17, 19, 25),
          ..._row(12, 14, 26), ..._row(17, 19, 26),
          ..._row(12, 14, 27), ..._row(17, 19, 27),
          ..._row(12, 14, 28), ..._row(17, 19, 28),
        ], px);
        // shadow
        _drawPixels(canvas, const Color(0xFFFF8F00), [
          [20,23],[20,24],[14,25],[14,26],[14,27],[14,28],
          [19,25],[19,26],[19,27],[19,28],
          [15,25],[15,26],[15,27],[15,28],[16,25],[16,26],[16,27],[16,28],
        ], px);
        // highlight
        _drawPixels(canvas, const Color(0xFFFFFDE7), [
          [11,22],[12,22],[11,23],[12,25],[17,25],
        ], px);
        // sparkle dots
        _drawPixels(canvas, Colors.white, [
          [13,23],[18,24],[14,26],[18,28],
        ], px);
        // outline
        _drawPixels(canvas, const Color(0xFFB8860B), [
          [11,22],[20,22],[11,28],[20,28],
        ], px);
        break;

      default:
        final skinBase = _getSkinTones(character?.skinTone ?? 'fair')[1];
        _drawLegs(canvas, px,
          CharacterPalette.defaultPantsBase,
          CharacterPalette.defaultPantsShadow,
          CharacterPalette.defaultPantsHighlight,
          false, skinBase);
    }
  }

  void _drawShoesEquipment(Canvas canvas, double px, String assetKey, String rarity) {
    switch (assetKey) {
      case 'shoes/sneakers.png':
        // spec §12 shoes/sneakers — blue sneakers
        // left
        _drawPixels(canvas, const Color(0xFF42A5F5), [[11,29],[12,29],[13,29]], px);
        _drawPixels(canvas, Colors.white, [[11,30],[12,30]], px); // toe-box white rubber
        _drawPixels(canvas, const Color(0xFF0D47A1), [[13,30]], px); // heel sole
        _drawPixels(canvas, Colors.white, [[12,29]], px); // lace
        _drawPixels(canvas, const Color(0xFF1565C0), [[10,29],[14,29],[10,30]], px);
        // right (mirror)
        _drawPixels(canvas, const Color(0xFF42A5F5), [[18,29],[19,29],[20,29]], px);
        _drawPixels(canvas, Colors.white, [[19,30],[20,30]], px);
        _drawPixels(canvas, const Color(0xFF0D47A1), [[18,30]], px);
        _drawPixels(canvas, Colors.white, [[19,29]], px);
        _drawPixels(canvas, const Color(0xFF1565C0), [[17,29],[21,29],[21,30]], px);
        break;

      case 'shoes/boots.png':
        // spec §12 shoes/boots — brown boots (rises to row 28)
        _drawPixels(canvas, const Color(0xFF5D4037), [
          [11,28],[12,28],[13,28],[11,29],[12,29],[13,29],[11,30],[12,30],[13,30],
          [18,28],[19,28],[20,28],[18,29],[19,29],[20,29],[18,30],[19,30],[20,30],
        ], px);
        // shaft shadow
        _drawPixels(canvas, const Color(0xFF3E2723), [
          [13,28],[13,29],[20,28],[20,29],
        ], px);
        // buckle strap
        _drawPixels(canvas, const Color(0xFFD7A441), [
          [11,28],[12,28],[18,28],[19,28],
        ], px);
        // sole (draw first — overwrite with upper above)
        _drawPixels(canvas, const Color(0xFF1B0E06), [
          [10,30],[21,30],
        ], px);
        // outline
        _drawPixels(canvas, const Color(0xFF1B0E06), [
          [10,28],[14,28],[10,29],[14,29],[17,28],[21,28],[17,29],[21,29],
        ], px);
        break;

      case 'shoes/heels.png':
        // spec §12 shoes/heels — pink heels
        _drawPixels(canvas, const Color(0xFFE91E63), [[12,29],[13,29]], px);
        _drawPixels(canvas, const Color(0xFFE91E63), [[19,29],[18,29]], px);
        // heel spike
        _drawPixels(canvas, const Color(0xFFE91E63), [[13,30],[18,30]], px);
        // toe-box
        _drawPixels(canvas, const Color(0xFFE91E63), [[11,29],[12,30]], px);
        _drawPixels(canvas, const Color(0xFFE91E63), [[20,29],[19,30]], px);
        // sole
        _drawPixels(canvas, const Color(0xFF880E4F), [
          [11,30],[12,30],[13,30],[18,30],[19,30],[20,30],
        ], px);
        // highlight
        _drawPixels(canvas, const Color(0xFFF48FB1), [[12,29],[19,29]], px);
        break;

      case 'shoes/loafers.png':
        // spec §12 shoes/loafers — dark loafers
        _drawPixels(canvas, const Color(0xFF37474F), [
          [11,29],[12,29],[13,29],[18,29],[19,29],[20,29],
        ], px);
        // saddle strap
        _drawPixels(canvas, const Color(0xFF546E7A), [[12,29],[19,29]], px);
        // toe-box glossy highlight
        _drawPixels(canvas, const Color(0xFF78909C), [[11,29],[18,29]], px);
        // sole
        _drawPixels(canvas, const Color(0xFF1C2A31), [
          [11,30],[12,30],[13,30],[18,30],[19,30],[20,30],
        ], px);
        // outline
        _drawPixels(canvas, const Color(0xFF0F1A20), [
          [10,29],[14,29],[17,29],[21,29],
        ], px);
        break;

      case 'shoes/sandals.png':
        // spec §12 shoes/sandals — yellow sandals
        _drawPixels(canvas, const Color(0xFFD4A017), [[11,29],[13,29]], px);
        _drawPixels(canvas, const Color(0xFFD4A017), [[18,29],[20,29]], px);
        // buckle center
        _drawPixels(canvas, const Color(0xFFFFEB3B), [[12,29],[19,29]], px);
        // sole
        _drawPixels(canvas, const Color(0xFF8D6E63), [
          [11,30],[12,30],[13,30],[18,30],[19,30],[20,30],
        ], px);
        // toe skin exposed
        final skinBase = _getSkinTones(character?.skinTone ?? 'fair')[1];
        _drawPixels(canvas, skinBase, [[10,30],[17,30]], px);
        // outline
        _drawPixels(canvas, const Color(0xFF6D5F10), [
          [10,29],[14,29],[17,29],[21,29],
        ], px);
        break;

      case 'shoes/golden_shoes.png':
        // spec §12 shoes/golden_shoes — EPIC gold sneakers
        _drawPixels(canvas, const Color(0xFFFFD700), [
          [11,29],[12,29],[13,29],[18,29],[19,29],[20,29],
        ], px);
        // toe-box
        _drawPixels(canvas, const Color(0xFFFFF59D), [
          [11,30],[12,30],[18,30],[19,30],
        ], px);
        // sole
        _drawPixels(canvas, const Color(0xFFB8860B), [[13,30],[20,30]], px);
        // sparkle
        _drawPixels(canvas, Colors.white, [[12,29],[19,29]], px);
        // outline
        _drawPixels(canvas, const Color(0xFF8B6914), [
          [10,29],[14,29],[17,29],[21,29],
        ], px);
        if (rarity == 'EPIC') {
          _drawPixels(canvas, Colors.white, [[10,29],[21,29]], px);
        }
        break;

      default:
        _drawShoes(canvas, px,
          CharacterPalette.defaultShoesBase,
          CharacterPalette.defaultShoesShadow,
          CharacterPalette.defaultShoesHighlight);
    }
  }

  void _drawSparkles(Canvas canvas, double px, double animValue) {
    // spec §14 EPIC sparkle — 32×32 positions, 3×3 cross pattern
    final sparklePositions = [
      [3, 3], [28, 3],   // head sides
      [1, 15], [30, 14], // shoulders
      [5, 25], [26, 27], // waist
      [15, 1], [14, 31], // center top/bottom
    ];

    final sparklePaint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;

    for (var i = 0; i < sparklePositions.length; i++) {
      final phase = (animValue + i / sparklePositions.length) % 1.0;
      if (phase < 0.3) {
        final alpha = (phase / 0.3 * 255).round().clamp(0, 255);
        final x = sparklePositions[i][0];
        final y = sparklePositions[i][1];
        // 3x3 cross (+) pattern
        final crossPixels = [
          [x, y-1], [x-1, y], [x, y], [x+1, y], [x, y+1],
        ];
        sparklePaint.color = Colors.white.withAlpha(alpha);
        for (final p in crossPixels) {
          if (p[0] >= 0 && p[0] < 32 && p[1] >= 0 && p[1] < 32) {
            canvas.drawRect(
              Rect.fromLTWH(p[0] * px, p[1] * px, px, px),
              sparklePaint,
            );
          }
        }
      }
    }

    // Crown gold shimmer (spec §14)
    if (character?.hat?.assetKey == 'hat/crown.png') {
      final shimmerAlpha = (255 * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(animValue * 2 * math.pi)))).round().clamp(0, 255);
      final goldPaint = Paint()
        ..color = Color.fromARGB(shimmerAlpha, 0xFF, 0xFF, 0xCC)
        ..isAntiAlias = false;
      // spec §14 crown 5-point top
      for (final p in [[14,0],[15,0],[16,0],[17,0],[18,0]]) {
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
        oldDelegate.shimmerValue != shimmerValue ||
        oldDelegate.accessoryAnimValue != accessoryAnimValue ||
        oldDelegate.isDark != isDark;
  }
}

/// Paints a pixel-art character into [dst] on an external [canvas].
///
/// Uses a static (non-animated) frame: shimmer=null, sparkle disabled.
/// Safe to call from a [dart:ui] off-screen canvas (e.g. photo stamping).
/// Does nothing if [character] is null.
/// isDark hardcoded false — photo stamp always renders in light mode.
void paintCharacterIntoCanvas(
  Canvas canvas, {
  required CharacterData? character,
  required Rect dst,
}) {
  if (character == null) return;
  final painter = _PixelCharacterPainter(
    character: character,
    shimmerValue: null,
    accessoryAnimValue: null,
    isDark: false,
  );
  canvas.save();
  canvas.translate(dst.left, dst.top);
  painter.paint(canvas, dst.size);
  canvas.restore();
}
