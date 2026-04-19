import 'package:flutter/material.dart';
import 'character_avatar.dart';
import 'tappable_character.dart';
import '../../features/character/models/character_data.dart';
import '../../features/room_decoration/models/room_equip.dart';

/// Cyworld-style miniroom color palette.
class MiniroomColors {
  MiniroomColors._();

  // Wall
  static const wallBase = Color(0xFFFFF5F8);
  static const wallShadow = Color(0xFFFFE4EC);

  // Floor
  static const floorLight = Color(0xFFFFF0E8);
  static const floorDark = Color(0xFFFFE0D0);

  // Baseboard / molding
  static const baseboard = Color(0xFFE8C8D0);
  static const moldingTop = Color(0xFFF0D8E0);

  // Furniture wood
  static const woodLight = Color(0xFFD4A574);
  static const woodDark = Color(0xFFB07848);
  static const woodShadow = Color(0xFF8B6040);

  // Window
  static const windowFrame = Color(0xFFE0C8D0);
  static const windowGlass = Color(0xFFE8F4FD);
  static const skyBlue = Color(0xFFB3E5FC);
  static const windowPane = Color(0xFFFFFFFF);

  // Decorative
  static const rugBase = Color(0xFFF8BBD0);
  static const rugDark = Color(0xFFF48FB1);
  static const plantGreen = Color(0xFF81C784);
  static const plantDark = Color(0xFF4CAF50);
  static const potBrown = Color(0xFFA1887F);
  static const potDark = Color(0xFF8D6E63);
  static const lampYellow = Color(0xFFFFF9C4);
  static const lampGlow = Color(0xFFFFECB3);
  static const clockFace = Color(0xFFFFFDE7);
  static const clockHand = Color(0xFF5D4037);
  static const bookSpine1 = Color(0xFFCE93D8);
  static const bookSpine2 = Color(0xFF90CAF9);
  static const bookSpine3 = Color(0xFFA5D6A7);
  static const mugWhite = Color(0xFFFFF8E1);

  // Room border
  static const roomBorder = Color(0xFFE0BFC7);
}

/// Cyworld-style miniroom scene — pixel-art room with character inside.
/// Uses independent horizontal/vertical scaling to fill the full width.
///
/// [equip] 가 지정되면 해당 MiniroomEquip 의 wall/floor assetKey 로 painter 를 분기한다.
/// Phase 2 에서 wall, floor 만 분기 구현. 나머지 슬롯은 기본 painter 유지.
class MiniroomScene extends StatelessWidget {
  final CharacterData? character;
  final Color? wallTintColor;
  final double height;
  final double characterSize;

  /// Phase 2: 미니룸 장착 아이템 override. wall/floor 색 분기에 사용.
  final MiniroomEquip? equip;

