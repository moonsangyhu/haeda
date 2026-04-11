import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/widgets/character_avatar.dart';
import '../../character/models/character_data.dart';

/// Composites a bottom-bar watermark onto a camera-captured photo.
///
/// The bar contains (left to right):
///   - Pixel character avatar (if [character] is non-null)
///   - Nickname (if non-empty)
///   - Date + time (right-aligned)
///
/// Returns PNG-encoded bytes of the composited image.
Future<Uint8List> stampVerificationPhoto({
  required Uint8List photoBytes,
  required CharacterData? character,
  required String nickname,
  required DateTime timestamp,
}) async {
  // --- Decode original image ---
  final codec = await ui.instantiateImageCodec(photoBytes);
  final frame = await codec.getNextFrame();
  final original = frame.image;
  final imgW = original.width.toDouble();
  final imgH = original.height.toDouble();

  // --- Off-screen canvas ---
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Draw original photo
  canvas.drawImage(original, Offset.zero, Paint());

  // --- Bar geometry ---
  final barHeight = (imgH * 0.12).clamp(96.0, 200.0);
  final barRect = Rect.fromLTWH(0, imgH - barHeight, imgW, barHeight);

  // Semi-transparent black background
  canvas.drawRect(
    barRect,
    Paint()..color = Colors.black.withValues(alpha: 0.55),
  );

  // --- Character (left side) ---
  final padding = barHeight * 0.12;
  final charSize = barHeight - padding * 2;
  double contentLeft = padding;

  if (character != null) {
    final charRect = Rect.fromLTWH(
      padding,
      imgH - barHeight + padding,
      charSize,
      charSize,
    );
    paintCharacterIntoCanvas(canvas, character: character, dst: charRect);
    contentLeft = padding + charSize + padding * 0.6;
  }

  // --- Nickname (right of character) ---
  final nicknameTrimmed = nickname.trim();
  if (nicknameTrimmed.isNotEmpty) {
    final nicknameFontSize = barHeight * 0.26;
    final nicknameSpan = TextSpan(
      text: nicknameTrimmed,
      style: TextStyle(
        color: Colors.white,
        fontSize: nicknameFontSize,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.none,
      ),
    );
    final nicknamePainter = TextPainter(
      text: nicknameSpan,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: imgW * 0.5);

    final nicknameY =
        imgH - barHeight + (barHeight - nicknamePainter.height) / 2;
    nicknamePainter.paint(canvas, Offset(contentLeft, nicknameY));
  }

  // --- Date + time (right-aligned) ---
  final rightPadding = padding;
  final y = timestamp.year;
  final mm = timestamp.month.toString().padLeft(2, '0');
  final dd = timestamp.day.toString().padLeft(2, '0');
  final hh = timestamp.hour.toString().padLeft(2, '0');
  final min = timestamp.minute.toString().padLeft(2, '0');

  final dateText = '$y.$mm.$dd';
  final timeText = '$hh:$min';

  final dateFontSize = barHeight * 0.24;
  final timeFontSize = barHeight * 0.28;

  final datePainter = TextPainter(
    text: TextSpan(
      text: dateText,
      style: TextStyle(
        color: Colors.white,
        fontSize: dateFontSize,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.none,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final timePainter = TextPainter(
    text: TextSpan(
      text: timeText,
      style: TextStyle(
        color: Colors.white,
        fontSize: timeFontSize,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.none,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  // Stack date above time, both right-aligned
  final textBlockHeight = datePainter.height + timePainter.height;
  final textBlockTop = imgH - barHeight + (barHeight - textBlockHeight) / 2;
  final textRight = imgW - rightPadding;

  datePainter.paint(
    canvas,
    Offset(textRight - datePainter.width, textBlockTop),
  );
  timePainter.paint(
    canvas,
    Offset(
      textRight - timePainter.width,
      textBlockTop + datePainter.height,
    ),
  );

  // --- Encode to PNG ---
  final picture = recorder.endRecording();
  final outImage = await picture.toImage(original.width, original.height);
  final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
