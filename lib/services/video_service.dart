import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/body_angle.dart';
import '../models/body_record.dart';
import 'config_service.dart';
import 'storage_service.dart';

typedef VideoProgressCallback = void Function(int currentSlide, int totalSlides, double progress);

class VideoSlideItem {
  final String imagePath;
  final String dateString;
  final String angleLabel;
  final String weightString;

  const VideoSlideItem({
    required this.imagePath,
    required this.dateString,
    required this.angleLabel,
    required this.weightString,
  });
}

class VideoService {
  static final VideoService instance = VideoService._internal();
  VideoService._internal();

  /// Compiles dataset into chronological slides filtering by selected angles.
  List<VideoSlideItem> buildSlideItems({
    required List<BodyRecord> records,
    required bool isKorean,
    Set<BodyAngle> selectedAngles = const {
      BodyAngle.front,
      BodyAngle.left,
      BodyAngle.back,
      BodyAngle.right,
    },
  }) {
    if (records.isEmpty || selectedAngles.isEmpty) return const [];

    final sortedRecords = List<BodyRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));

    final List<VideoSlideItem> slides = [];
    final dateFormat = DateFormat('yyyy.MM.dd');

    for (final record in sortedRecords) {
      final dateStr = dateFormat.format(record.date);
      final weightStr = '${record.weight.toStringAsFixed(1)} kg';

      for (final angle in BodyAngle.values) {
        if (!selectedAngles.contains(angle)) continue;

        slides.add(VideoSlideItem(
          imagePath: StorageService.instance.resolveImagePath(angle.getImagePath(record)),
          dateString: dateStr,
          angleLabel: angle.label(isKorean),
          weightString: weightStr,
        ));
      }
    }

    return slides;
  }

  /// Compiles all dataset into chronological slides and renders an MP4 video.
  Future<String?> renderSlideshowVideo({
    required List<BodyRecord> records,
    required double slideIntervalSeconds,
    required bool isKorean,
    Set<BodyAngle> selectedAngles = const {
      BodyAngle.front,
      BodyAngle.left,
      BodyAngle.back,
      BodyAngle.right,
    },
    String? theme,
    VideoProgressCallback? onProgress,
  }) async {
    final slides = buildSlideItems(
      records: records,
      isKorean: isKorean,
      selectedAngles: selectedAngles,
    );
    if (slides.isEmpty) return null;

    const int videoWidth = 720;
    const int videoHeight = 1280;
    const int fps = 24;
    final int framesPerSlide = (slideIntervalSeconds * fps).round().clamp(1, 600);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${tempDir.path}/body_tracker_$timestamp.mp4';

    try {
      await FlutterQuickVideoEncoder.setup(
        width: videoWidth,
        height: videoHeight,
        fps: fps,
        videoBitrate: 3000000,
        profileLevel: ProfileLevel.any,
        audioChannels: 0,
        audioBitrate: 0,
        sampleRate: 0,
        filepath: outputPath,
      );

      // 1. Render splash screen animation at the beginning
      // (2-second animation matching SplashScreen's pulse & fade at 24 fps = 48 frames)
      // Background and colors match the app's 'theme' config
      final effectiveTheme = (theme ?? ConfigService.instance.config.theme).toLowerCase();
      final isDarkTheme = effectiveTheme == 'dark';

      final appIconBytes = await _loadAppIconBytes();
      ui.Image? appIconImage;
      if (appIconBytes != null) {
        try {
          final codec = await ui.instantiateImageCodec(appIconBytes);
          final frame = await codec.getNextFrame();
          appIconImage = frame.image;
        } catch (e) {
          debugPrint('Error decoding app icon for splash intro: $e');
        }
      }

      onProgress?.call(0, slides.length, 0.0);
      const int splashFps = fps;
      const int splashCycleSteps = splashFps; // 24 steps for 1.0s forward cycle
      final splashFrames = <Uint8List>[];

      for (int step = 0; step < splashCycleSteps; step++) {
        final t = step / (splashCycleSteps - 1);
        final curved = Curves.easeInOut.transform(t);
        final scale = 0.95 + (1.08 - 0.95) * curved;
        final opacity = 0.60 + (1.00 - 0.60) * curved;

        final splashRgba = await _renderSplashFrameRgba(
          scale: scale,
          opacity: opacity,
          width: videoWidth,
          height: videoHeight,
          appName: isKorean ? '바디 트래커' : 'Body Tracker',
          isDark: isDarkTheme,
          iconImage: appIconImage,
        );
        splashFrames.add(splashRgba);
      }

      // Forward half-cycle (0.0s to 1.0s: scale 0.95 -> 1.08, opacity 0.60 -> 1.00)
      for (int step = 0; step < splashCycleSteps; step++) {
        await FlutterQuickVideoEncoder.appendVideoFrame(splashFrames[step]);
      }

      // Reverse half-cycle (1.0s to 2.0s: scale 1.08 -> 0.95, opacity 1.00 -> 0.60)
      for (int step = splashCycleSteps - 1; step >= 0; step--) {
        await FlutterQuickVideoEncoder.appendVideoFrame(splashFrames[step]);
      }

      // The last frame of intro is splashFrames[0] (scale 0.95, opacity 0.60)
      final lastIntroFrame = splashFrames[0];

      // 2. Render photo slides with dissolve transition from intro
      const int dissolveSteps = 12; // 12 frames = 0.5s smooth crossfade at 24 fps
      Uint8List? lastSlideRgba;

      for (int i = 0; i < slides.length; i++) {
        final slide = slides[i];
        if (onProgress != null) {
          final progress = 0.05 + 0.85 * ((i + 1) / slides.length);
          onProgress(i + 1, slides.length, progress);
        }

        final rawRgba = await _renderSlideFrameRgba(
          slide: slide,
          width: videoWidth,
          height: videoHeight,
        );
        lastSlideRgba = rawRgba;

        // Intro to Body dissolve transition on the first slide
        if (i == 0) {
          for (int s = 1; s <= dissolveSteps; s++) {
            final t = s / (dissolveSteps + 1);
            final blend = Curves.easeInOut.transform(t);
            final blendedFrame = _crossfadeFrames(lastIntroFrame, rawRgba, blend);
            await FlutterQuickVideoEncoder.appendVideoFrame(blendedFrame);
          }
        }

        // Append repeated frames for the duration of this slide
        for (int f = 0; f < framesPerSlide; f++) {
          await FlutterQuickVideoEncoder.appendVideoFrame(rawRgba);
        }
      }

      // 3. Render outro slide at the end with blue_lemonade logo & 'BlueLemonade, 2026'
      // Background color matches the app's 'theme' config
      final logoBytes = await _loadBlueLemonadeBytes();
      ui.Image? logoImage;
      if (logoBytes != null) {
        try {
          final codec = await ui.instantiateImageCodec(logoBytes);
          final frame = await codec.getNextFrame();
          logoImage = frame.image;
        } catch (e) {
          debugPrint('Error decoding blue_lemonade logo: $e');
        }
      }

      final outroRgba = await _renderOutroFrameRgba(
        logoImage: logoImage,
        isDark: isDarkTheme,
        width: videoWidth,
        height: videoHeight,
      );

      // Body to Outro dissolve transition
      if (lastSlideRgba != null) {
        for (int s = 1; s <= dissolveSteps; s++) {
          final t = s / (dissolveSteps + 1);
          final blend = Curves.easeInOut.transform(t);
          final blendedFrame = _crossfadeFrames(lastSlideRgba, outroRgba, blend);
          await FlutterQuickVideoEncoder.appendVideoFrame(blendedFrame);
        }
      }

      final int outroFrames = framesPerSlide < (fps * 2) ? (fps * 2) : framesPerSlide;
      for (int f = 0; f < outroFrames; f++) {
        await FlutterQuickVideoEncoder.appendVideoFrame(outroRgba);
      }

      if (onProgress != null) {
        onProgress(slides.length, slides.length, 1.0);
      }

      await FlutterQuickVideoEncoder.finish();
      return outputPath;
    } catch (e) {
      debugPrint('Error rendering video with FlutterQuickVideoEncoder: $e');
      try {
        await FlutterQuickVideoEncoder.finish();
      } catch (_) {}
      return null;
    }
  }

  /// Loads bytes for app_icon from assets or file fallback.
  Future<Uint8List?> _loadAppIconBytes() async {
    try {
      final byteData = await rootBundle.load('assets/app_icon.png');
      return byteData.buffer.asUint8List();
    } catch (_) {
      try {
        final file = File('assets/app_icon.png');
        if (await file.exists()) {
          return await file.readAsBytes();
        }
        final rootFile = File('app_icon.png');
        if (await rootFile.exists()) {
          return await rootFile.readAsBytes();
        }
      } catch (_) {}
      return null;
    }
  }

  /// Loads bytes for blue_lemonade branding logo from assets or file fallback.
  Future<Uint8List?> _loadBlueLemonadeBytes() async {
    try {
      final byteData = await rootBundle.load('assets/blue_lemonade.png');
      return byteData.buffer.asUint8List();
    } catch (_) {
      try {
        final file = File('assets/blue_lemonade.png');
        if (await file.exists()) {
          return await file.readAsBytes();
        }
        final rootFile = File('blue_lemonade.png');
        if (await rootFile.exists()) {
          return await rootFile.readAsBytes();
        }
      } catch (_) {}
      return null;
    }
  }

  /// Renders the outro slide with blue_lemonade logo, "BlueLemonade, 2026",
  /// and a background color matching the app's 'theme' config.
  Future<Uint8List> _renderOutroFrameRgba({
    required ui.Image? logoImage,
    required bool isDark,
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // Background matching the app's 'theme' config
    final bgColor = isDark ? const Color(0xFF121216) : const Color(0xFFFFFFFF);
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = bgColor,
    );

    final double cx = width / 2.0;
    final double cy = height / 2.0;

    const double logoSize = 260.0;
    const double gap = 36.0;

    // Text painter for "BlueLemonade, 2026"
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
    final startY = cy - (totalHeight / 2.0);
    final logoRect = Rect.fromLTWH(cx - (logoSize / 2.0), startY, logoSize, logoSize);

    // Subtle soft shadow behind the circular badge
    final shadowColor = isDark ? const Color(0x33000000) : const Color(0x1A000000);
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(logoRect.center + const Offset(0, 5), logoSize / 2.0, shadowPaint);

    if (logoImage != null) {
      canvas.drawImageRect(
        logoImage,
        Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
        logoRect,
        Paint()..filterQuality = FilterQuality.high,
      );
    }

    // Text centered below logo
    final textX = cx - (textPainter.width / 2.0);
    final textY = startY + logoSize + gap;
    textPainter.paint(canvas, Offset(textX, textY));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  /// Renders a single frame of the splash screen animation into raw RGBA bytes.
  /// Background and element colors adapt to the app's 'theme' config, displaying
  /// the new app icon with rounded corners and ambient shadow.
  Future<Uint8List> _renderSplashFrameRgba({
    required double scale,
    required double opacity,
    required int width,
    required int height,
    required String appName,
    required bool isDark,
    required ui.Image? iconImage,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // Background matching the app's 'theme' config
    final bgColor = isDark ? const Color(0xFF121216) : const Color(0xFFFFFFFF);
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

    final double cx = width / 2.0;
    final double cy = height / 2.0;

    // Metrics matching SplashScreen with the new app icon
    const double iconSize = 140.0;
    const double cornerRadius = 32.0;
    const double gap = 28.0;

    // Text painter for App Name
    final textPainter = TextPainter(
      text: TextSpan(
        text: appName,
        style: TextStyle(
          color: textColor,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final totalContentHeight = iconSize + gap + textPainter.height;
    final startY = cy - (totalContentHeight / 2.0);
    final iconRect = Rect.fromLTWH(cx - (iconSize / 2.0), startY, iconSize, iconSize);
    final textY = startY + iconSize + gap;
    final textX = cx - (textPainter.width / 2.0);

    // Apply scale & opacity centered at (cx, cy)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale, scale);
    canvas.translate(-cx, -cy);

    final layerPaint = Paint()..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0));
    canvas.saveLayer(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), layerPaint);

    // Icon BoxShadow: soft ambient glow/shadow
    final shadowPaint = Paint()
      ..color = isDark ? const Color(0x66000000) : const Color(0x40B3D3E6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(iconRect.shift(const Offset(0, 8)), const Radius.circular(cornerRadius)),
      shadowPaint,
    );

    // Draw app icon image with rounded corners
    if (iconImage != null) {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(iconRect, const Radius.circular(cornerRadius)));
      canvas.drawImageRect(
        iconImage,
        Rect.fromLTWH(0, 0, iconImage.width.toDouble(), iconImage.height.toDouble()),
        iconRect,
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
    } else {
      // Fallback if image not loaded
      final fallbackPaint = Paint()
        ..color = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(iconRect, const Radius.circular(cornerRadius)),
        fallbackPaint,
      );
    }

    // Centered Text below icon
    textPainter.paint(canvas, Offset(textX, textY));

    canvas.restore(); // layer
    canvas.restore(); // transform

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  /// Blends frame [a] and frame [b] according to [progress] (0.0 = all [a], 1.0 = all [b]).
  Uint8List _crossfadeFrames(Uint8List a, Uint8List b, double progress) {
    assert(a.length == b.length);
    final out = Uint8List(a.length);
    final int wB = (progress.clamp(0.0, 1.0) * 256).round();
    final int wA = 256 - wB;
    for (int i = 0; i < a.length; i++) {
      out[i] = (a[i] * wA + b[i] * wB) >> 8;
    }
    return out;
  }

  Future<Uint8List> _renderSlideFrameRgba({
    required VideoSlideItem slide,
    required int width,
    required int height,
  }) async {
    // 1. Create base background canvas
    final canvas = img.Image(width: width, height: height, numChannels: 4);
    img.fill(canvas, color: img.ColorRgba8(18, 18, 22, 255));

    // 2. Load slide image
    try {
      final file = File(slide.imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        var decoded = img.decodeImage(bytes);
        if (decoded != null) {
          decoded = img.bakeOrientation(decoded);
          // Aspect fit image inside video canvas leaving space for bottom banner
          final availableHeight = height - 160;
          final scale = (width / decoded.width).clamp(0.0, availableHeight / decoded.height);
          final targetW = (decoded.width * scale).toInt().clamp(1, width);
          final targetH = (decoded.height * scale).toInt().clamp(1, availableHeight);

          final resized = img.copyResize(decoded, width: targetW, height: targetH);
          final offsetX = (width - targetW) ~/ 2;
          final offsetY = (availableHeight - targetH) ~/ 2 + 20;

          img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);
        }
      }
    } catch (e) {
      debugPrint('Error processing slide image: $e');
    }

    // 3. Draw bottom banner overlay
    const bannerHeight = 140;
    final bannerY = height - bannerHeight;

    img.fillRect(
      canvas,
      x1: 24,
      y1: bannerY,
      x2: width - 24,
      y2: height - 24,
      color: img.ColorRgba8(30, 32, 40, 220),
    );

    // 4. Draw texts: Date & Angle, and prominently Weight
    final infoText = '${slide.dateString}  •  ${slide.angleLabel}';
    final weightText = 'Weight: ${slide.weightString}';

    img.drawString(
      canvas,
      infoText,
      font: img.arial24,
      x: 48,
      y: bannerY + 24,
      color: img.ColorRgba8(200, 200, 210, 255),
    );

    img.drawString(
      canvas,
      weightText,
      font: img.arial48,
      x: 48,
      y: bannerY + 62,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    return canvas.getBytes(order: img.ChannelOrder.rgba);
  }

  /// Exports video via the platform-specific share sheet
  Future<void> exportVideo(String videoPath) async {
    final xfile = XFile(videoPath, mimeType: 'video/mp4');
    await SharePlus.instance.share(
      ShareParams(
        files: [xfile],
        subject: 'Body Tracker Progress Video',
        text: 'Here is my Body Tracker timeline progress video!',
      ),
    );
  }
}
