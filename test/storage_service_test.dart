import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_tracker/models/body_record.dart';
import 'package:body_tracker/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService path resolution tests', () {
    test('resolveImagePath recovers files when sandbox directory UUID changes', () async {
      // Simulate creating a photo in photos directory
      final tempDir = await Directory.systemTemp.createTemp('body_tracker_test');
      final photosDir = Directory('${tempDir.path}/photos');
      await photosDir.create(recursive: true);

      final dummyPhoto = File('${photosDir.path}/20260917_test_front.jpg');
      await dummyPhoto.writeAsString('test photo content');

      // Old outdated path from a previous app build with different sandbox UUID
      const outdatedOldUuidPath =
          '/var/mobile/Containers/Data/Application/OLD-UUID-1234/Documents/photos/20260917_test_front.jpg';

      // Fallback when uninitialized returns storedPath
      expect(StorageService.instance.resolveImagePath(outdatedOldUuidPath), outdatedOldUuidPath);

      // Clean up
      await tempDir.delete(recursive: true);
    });

    test('BodyRecord copyWith updates paths', () {
      final now = DateTime.now();
      final record = BodyRecord(
        id: 'rec-1',
        date: now,
        weight: 70.0,
        frontImagePath: '/old/front.jpg',
        leftImagePath: '/old/left.jpg',
        backImagePath: '/old/back.jpg',
        rightImagePath: '/old/right.jpg',
        createdAt: now,
      );

      final updated = record.copyWith(
        frontImagePath: '/new/front.jpg',
      );

      expect(updated.frontImagePath, '/new/front.jpg');
      expect(updated.leftImagePath, '/old/left.jpg');
    });

    test('StorageService updateRecord updates record in recordsNotifier', () async {
      final now = DateTime.now();
      final record = BodyRecord(
        id: 'rec-test-1',
        date: now,
        weight: 70.0,
        frontImagePath: '/front.jpg',
        leftImagePath: '/left.jpg',
        backImagePath: '/back.jpg',
        rightImagePath: '/right.jpg',
        isMasked: false,
        createdAt: now,
      );

      StorageService.instance.recordsNotifier.value = [record];

      final updated = record.copyWith(isMasked: true);
      await StorageService.instance.updateRecord(updated);

      expect(StorageService.instance.recordsNotifier.value.first.isMasked, true);
    });
  });
}
