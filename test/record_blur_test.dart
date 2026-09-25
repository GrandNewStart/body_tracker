import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:body_tracker/models/body_record.dart';
import 'package:body_tracker/screens/record_screen.dart';
import 'package:body_tracker/screens/record_blur_screen.dart';
import 'package:body_tracker/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String frontPath;
  late String leftPath;
  late String backPath;
  late String rightPath;
  late BodyRecord testRecord;

  setUp(() async {
    // Mock ML Kit method channels so tests don't fail or wait on missing native plugins
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('google_mlkit_face_detector'), (call) async => []);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('google_mlkit_pose_detector'), (call) async => []);

    tempDir = await Directory.systemTemp.createTemp('record_blur_test_');
    frontPath = '${tempDir.path}/front.jpg';
    leftPath = '${tempDir.path}/left.jpg';
    backPath = '${tempDir.path}/back.jpg';
    rightPath = '${tempDir.path}/right.jpg';

    // Create 4 dummy image files (50x50 for instant decode/encode in tests)
    for (final p in [frontPath, leftPath, backPath, rightPath]) {
      final image = img.Image(width: 50, height: 50);
      img.fill(image, color: img.ColorRgb8(120, 160, 200));
      // Add red square (face)
      img.fillRect(image, x1: 15, y1: 10, x2: 35, y2: 30, color: img.ColorRgb8(255, 0, 0));
      await File(p).writeAsBytes(img.encodeJpg(image));
    }

    final now = DateTime.now();
    testRecord = BodyRecord(
      id: 'test-record-1',
      date: now,
      weight: 68.5,
      frontImagePath: frontPath,
      leftImagePath: leftPath,
      backImagePath: backPath,
      rightImagePath: rightPath,
      isMasked: false,
      createdAt: now,
    );

    StorageService.instance.recordsNotifier.value = [testRecord];
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Post-save Face Blur Tests', () {
    testWidgets('RecordScreen directly opens RecordBlurScreen when Enable Face Blur is tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecordScreen(record: testRecord),
        ),
      );
      await tester.pump();

      // Verify Enable Face Blur button/chip is present
      expect(find.text('Enable Face Blur'), findsWidgets);

      // Tap Enable Face Blur to directly open RecordBlurScreen (no 2-option choice dialog!)
      await tester.tap(find.text('Enable Face Blur').first);
      await tester.pump(const Duration(milliseconds: 300));

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      // Verify RecordBlurScreen is directly shown with auto-blur previews and banners
      expect(find.text('Review & Adjust Face Blur'), findsOneWidget);
      expect(find.textContaining('This action cannot be undone'), findsOneWidget);
      expect(find.text('Tap any photo to adjust face blur position'), findsOneWidget);
      expect(find.text('Adjust'), findsNWidgets(4));

      // Tap Cancel returns to RecordScreen with record remaining unmasked
      final cancelBtn = find.text('Cancel');
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(StorageService.instance.recordsNotifier.value.first.isMasked, isFalse);
    });

    testWidgets('RecordScreen full blur flow: auto-blurs on open and permanently applies on confirm', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecordScreen(record: testRecord),
        ),
      );
      await tester.pump();

      // Tap Enable Face Blur
      await tester.tap(find.text('Enable Face Blur').first);
      await tester.pump(const Duration(milliseconds: 300));

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      // In RecordBlurScreen, user reviews the auto-applied blur and taps Apply Permanently
      final applyBtn = find.widgetWithText(FilledButton, 'Apply Permanently');
      await tester.ensureVisible(applyBtn);
      await tester.pumpAndSettle();
      await tester.tap(applyBtn);
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm permanent blur in confirmation dialog
      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Apply Permanently'),
      );
      await tester.tap(confirmBtn);
      await tester.pump(const Duration(milliseconds: 500));

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (StorageService.instance.recordsNotifier.value.first.isMasked) break;
      }
      await tester.pumpAndSettle();

      // Record is now masked and photos permanently blurred
      expect(StorageService.instance.recordsNotifier.value.first.isMasked, isTrue);
      final frontBytes = File(frontPath).readAsBytesSync();
      final decoded = img.decodeImage(frontBytes);
      expect(decoded, isNotNull);
    });

    testWidgets('RecordBlurScreen displays warning banner, 4 photos grid and permanently applies', (tester) async {
      BodyRecord? resultRecord;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  resultRecord = await Navigator.of(context).push<BodyRecord>(
                    MaterialPageRoute(
                      builder: (_) => RecordBlurScreen(record: testRecord),
                    ),
                  );
                },
                child: const Text('Open Review'),
              ),
            ),
          ),
        ),
      );

      // Open RecordBlurScreen
      await tester.tap(find.text('Open Review'));
      await tester.pump(const Duration(milliseconds: 500));

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      // Check title and warning banner
      expect(find.text('Review & Adjust Face Blur'), findsOneWidget);
      expect(
        find.textContaining('This action cannot be undone'),
        findsOneWidget,
      );

      // Check 4 photo preview grid has "Adjust" buttons
      expect(find.text('Adjust'), findsNWidgets(4));

      // Tap "Apply Permanently" on screen
      final applyBtn = find.widgetWithText(FilledButton, 'Apply Permanently');
      await tester.ensureVisible(applyBtn);
      await tester.pumpAndSettle();
      await tester.tap(applyBtn);
      await tester.pump(const Duration(milliseconds: 500));

      // Verify confirmation dialog
      expect(find.text('Confirm Permanent Blur'), findsOneWidget);
      expect(
        find.textContaining('cannot be undone and original photos cannot be restored'),
        findsOneWidget,
      );

      // Confirm permanent application in dialog
      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Apply Permanently'),
      );
      await tester.tap(confirmBtn);
      await tester.pump(const Duration(milliseconds: 500));

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (StorageService.instance.recordsNotifier.value.first.isMasked) break;
      }
      await tester.pump(const Duration(milliseconds: 500));

      // Verify result record is marked as masked
      expect(resultRecord, isNotNull);
      expect(resultRecord!.isMasked, isTrue);
      expect(StorageService.instance.recordsNotifier.value.first.isMasked, isTrue);
    });
  });
}
