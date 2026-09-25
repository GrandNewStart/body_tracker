import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_tracker/models/body_angle.dart';
import 'package:body_tracker/models/body_record.dart';
import 'package:body_tracker/screens/profile_screen.dart';
import 'package:body_tracker/services/storage_service.dart';
import 'package:body_tracker/services/video_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final record1 = BodyRecord(
    id: 'rec-1',
    date: DateTime(2026, 1, 1),
    weight: 75.0,
    frontImagePath: '/path/rec1_front.jpg',
    leftImagePath: '/path/rec1_left.jpg',
    backImagePath: '/path/rec1_back.jpg',
    rightImagePath: '/path/rec1_right.jpg',
    createdAt: DateTime(2026, 1, 1),
  );

  final record2 = BodyRecord(
    id: 'rec-2',
    date: DateTime(2026, 1, 10),
    weight: 73.5,
    frontImagePath: '/path/rec2_front.jpg',
    leftImagePath: '/path/rec2_left.jpg',
    backImagePath: '/path/rec2_back.jpg',
    rightImagePath: '/path/rec2_right.jpg',
    createdAt: DateTime(2026, 1, 10),
  );

  group('VideoService Profile Selection Tests', () {
    test('Default all 4 profiles selected includes all 4 angles for each record', () {
      final slides = VideoService.instance.buildSlideItems(
        records: [record1, record2],
        isKorean: false,
      );

      expect(slides.length, equals(8));
      expect(slides[0].angleLabel, equals('Front'));
      expect(slides[0].imagePath, contains('rec1_front.jpg'));
      expect(slides[1].angleLabel, equals('Left'));
      expect(slides[1].imagePath, contains('rec1_left.jpg'));
      expect(slides[2].angleLabel, equals('Back'));
      expect(slides[2].imagePath, contains('rec1_back.jpg'));
      expect(slides[3].angleLabel, equals('Right'));
      expect(slides[3].imagePath, contains('rec1_right.jpg'));

      expect(slides[4].angleLabel, equals('Front'));
      expect(slides[4].imagePath, contains('rec2_front.jpg'));
      expect(slides[5].angleLabel, equals('Left'));
      expect(slides[5].imagePath, contains('rec2_left.jpg'));
      expect(slides[6].angleLabel, equals('Back'));
      expect(slides[6].imagePath, contains('rec2_back.jpg'));
      expect(slides[7].angleLabel, equals('Right'));
      expect(slides[7].imagePath, contains('rec2_right.jpg'));
    });

    test('Single profile selected (Front only) includes only front images in date order', () {
      final slides = VideoService.instance.buildSlideItems(
        records: [record2, record1], // Out of order input to test sorting
        isKorean: true,
        selectedAngles: {BodyAngle.front},
      );

      expect(slides.length, equals(2));
      // First is record1 (earlier date)
      expect(slides[0].dateString, equals('2026.01.01'));
      expect(slides[0].angleLabel, equals('정면'));
      expect(slides[0].imagePath, contains('rec1_front.jpg'));

      // Second is record2 (later date)
      expect(slides[1].dateString, equals('2026.01.10'));
      expect(slides[1].angleLabel, equals('정면'));
      expect(slides[1].imagePath, contains('rec2_front.jpg'));
    });

    test('Two profiles selected (Front & Left) generates 2 angles per record', () {
      final slides = VideoService.instance.buildSlideItems(
        records: [record1, record2],
        isKorean: false,
        selectedAngles: {BodyAngle.front, BodyAngle.left},
      );

      expect(slides.length, equals(4));
      // Record 1
      expect(slides[0].angleLabel, equals('Front'));
      expect(slides[0].imagePath, contains('rec1_front.jpg'));
      expect(slides[1].angleLabel, equals('Left'));
      expect(slides[1].imagePath, contains('rec1_left.jpg'));

      // Record 2
      expect(slides[2].angleLabel, equals('Front'));
      expect(slides[2].imagePath, contains('rec2_front.jpg'));
      expect(slides[3].angleLabel, equals('Left'));
      expect(slides[3].imagePath, contains('rec2_left.jpg'));
    });

    test('Non-contiguous profiles selected (Front & Back) correctly filters and preserves order', () {
      final slides = VideoService.instance.buildSlideItems(
        records: [record1],
        isKorean: true,
        selectedAngles: {BodyAngle.back, BodyAngle.front},
      );

      expect(slides.length, equals(2));
      expect(slides[0].angleLabel, equals('정면'));
      expect(slides[1].angleLabel, equals('후면'));
    });

    test('Empty selectedAngles returns empty slide list', () {
      final slides = VideoService.instance.buildSlideItems(
        records: [record1, record2],
        isKorean: false,
        selectedAngles: {},
      );

      expect(slides, isEmpty);
    });
  });

  group('ProfileScreen Video Dialog Profile Selection Widget Tests', () {
    setUp(() {
      StorageService.instance.recordsNotifier.value = [record1, record2];
    });

    testWidgets('Dialog renders profile selection chips, dynamic slide count, and disables on empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the Render Video floating action button
      final renderVideoBtn = find.widgetWithText(FloatingActionButton, 'Render Video');
      expect(renderVideoBtn, findsOneWidget);
      await tester.tap(renderVideoBtn);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Create Timeline Video'), findsOneWidget);
      expect(find.text('Select profiles to include:'), findsOneWidget);

      // Verify all 4 FilterChips exist
      expect(find.widgetWithText(FilterChip, 'Front'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Left'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Back'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Right'), findsOneWidget);

      // Verify initial total slides summary (2 records * 4 profiles = 8 slides)
      expect(find.textContaining('Total Slides: 8 (2 days × 4 profiles)'), findsOneWidget);

      // Unselect Left, Back, Right so only Front remains
      await tester.tap(find.widgetWithText(FilterChip, 'Left'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Right'));
      await tester.pumpAndSettle();

      // Summary should update dynamically: 2 records * 1 profile = 2 slides!
      expect(find.textContaining('Total Slides: 2 (2 days × 1 profiles)'), findsOneWidget);

      // Now unselect Front as well -> 0 selected
      await tester.tap(find.widgetWithText(FilterChip, 'Front'));
      await tester.pumpAndSettle();

      // Validation error shown
      expect(find.text('Please select at least one profile.'), findsOneWidget);

      // The dialog action "Render Video" button should now be disabled
      final dialogRenderBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Render Video'),
      );
      expect(dialogRenderBtn.onPressed, isNull);

      // Re-select Front and Left -> 2 selected, button re-enabled
      await tester.tap(find.widgetWithText(FilterChip, 'Front'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Left'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Total Slides: 4 (2 days × 2 profiles)'), findsOneWidget);
      final reenabledBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Render Video'),
      );
      expect(reenabledBtn.onPressed, isNotNull);

      // Tap Cancel to dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
