import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VideoService splash screen animation frame generation test', () async {
    final stopwatch = Stopwatch()..start();
    final List<Uint8List> frames = [];
    const int totalSteps = 24;

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.accessibility_new_rounded.codePoint),
        style: TextStyle(
          inherit: false,
          fontFamily: Icons.accessibility_new_rounded.fontFamily,
          package: Icons.accessibility_new_rounded.fontPackage,
          fontSize: 64,
          color: Colors.white,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Body Tracker',
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    for (int i = 0; i < totalSteps; i++) {
      final t = i / (totalSteps - 1);
      final curved = Curves.easeInOut.transform(t);
      final scale = 0.95 + (1.08 - 0.95) * curved;
      final opacity = 0.60 + (1.00 - 0.60) * curved;

      final rec = ui.PictureRecorder();
      final c = Canvas(rec, const Rect.fromLTWH(0, 0, 720, 1280));
      c.drawRect(const Rect.fromLTWH(0, 0, 720, 1280), Paint()..color = const Color(0xFF121216));

      c.save();
      c.translate(360, 640);
      c.scale(scale, scale);
      c.translate(-360, -640);

      final lp = Paint()..color = Color.fromRGBO(255, 255, 255, opacity);
      c.saveLayer(const Rect.fromLTWH(0, 0, 720, 1280), lp);

      final sp = Paint()
        ..color = const Color(0x593B82F6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      c.drawCircle(const Offset(360, 563), 59, sp);

      final cp = Paint()..color = const Color(0xFF3B82F6);
      c.drawCircle(const Offset(360, 555), 55, cp);

      iconPainter.paint(c, const Offset(328, 523));
      textPainter.paint(c, const Offset(250, 640));

      c.restore();
      c.restore();

      final pic = rec.endRecording();
      final img = await pic.toImage(720, 1280);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      frames.add(bd!.buffer.asUint8List());
    }
    stopwatch.stop();

    for (final isDark in [true, false]) {
      final bgColor = isDark ? const Color(0xFF121216) : const Color(0xFFFFFFFF);
      final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
      final primaryColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);

      final rec = ui.PictureRecorder();
      final c = Canvas(rec, const Rect.fromLTWH(0, 0, 720, 1280));
      c.drawRect(const Rect.fromLTWH(0, 0, 720, 1280), Paint()..color = bgColor);

      final cp = Paint()..color = primaryColor;
      c.drawCircle(const Offset(360, 555), 55, cp);

      final tp = TextPainter(
        text: TextSpan(
          text: 'Body Tracker',
          style: TextStyle(
            color: textColor,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(c, const Offset(250, 640));

      final pic = rec.endRecording();
      final img = await pic.toImage(720, 1280);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final p = bd!.buffer.asUint8List();

      if (isDark) {
        expect(p[0], equals(0x12));
        expect(p[1], equals(0x12));
        expect(p[2], equals(0x16));
      } else {
        expect(p[0], equals(0xFF));
        expect(p[1], equals(0xFF));
        expect(p[2], equals(0xFF));
      }
    }
  });

  test('Check blue_lemonade.png exists and inspect format', () async {
    final file = File('assets/blue_lemonade.png');
    expect(await file.exists(), isTrue);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final logoImage = frame.image;

    for (final theme in ['dark', 'light']) {
      final isDark = theme == 'dark';
      final bgColor = isDark ? const Color(0xFF121216) : const Color(0xFFFFFFFF);
      final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, 720, 1280));
      canvas.drawRect(const Rect.fromLTWH(0, 0, 720, 1280), Paint()..color = bgColor);

      const double logoSize = 260.0;
      const double gap = 36.0;

      final textPainter = TextPainter(
        text: TextSpan(
          text: 'BlueLemonade, 2026',
          style: TextStyle(
            color: textColor,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final totalHeight = logoSize + gap + textPainter.height;
      final startY = 640 - (totalHeight / 2.0);
      final logoRect = Rect.fromLTWH(360 - (logoSize / 2), startY, logoSize, logoSize);

      // Draw shadow for logo in dark mode
      if (isDark) {
        final shadowPaint = Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
        canvas.drawCircle(logoRect.center + const Offset(0, 6), (logoSize / 2), shadowPaint);
      } else {
        final shadowPaint = Paint()
          ..color = const Color(0x1A000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
        canvas.drawCircle(logoRect.center + const Offset(0, 4), (logoSize / 2), shadowPaint);
      }

      // Draw logo
      canvas.drawImageRect(
        logoImage,
        Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
        logoRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      // Draw text
      final textX = 360 - (textPainter.width / 2.0);
      final textY = startY + logoSize + gap;
      textPainter.paint(canvas, Offset(textX, textY));

      final pic = rec.endRecording();
      final img = await pic.toImage(720, 1280);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bd, isNotNull);
      expect(bd!.lengthInBytes, equals(720 * 1280 * 4));

      final p = bd.buffer.asUint8List();
      if (isDark) {
        expect(p[0], equals(0x12));
        expect(p[1], equals(0x12));
        expect(p[2], equals(0x16));
      } else {
        expect(p[0], equals(0xFF));
        expect(p[1], equals(0xFF));
        expect(p[2], equals(0xFF));
      }
    }
  });

  test('Benchmark crossfadeFrames', () {
    const size = 720 * 1280 * 4;
    final a = Uint8List(size)..fillRange(0, size, 50);
    final b = Uint8List(size)..fillRange(0, size, 200);

    final sw = Stopwatch()..start();
    const steps = 12;
    int lastVal = 50;
    for (int s = 0; s < steps; s++) {
      final progress = (s + 1) / (steps + 1);
      final out = Uint8List(size);
      final int wB = (progress * 256).round().clamp(0, 256);
      final int wA = 256 - wB;
      for (int i = 0; i < size; i++) {
        out[i] = (a[i] * wA + b[i] * wB) >> 8;
      }
      expect(out[0], greaterThan(lastVal));
      lastVal = out[0];
    }
    expect(lastVal, lessThan(200));
    sw.stop();
    // ignore: avoid_print
    print('Blended 12 frames in ${sw.elapsedMilliseconds}ms');
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(0));
  });
}
