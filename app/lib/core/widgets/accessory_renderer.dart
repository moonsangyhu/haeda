import 'package:flutter/material.dart';

void _drawPx(Canvas canvas, Color color, List<List<int>> pixels, double s) {
  final paint = Paint()
    ..color = color
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..style = PaintingStyle.fill;
  for (final p in pixels) {
    canvas.drawRect(Rect.fromLTWH(p[0] * s, p[1] * s, s, s), paint);
  }
}

/// Coordinate remap from 16-grid to 32-grid (spec §13):
/// x_new = x_old * 2 - 1
/// y_new = y_old * 2 + 4
/// Each pixel becomes a 2×2 block.
void _drawPxRemapped(Canvas canvas, Color color, List<List<int>> pixels, double px) {
  final paint = Paint()
    ..color = color
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..style = PaintingStyle.fill;
  for (final p in pixels) {
    final xNew = p[0] * 2 - 1;
    final yNew = p[1] * 2 + 4;
    for (int dx = 0; dx < 2; dx++) {
      for (int dy = 0; dy < 2; dy++) {
        canvas.drawRect(
          Rect.fromLTWH((xNew + dx) * px, (yNew + dy) * px, px, px),
          paint,
        );
      }
    }
  }
}

void drawAccessoryOnCharacter(
  Canvas canvas,
  double px,
  String assetKey,
  String rarity,
  double? animValue,
) {
  switch (assetKey) {
    case 'accessory/watch.png':
      _drawPxRemapped(canvas, const Color(0xFF78909C), [[4, 10]], px);
      _drawPxRemapped(canvas, const Color(0xFFFFFFFF), [[4, 10]], px);
      break;

    case 'accessory/sunglasses.png':
      _drawPxRemapped(canvas, const Color(0xFF37474F), [
        [5, 3], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3],
      ], px);
      _drawPxRemapped(canvas, const Color(0xFF4DB6AC), [[6, 3], [7, 3]], px);
      _drawPxRemapped(canvas, const Color(0xFF4DB6AC), [[8, 3], [9, 3]], px);
      _drawPxRemapped(canvas, const Color(0xFF37474F), [[7, 3], [8, 3]], px);
      break;

    case 'accessory/angel_wings.png':
      _drawPxRemapped(canvas, Colors.white, [
        [2, 8], [3, 8],
        [1, 9], [2, 9], [3, 9],
        [2, 10], [3, 10],
        [2, 11], [3, 11],
        [12, 8], [13, 8],
        [12, 9], [13, 9], [14, 9],
        [12, 10], [13, 10],
        [12, 11], [13, 11],
      ], px);
      _drawPxRemapped(canvas, const Color(0xFFE3F2FD), [[2, 9], [13, 9]], px);
      break;

    case 'accessory/necklace.png':
      _drawPxRemapped(canvas, const Color(0xFFFFD700), [[7, 8], [8, 8]], px);
      break;

    case 'accessory/newspaper.png':
      _drawPxRemapped(canvas, const Color(0xFFBDBDBD), [
        [10, 9], [11, 9], [12, 9],
        [10, 11], [11, 11], [12, 11],
      ], px);
      _drawPxRemapped(canvas, const Color(0xFF9E9E9E), [
        [10, 10], [11, 10], [12, 10],
      ], px);
      _drawPxRemapped(canvas, const Color(0xFF757575), [[12, 10]], px);
      break;

    case 'accessory/duck_watergun.png':
      // Duck body
      _drawPxRemapped(canvas, const Color(0xFFFFEB3B), [
        [11, 9], [12, 9],
        [11, 10], [12, 10],
      ], px);
      // Duck head
      _drawPxRemapped(canvas, const Color(0xFFFFEB3B), [[13, 8], [13, 9]], px);
      // Beak
      _drawPxRemapped(canvas, const Color(0xFFFF9800), [[14, 9]], px);
      // Eye
      _drawPxRemapped(canvas, const Color(0xFF212121), [[13, 8]], px);
      // Water squirt animation (every 2s in 6s cycle)
      if (animValue != null) {
        final phase = (animValue * 3) % 1.0;
        if (phase < 0.15) {
          final alpha = (255 * (1.0 - phase / 0.15)).round().clamp(0, 255);
          _drawPxRemapped(canvas, Color.fromARGB(alpha, 0x42, 0xA5, 0xF5), [
            [15, 9], [15, 8],
          ], px);
        }
      }
      break;

    case 'accessory/laptop.png':
      // Keyboard base
      _drawPxRemapped(canvas, const Color(0xFF424242), [
        [3, 10], [4, 10], [5, 10],
      ], px);
      // Screen (animated open/close every 3s in 6s cycle)
      final isOpen = animValue == null || (animValue * 2).floor() % 2 == 0;
      _drawPxRemapped(
        canvas,
        isOpen ? const Color(0xFF90CAF9) : const Color(0xFF616161),
        [[3, 9], [4, 9], [5, 9]],
        px,
      );
      // Hinge
      _drawPxRemapped(canvas, const Color(0xFF212121), [[3, 10]], px);
      break;

    case 'accessory/pencil.png':
      // Eraser (pink)
      _drawPxRemapped(canvas, const Color(0xFFFF8A80), [[11, 7]], px);
      // Metal band (silver)
      _drawPxRemapped(canvas, const Color(0xFFBDBDBD), [[11, 8]], px);
      // Body (yellow)
      _drawPxRemapped(canvas, const Color(0xFFFFEB3B), [[11, 9], [11, 10], [11, 11]], px);
      // Sharpened tip (tan)
      _drawPxRemapped(canvas, const Color(0xFFFFCC80), [[11, 12]], px);
      // Lead (dark)
      _drawPxRemapped(canvas, const Color(0xFF424242), [[11, 13]], px);
      break;

    default:
      break;
  }
}