  const MiniroomScene({
    super.key,
    this.character,
    this.wallTintColor,
    this.height = 250,
    this.characterSize = 110,
    this.equip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Independent scaling: fill full width and full height
          final pxW = w / 32;
          final pxH = h / 24;

          // equip.wall.assetKey → 벽지 색 분기 (Phase 2)
          final equipWallColor =
              _wallColorFor(equip?.wall?.assetKey);
          final equipFloorColors =
              _floorColorsFor(equip?.floor?.assetKey);

          final wallTint = equipWallColor != null
              ? Color.lerp(MiniroomColors.wallBase, equipWallColor, 0.45)!
              : wallTintColor != null
                  ? Color.lerp(MiniroomColors.wallBase, wallTintColor, 0.3)!
                  : MiniroomColors.wallBase;

          final charSize = characterSize;
          final charLeft = (w - charSize) / 2;
          final charTop = h * 0.18;

          return Stack(
            children: [
              CustomPaint(
                size: Size(w, h),
                painter: _MiniroomBackgroundPainter(
                  pxW: pxW,
                  pxH: pxH,
                  wallTint: wallTint,
                  floorOverride: equipFloorColors,
                ),
              ),
              Positioned(
                left: charLeft,
                top: charTop,
                child: TappableCharacter(
                  child: CharacterAvatar(
                    character: character,
                    size: charSize,
                  ),
                ),
              ),
              CustomPaint(
                size: Size(w, h),
                painter: _MiniroomForegroundPainter(pxW: pxW, pxH: pxH),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── assetKey → color helpers (top-level) ───

Color? _wallColorFor(String? assetKey) {
  if (assetKey == null) return null;
  if (assetKey.startsWith('wall/pink')) return const Color(0xFFFFB3C1);
  if (assetKey.startsWith('wall/blue')) return const Color(0xFFB3D9FF);
  if (assetKey.startsWith('wall/green')) return const Color(0xFFA5D6A7);
  if (assetKey.startsWith('wall/yellow')) return const Color(0xFFFFF9C4);
  if (assetKey.startsWith('wall/purple')) return const Color(0xFFCE93D8);
  if (assetKey.startsWith('wall/white')) return const Color(0xFFFAFAFA);
  return const Color(0xFFFFB3C1);
}

List<Color>? _floorColorsFor(String? assetKey) {
  if (assetKey == null) return null;
  if (assetKey.startsWith('floor/wood')) {
    return [const Color(0xFFD4A574), const Color(0xFFB07848)];
  }
  if (assetKey.startsWith('floor/tile')) {
    return [const Color(0xFFE0E0E0), const Color(0xFFBDBDBD)];
  }
  if (assetKey.startsWith('floor/marble')) {
    return [const Color(0xFFF5F5F5), const Color(0xFFE8E8E8)];
  }
  return null;
}

// ─── Background Painter (wall, floor, furniture behind character) ───

class _MiniroomBackgroundPainter extends CustomPainter {
  final double pxW;
  final double pxH;
  final Color wallTint;
  final List<Color>? floorOverride;

  _MiniroomBackgroundPainter({
    required this.pxW,
    required this.pxH,
    required this.wallTint,
    this.floorOverride,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawCeilingMolding(canvas);
    _drawWall(canvas);
    _drawBaseboard(canvas);
    _drawFloor(canvas);
    _drawWindow(canvas);
    _drawClock(canvas);
    _drawShelf(canvas);
    _drawDesk(canvas);
    _drawRug(canvas);
    _drawPlant(canvas);
  }

  void _drawPx(Canvas canvas, Color color, int x, int y) {
    canvas.drawRect(
      Rect.fromLTWH(x * pxW, y * pxH, pxW, pxH),
      Paint()..color = color,
    );
  }

  void _drawRect(Canvas canvas, Color color, int x, int y, int w, int h) {
    canvas.drawRect(
      Rect.fromLTWH(x * pxW, y * pxH, w * pxW, h * pxH),
      Paint()..color = color,
    );
  }

  void _drawCeilingMolding(Canvas canvas) {
    _drawRect(canvas, MiniroomColors.moldingTop, 0, 0, 32, 1);
    _drawRect(canvas, MiniroomColors.baseboard, 0, 1, 32, 1);
  }

  void _drawWall(Canvas canvas) {
    _drawRect(canvas, wallTint, 0, 2, 32, 10);
    final shadow = Color.lerp(wallTint, MiniroomColors.wallShadow, 0.5)!;
    _drawRect(canvas, shadow, 0, 10, 32, 2);
  }

  void _drawBaseboard(Canvas canvas) {
    _drawRect(canvas, MiniroomColors.baseboard, 0, 12, 32, 1);
  }

  void _drawFloor(Canvas canvas) {
    final lightColor = floorOverride != null
        ? floorOverride![0]
        : MiniroomColors.floorLight;
    final darkColor = floorOverride != null
        ? floorOverride![1]
        : MiniroomColors.floorDark;
    for (int y = 13; y < 24; y++) {
      for (int x = 0; x < 32; x++) {
        final isLight = (x + y) % 2 == 0;
        _drawPx(canvas, isLight ? lightColor : darkColor, x, y);
      }
    }
  }

  void _drawWindow(Canvas canvas) {
    _drawRect(canvas, MiniroomColors.windowFrame, 3, 3, 8, 7);
    _drawRect(canvas, MiniroomColors.windowGlass, 4, 4, 6, 5);
    _drawRect(canvas, MiniroomColors.skyBlue, 4, 4, 6, 3);
    _drawRect(canvas, MiniroomColors.windowPane, 7, 4, 1, 5);
    _drawRect(canvas, MiniroomColors.windowPane, 4, 6, 6, 1);
    _drawPx(canvas, MiniroomColors.windowPane, 5, 5);
    _drawPx(canvas, MiniroomColors.windowPane, 6, 5);
    _drawPx(canvas, MiniroomColors.windowPane, 9, 4);
    _drawPx(canvas, MiniroomColors.windowPane, 10, 4);
    _drawRect(canvas, MiniroomColors.windowFrame, 3, 9, 8, 1);
  }

  void _drawClock(Canvas canvas) {
    _drawRect(canvas, MiniroomColors.clockFace, 15, 3, 3, 3);
    _drawPx(canvas, MiniroomColors.woodDark, 15, 3);
    _drawPx(canvas, MiniroomColors.woodDark, 17, 3);
    _drawPx(canvas, MiniroomColors.woodDark, 15, 5);
    _drawPx(canvas, MiniroomColors.woodDark, 17, 5);
    _drawPx(canvas, MiniroomColors.clockHand, 16, 3);
    _drawPx(canvas, MiniroomColors.clockHand, 16, 4);
    _drawPx(canvas, MiniroomColors.clockHand, 17, 4);
  }

  void _drawShelf(Canvas canvas) {
    _drawRect(canvas, MiniroomColors.woodLight, 22, 7, 9, 1);
    _drawRect(canvas, MiniroomColors.woodDark, 22, 8, 9, 1);
    _drawPx(canvas, MiniroomColors.woodShadow, 23, 8);
    _drawPx(canvas, MiniroomColors.woodShadow, 29, 8);
    _drawRect(canvas, MiniroomColors.bookSpine1, 23, 5, 1, 2);
    _drawRect(canvas, MiniroomColors.bookSpine2, 24, 5, 1, 2);
    _drawRect(canvas, MiniroomColors.bookSpine3, 25, 6, 1, 1);
    _drawRect(canvas, MiniroomColors.bookSpine1, 26, 5, 1, 2);
    _drawRect(canvas, MiniroomColors.bookSpine2, 27, 6, 1, 1);
    _drawRect(canvas, MiniroomColors.mugWhite, 28, 6, 2, 1);
    _drawPx(canvas, MiniroomColors.mugWhite, 28, 7);
    _drawPx(canvas, MiniroomColors.mugWhite, 29, 7);
    _drawPx(canvas, MiniroomColors.baseboard, 30, 6);
  }

  void _drawDesk(Canvas canvas) {
    _drawRect(canvas, MiniroomColors.woodLight, 1, 14, 8, 2);
    _drawRect(canvas, MiniroomColors.woodDark, 1, 15, 8, 1);
    _drawRect(canvas, MiniroomColors.woodDark, 2, 16, 2, 4);
    _drawRect(canvas, MiniroomColors.woodDark, 7, 16, 2, 4);
    _drawRect(canvas, MiniroomColors.woodShadow, 4, 16, 3, 2);
    _drawPx(canvas, MiniroomColors.woodDark, 4, 13);
    _drawRect(canvas, MiniroomColors.lampYellow, 3, 12, 3, 1);
    _drawPx(canvas, MiniroomColors.woodShadow, 4, 14);
  }

  void _drawRug(Canvas canvas) {
    _drawRect(canvas, MiniroomColors.rugBase, 11, 18, 10, 3);
    _drawRect(canvas, MiniroomColors.rugBase, 12, 17, 8, 1);
    _drawRect(canvas, MiniroomColors.rugBase, 12, 21, 8, 1);
    _drawRect(canvas, MiniroomColors.rugDark, 13, 19, 6, 1);
    for (int x = 12; x < 20; x += 2) {
      _drawPx(canvas, MiniroomColors.rugDark, x, 17);
      _drawPx(canvas, MiniroomColors.rugDark, x, 21);
    }
  }

  void _drawPlant(Canvas canvas) {
    _drawRect(canvas, MiniroomColors.potBrown, 26, 19, 4, 2);
    _drawPx(canvas, MiniroomColors.potDark, 26, 20);
    _drawPx(canvas, MiniroomColors.potDark, 29, 20);
    _drawRect(canvas, MiniroomColors.potDark, 26, 18, 4, 1);
    _drawPx(canvas, MiniroomColors.plantGreen, 27, 17);
    _drawPx(canvas, MiniroomColors.plantGreen, 28, 17);
    _drawPx(canvas, MiniroomColors.plantDark, 27, 16);
    _drawPx(canvas, MiniroomColors.plantGreen, 26, 16);
    _drawPx(canvas, MiniroomColors.plantGreen, 29, 16);
    _drawPx(canvas, MiniroomColors.plantDark, 28, 15);
    _drawPx(canvas, MiniroomColors.plantGreen, 27, 15);
  }

  @override
  bool shouldRepaint(_MiniroomBackgroundPainter oldDelegate) =>
      oldDelegate.wallTint != wallTint;
}

// ─── Foreground Painter (furniture in front of character) ───

class _MiniroomForegroundPainter extends CustomPainter {
  final double pxW;
  final double pxH;

  _MiniroomForegroundPainter({required this.pxW, required this.pxH});

  @override
  void paint(Canvas canvas, Size size) {
    _drawDeskFront(canvas);
    _drawLampGlow(canvas);
  }

  void _drawDeskFront(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(1 * pxW, 19 * pxH, 8 * pxW, 2 * pxH),
      Paint()..color = MiniroomColors.woodLight,
    );
    canvas.drawRect(
      Rect.fromLTWH(1 * pxW, 20 * pxH, 8 * pxW, 1 * pxH),
      Paint()..color = MiniroomColors.woodDark,
    );
  }

  void _drawLampGlow(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(4.5 * pxW, 13 * pxH),
        width: 6 * pxW,
        height: 6 * pxH,
      ),
      Paint()
        ..color = MiniroomColors.lampGlow.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(_MiniroomForegroundPainter oldDelegate) => false;
}
