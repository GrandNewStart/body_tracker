import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:body_tracker/models/face_mask_region.dart';
import 'package:body_tracker/screens/face_adjustment_screen.dart';
import 'package:body_tracker/services/ml_service.dart';

void main() {
  group('FaceMaskRegion Model Tests', () {
    test('defaultHead has reasonable coordinates', () {
      expect(FaceMaskRegion.defaultHead.x, equals(0.5));
      expect(FaceMaskRegion.defaultHead.y, equals(0.18));
      expect(FaceMaskRegion.defaultHead.radius, equals(0.14));
      expect(FaceMaskRegion.defaultHead.center, equals(const Offset(0.5, 0.18)));
    });

    test('JSON serialization and deserialization', () {
      const region = FaceMaskRegion(x: 0.45, y: 0.22, radius: 0.16);
      final json = region.toJson();

      expect(json['x'], equals(0.45));
      expect(json['y'], equals(0.22));
      expect(json['radius'], equals(0.16));

      final fromJson = FaceMaskRegion.fromJson(json);
      expect(fromJson, equals(region));
      expect(fromJson.hashCode, equals(region.hashCode));
    });

    test('copyWith updates specified fields', () {
      const region = FaceMaskRegion(x: 0.5, y: 0.2, radius: 0.15);
      final updated = region.copyWith(x: 0.6, radius: 0.2);

      expect(updated.x, equals(0.6));
      expect(updated.y, equals(0.2));
      expect(updated.radius, equals(0.2));
    });
  });

  group('Mosaic Downscaling & Canvas Tests', () {
    test('instantiateImageCodec downscaling creates valid mosaic ui.Image', () async {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, 100, 100));
      canvas.drawRect(const Rect.fromLTWH(0, 0, 50, 50), Paint()..color = Colors.red);
      canvas.drawRect(const Rect.fromLTWH(50, 0, 50, 50), Paint()..color = Colors.blue);
      canvas.drawRect(const Rect.fromLTWH(0, 50, 50, 50), Paint()..color = Colors.green);
      canvas.drawRect(const Rect.fromLTWH(50, 50, 50, 50), Paint()..color = Colors.yellow);
      final pic = rec.endRecording();
      final srcImage = await pic.toImage(100, 100);
      final byteData = await srcImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 10);
      final frame = await codec.getNextFrame();
      final mosaicImage = frame.image;

      expect(mosaicImage.width, equals(10));
      expect(mosaicImage.height, equals(10));

      final paintRec = ui.PictureRecorder();
      final paintCanvas = Canvas(paintRec, const Rect.fromLTWH(0, 0, 200, 200));

      final painter = MosaicCirclePainter(
        mosaicImage: mosaicImage,
        center: const Offset(100, 100),
        radius: 50,
        primaryColor: Colors.blue,
      );
      painter.paint(paintCanvas, const Size(200, 200));

      final resultPic = paintRec.endRecording();
      final resultImg = await resultPic.toImage(200, 200);
      expect(resultImg.width, equals(200));
      expect(resultImg.height, equals(200));
    });
  });

  group('MlService Masking Tests', () {
    late Directory tempDir;
    late String testImagePath;
    late String maskedOutputPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_service_test_');
      testImagePath = '${tempDir.path}/test_image.jpg';
      maskedOutputPath = '${tempDir.path}/masked_output.jpg';

      // Create a dummy 200x200 image with distinct colored quadrants
      final testImg = img.Image(width: 200, height: 200);
      img.fill(testImg, color: img.ColorRgb8(255, 255, 255));
      // Put a red square in the center (representing a face)
      img.fillRect(
        testImg,
        x1: 70,
        y1: 50,
        x2: 130,
        y2: 110,
        color: img.ColorRgb8(255, 0, 0),
      );
      final jpgBytes = img.encodeJpg(testImg);
      await File(testImagePath).writeAsBytes(jpgBytes);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('applyFaceMask creates masked image at specified circular region', () async {
      const region = FaceMaskRegion(x: 0.5, y: 0.4, radius: 0.2);
      final out = await MlService.instance.applyFaceMask(
        originalImagePath: testImagePath,
        maskedOutputPath: maskedOutputPath,
        region: region,
      );

      expect(out, equals(maskedOutputPath));
      expect(File(maskedOutputPath).existsSync(), isTrue);

      final maskedBytes = await File(maskedOutputPath).readAsBytes();
      final decoded = img.decodeImage(maskedBytes);
      expect(decoded, isNotNull);
      if (decoded != null) {
        expect(decoded.width, equals(200));
        expect(decoded.height, equals(200));
      }
    });

    test('maskFaceInImage with customRegion applies to that region directly', () async {
      const customRegion = FaceMaskRegion(x: 0.3, y: 0.3, radius: 0.15);
      final out = await MlService.instance.maskFaceInImage(
        originalImagePath: testImagePath,
        maskedOutputPath: maskedOutputPath,
        customRegion: customRegion,
      );

      expect(out, equals(maskedOutputPath));
      expect(File(maskedOutputPath).existsSync(), isTrue);
    });
  });

  group('FaceAdjustmentScreen Widget Tests', () {
    late Directory tempDir;
    late String testImagePath;

    late Uint8List testImageBytes;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('widget_test_');
      testImagePath = '${tempDir.path}/test_widget_image.jpg';

      final testImg = img.Image(width: 300, height: 400);
      img.fill(testImg, color: img.ColorRgb8(100, 150, 200));
      testImageBytes = Uint8List.fromList(img.encodeJpg(testImg));
      await File(testImagePath).writeAsBytes(testImageBytes);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('FaceAdjustmentScreen renders image, circle, slider and handles dragging', (tester) async {
      late ui.Image mosaicImage;
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(testImageBytes, targetWidth: 45);
        final frame = await codec.getNextFrame();
        mosaicImage = frame.image;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: FaceAdjustmentScreen(
            imagePath: testImagePath,
            imageBytes: testImageBytes,
            preloadedMosaicImage: mosaicImage,
            preloadedNaturalSize: const Size(300, 400),
            angleLabel: 'Front',
            initialRegion: const FaceMaskRegion(x: 0.5, y: 0.2, radius: 0.15),
            autoDetectedRegion: const FaceMaskRegion(x: 0.5, y: 0.2, radius: 0.15),
          ),
        ),
      );
      await tester.pump();

      // Verify AppBar and elements
      expect(find.text('Front - Adjust Face Blur'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Test slider interaction
      final sliderFinder = find.byType(Slider);
      await tester.tap(sliderFinder);
      await tester.pump();

      // Test drag gesture on the photo area
      final gestureFinder = find.byType(GestureDetector).first;
      await tester.drag(gestureFinder, const Offset(30, 40));
      await tester.pump();

      // Test Reset button
      final resetFinder = find.text('Reset').first;
      await tester.tap(resetFinder);
      await tester.pump();

      // Test Apply button exists (both in AppBar and bottom bar)
      final applyFinder = find.text('Apply');
      expect(applyFinder, findsNWidgets(2));
    });
  });
}