void drawAccessoryIcon(Canvas canvas, double s, String assetKey) {
  switch (assetKey) {
    case 'accessory/watch.png':
      _drawPx(canvas, const Color(0xFF78909C), [[3, 2], [4, 2], [3, 3], [4, 3], [3, 4], [4, 4]], s);
      _drawPx(canvas, const Color(0xFFE0E0E0), [[3, 3], [4, 3]], s);
      break;
    case 'accessory/bag.png':
      _drawPx(canvas, const Color(0xFF8D6E63), [[2, 1], [3, 1], [4, 1], [5, 1], [2, 2], [3, 2], [4, 2], [5, 2], [2, 3], [3, 3], [4, 3], [5, 3], [2, 4], [3, 4], [4, 4], [5, 4]], s);
      _drawPx(canvas, const Color(0xFFD7CCC8), [[3, 1], [4, 1]], s);
      _drawPx(canvas, const Color(0xFF5D4037), [[3, 3], [4, 3]], s);
      break;
    case 'accessory/scarf.png':
      _drawPx(canvas, const Color(0xFFE53935), [[2, 2], [3, 2], [4, 2], [5, 2], [3, 3], [4, 3], [3, 4], [4, 4], [4, 5], [4, 6]], s);
      _drawPx(canvas, const Color(0xFFC62828), [[2, 2], [5, 2], [4, 5]], s);
      break;
    case 'accessory/sunglasses.png':
      _drawPx(canvas, const Color(0xFF37474F), [[1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3]], s);
      _drawPx(canvas, const Color(0xFF4DB6AC), [[2, 3], [3, 3], [5, 3], [6, 3]], s);
      _drawPx(canvas, const Color(0xFF263238), [[1, 2], [6, 2]], s);
      break;
    case 'accessory/earphones.png':
      _drawPx(canvas, const Color(0xFF424242), [[2, 2], [5, 2], [1, 3], [2, 3], [5, 3], [6, 3], [2, 4], [3, 4], [4, 4], [5, 4]], s);
      _drawPx(canvas, Colors.white, [[2, 3], [5, 3]], s);
      break;
    case 'accessory/angel_wings.png':
      _drawPx(canvas, Colors.white, [[0, 1], [1, 1], [6, 1], [7, 1], [0, 2], [1, 2], [2, 2], [5, 2], [6, 2], [7, 2], [0, 3], [1, 3], [6, 3], [7, 3], [1, 4], [6, 4]], s);
      _drawPx(canvas, const Color(0xFFE3F2FD), [[1, 2], [6, 2]], s);
      break;

    case 'accessory/newspaper.png':
      // Rolled newspaper
      _drawPx(canvas, const Color(0xFFBDBDBD), [
        [2, 2], [3, 2], [4, 2], [5, 2],
        [2, 5], [3, 5], [4, 5], [5, 5],
      ], s);
      _drawPx(canvas, const Color(0xFF9E9E9E), [
        [2, 3], [3, 3], [4, 3], [5, 3],
        [2, 4], [3, 4], [4, 4], [5, 4],
      ], s);
      _drawPx(canvas, const Color(0xFF757575), [[5, 3], [5, 4]], s);
      break;

    case 'accessory/duck_watergun.png':
      // Yellow duck body
      _drawPx(canvas, const Color(0xFFFFEB3B), [
        [2, 2], [3, 2], [4, 2],
        [2, 3], [3, 3], [4, 3],
        [2, 4], [3, 4],
      ], s);
      // Head + beak
      _drawPx(canvas, const Color(0xFFFFEB3B), [[5, 2], [5, 3]], s);
      _drawPx(canvas, const Color(0xFFFF9800), [[6, 3]], s);
      // Eye
      _drawPx(canvas, const Color(0xFF212121), [[5, 2]], s);
      // Water hint
      _drawPx(canvas, const Color(0xFF42A5F5), [[7, 3], [7, 2]], s);
      break;

    case 'accessory/laptop.png':
      // Open laptop
      _drawPx(canvas, const Color(0xFF90CAF9), [
        [1, 1], [2, 1], [3, 1], [4, 1], [5, 1],
        [1, 2], [2, 2], [3, 2], [4, 2], [5, 2],
        [1, 3], [2, 3], [3, 3], [4, 3], [5, 3],
      ], s);
      // Keyboard base
      _drawPx(canvas, const Color(0xFF424242), [
        [1, 4], [2, 4], [3, 4], [4, 4], [5, 4],
        [1, 5], [2, 5], [3, 5], [4, 5], [5, 5],
      ], s);
      // Screen border
      _drawPx(canvas, const Color(0xFF616161), [[1, 1], [5, 1], [1, 3], [5, 3]], s);
      break;

    case 'accessory/pencil.png':
      // Diagonal pencil
      _drawPx(canvas, const Color(0xFFFF8A80), [[1, 1]], s);
      _drawPx(canvas, const Color(0xFFBDBDBD), [[2, 2]], s);
      _drawPx(canvas, const Color(0xFFFFEB3B), [[3, 3], [4, 4], [5, 5]], s);
      _drawPx(canvas, const Color(0xFFFFCC80), [[6, 6]], s);
      _drawPx(canvas, const Color(0xFF424242), [[7, 7]], s);
      break;

    default:
      _drawPx(canvas, const Color(0xFF9E9E9E), [[2, 1], [3, 1], [4, 1], [5, 1], [5, 2], [4, 3], [3, 3], [3, 5]], s);
  }
}
