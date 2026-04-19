import 'package:flutter/material.dart';
import 'accessory_renderer.dart';

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
      painter: ItemIconPainter(assetKey: assetKey, rarity: rarity),
    );
  }
}

class ItemIconPainter extends CustomPainter {
  final String assetKey;
  final String rarity;
  const ItemIconPainter({required this.assetKey, required this.rarity});

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

    final bg = Paint()..color = const Color(0xFFF5F5F5)..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s)),
      bg,
    );

    switch (assetKey) {
      // ─── HATS ───
      case 'hat/cap.png':
        _draw(canvas, const Color(0xFFE53935), [[2,2],[3,2],[4,2],[5,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[1,4],[6,4]], s);
        _draw(canvas, const Color(0xFFC62828), [[0,4],[1,4],[6,4],[7,4]], s);
        break;
      case 'hat/beanie.png':
      case 'hat/pink_beanie.png':
        final isP = assetKey.contains('pink');
        final m = isP ? const Color(0xFFFF80AB) : const Color(0xFF1976D2);
        final l = isP ? const Color(0xFFFFCDD2) : const Color(0xFF90CAF9);
        _draw(canvas, Colors.white, [[3,1],[4,1]], s);
        _draw(canvas, m, [[2,2],[3,2],[4,2],[5,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[1,4],[2,4],[5,4],[6,4]], s);
        _draw(canvas, l, [[2,3],[4,3],[6,3]], s);
        break;
      case 'hat/headband.png':
        _draw(canvas, const Color(0xFFFFD600), [[1,3],[2,3],[3,3],[4,3],[5,3],[6,3]], s);
        _draw(canvas, const Color(0xFFFF8F00), [[3,2],[4,2]], s);
        break;
      case 'hat/fedora.png':
        _draw(canvas, const Color(0xFF795548), [[3,1],[4,1],[2,2],[3,2],[4,2],[5,2]], s);
        _draw(canvas, const Color(0xFF5D4037), [[0,3],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3]], s);
        _draw(canvas, const Color(0xFFFFCC80), [[2,2],[5,2]], s);
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
        _draw(canvas, const Color(0xFFE0E0E0), [[1,2],[6,2],[3,1],[4,1]], s);
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
        _draw(canvas, const Color(0xFF0D47A1), [[2,1],[5,1]], s);
        _draw(canvas, const Color(0xFF1976D2), [[3,5],[4,5]], s);
        break;
      case 'top/cardigan.png':
        _draw(canvas, const Color(0xFF8D6E63), [[1,2],[2,2],[5,2],[6,2],[2,3],[5,3],[2,4],[5,4],[2,5],[5,5]], s);
        _draw(canvas, const Color(0xFFFFF9C4), [[3,2],[4,2],[3,3],[4,3],[3,4],[4,4],[3,5],[4,5]], s);
        _draw(canvas, const Color(0xFF5D4037), [[3,3],[3,5]], s);
        break;
      case 'top/tuxedo.png':
        _draw(canvas, const Color(0xFF212121), [[1,2],[2,2],[5,2],[6,2],[2,3],[5,3],[2,4],[5,4],[2,5],[5,5]], s);
        _draw(canvas, Colors.white, [[3,2],[4,2],[3,3],[4,3],[3,4],[4,4],[3,5],[4,5]], s);
        _draw(canvas, const Color(0xFFFF1744), [[3,2],[4,2]], s);
        break;

      // ─── BOTTOMS ───
      case 'bottom/jeans.png':
        _draw(canvas, const Color(0xFF1565C0), [[2,1],[3,1],[4,1],[5,1],[2,2],[3,2],[4,2],[5,2],[2,3],[3,3],[4,3],[5,3],[2,4],[3,4],[4,4],[5,4]], s);
        _draw(canvas, const Color(0xFF0D47A1), [[2,1],[5,1],[2,4],[5,4]], s);
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
        _draw(canvas, const Color(0xFF33691E), [[1,2],[6,2]], s);
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
        _draw(canvas, Colors.white, [[1,3],[5,3]], s);
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
        _draw(canvas, Colors.white, [[0,2],[0,3],[4,2],[4,3]], s);
        break;

      // ─── ACCESSORIES ───
      default:
        if (assetKey.startsWith('accessory/')) {
          drawAccessoryIcon(canvas, s, assetKey);
          return;
        }
        _draw(canvas, const Color(0xFF9E9E9E), [[2,1],[3,1],[4,1],[5,1],[5,2],[4,3],[3,3],[3,5]], s);
    }
  }

  @override
  bool shouldRepaint(ItemIconPainter old) =>
      old.assetKey != assetKey || old.rarity != rarity;
}
