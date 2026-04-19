import 'package:flutter/material.dart';

class SpeechBubble extends StatelessWidget {
  final String text;
  final double opacity;
  final double scale;
  final String semanticsNickname;
  final double maxWidth;

  const SpeechBubble({
    super.key,
    required this.text,
    required this.opacity,
    required this.scale,
    required this.semanticsNickname,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.bottomCenter,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: '$semanticsNickname: $text',
          child: ExcludeSemantics(
            child: _BubbleBody(text: text, maxWidth: maxWidth),
          ),
        ),
      ),
    );
  }
}

class _BubbleBody extends StatelessWidget {
  final String text;
  final double maxWidth;

  const _BubbleBody({required this.text, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0x26000000),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF212121),
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
        CustomPaint(
          size: const Size(8, 6),
          painter: _SpeechTailPainter(),
        ),
      ],
    );
  }
}

class _SpeechTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0x26000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, fillPaint);
    // Draw border only on the two diagonal sides (not the top edge)
    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(_SpeechTailPainter old) => false;
}
