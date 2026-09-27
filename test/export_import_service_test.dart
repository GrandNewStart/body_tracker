import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_tracker/models/body_record.dart';
import 'package:body_tracker/services/export_import_service.dart';
import 'package:body_tracker/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('export_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async {
      return tempDir.path;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('deriveKeyFromPassword produces 32-byte key matching SHA-256 of password', () {
    const password = 'SuperSecretPassword2026!';
    final key = ExportImportService.instance.deriveKeyFromPassword(password);

    final expectedHash = sha256.convert(utf8.encode(password)).bytes;
    expect(key.bytes, equals(expectedHash));
    expect(key.bytes.length, equals(32));
  });

  test('exportRecords creates AES-encrypted .bodytracker file and decryptPackage recovers data', () async {
    final storage = StorageService.instance;
    await storage.init();

    // Create a dummy photo file
    final photoFile = File('${storage.photosDirPath}/test_front.jpg');
    await photoFile.writeAsBytes([10, 20, 30, 40, 50, 60]);

    // Create a sample record
    final now = DateTime.now();
    final sampleRecord = BodyRecord(
      id: 'export-test-rec-1',
      date: now,
      weight: 72.5,
      frontImagePath: photoFile.path,
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      isMasked: false,
      createdAt: now,
    );
    await storage.addRecord(sampleRecord);

    const password = 'TestUserPassword!99';

    // Export records
    final exportedFile = await ExportImportService.instance.exportRecords(password: password);

    expect(exportedFile.existsSync(), isTrue);
    expect(exportedFile.path.endsWith('.bodytracker'), isTrue);

    // Verify filename is date string format: yyyyMMdd_HHmmss.bodytracker
    final fileName = exportedFile.path.split(RegExp(r'[/\\]')).last;
    final baseName = fileName.replaceAll('.bodytracker', '');
    expect(RegExp(r'^\d{8}_\d{6}$').hasMatch(baseName), isTrue);

    // Verify file content is encrypted (cannot be read directly as zip)
    final fileBytes = await exportedFile.readAsBytes();
    expect(fileBytes[0], 0x42); // 'B'
    expect(fileBytes[1], 0x54); // 'T'
    expect(fileBytes[2], 0x01); // Version 1

    // Decrypt with correct password
    final decryptedData = await ExportImportService.instance.decryptPackage(
      packageBytes: fileBytes,
      password: password,
    );

    expect(decryptedData.records.length, 1);
    expect(decryptedData.records.first.id, sampleRecord.id);
    expect(decryptedData.records.first.weight, 72.5);
    expect(decryptedData.photos.containsKey('photos/test_front.jpg'), isTrue);
    expect(decryptedData.photos['photos/test_front.jpg'], equals([10, 20, 30, 40, 50, 60]));

    // Decrypt with WRONG password should throw InvalidPasswordException
    expect(
      () => ExportImportService.instance.decryptPackage(
        packageBytes: fileBytes,
        password: 'wrong_password_here',
      ),
      throwsA(isA<InvalidPasswordException>()),
    );

    // Decrypt corrupted package should throw InvalidPackageFormatException
    final corruptedBytes = Uint8List.fromList([1, 2, 3]);
    expect(
      () => ExportImportService.instance.decryptPackage(
        packageBytes: corruptedBytes,
        password: password,
      ),
      throwsA(isA<InvalidPackageFormatException>()),
    );
  });

  test('isCollision correctly identifies collisions by id or by same calendar day', () {
    final now = DateTime(2026, 9, 20, 10, 30);
    final rec1 = BodyRecord(
      id: 'rec-1',
      date: now,
      weight: 70.0,
      frontImagePath: '',
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      createdAt: now,
    );

    // Same id, different date -> collision
    final recSameId = BodyRecord(
      id: 'rec-1',
      date: DateTime(2026, 9, 25),
      weight: 71.0,
      frontImagePath: '',
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      createdAt: DateTime(2026, 9, 25),
    );
    expect(ExportImportService.isCollision(rec1, recSameId), isTrue);

    // Different id, same date (different hour) -> collision
    final recSameDate = BodyRecord(
      id: 'rec-2',
      date: DateTime(2026, 9, 20, 18, 45),
      weight: 70.5,
      frontImagePath: '',
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      createdAt: DateTime(2026, 9, 20, 18, 45),
    );
    expect(ExportImportService.isCollision(rec1, recSameDate), isTrue);

    // Different id, different date -> no collision
    final recDifferent = BodyRecord(
      id: 'rec-3',
      date: DateTime(2026, 9, 21),
      weight: 69.5,
      frontImagePath: '',
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      createdAt: DateTime(2026, 9, 21),
    );
    expect(ExportImportService.isCollision(rec1, recDifferent), isFalse);
  });

  test('restoreAndMergePackage restores photos and merges records, handling collisions', () async {
    final storage = StorageService.instance;
    await storage.init();
    await storage.clearAllData();

    // 1. Setup existing record
    final date1 = DateTime(2026, 9, 20, 10, 0);
    final existingRec = BodyRecord(
      id: 'rec-existing',
      date: date1,
      weight: 70.0,
      frontImagePath: '${storage.photosDirPath}/old_front.jpg',
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      createdAt: date1,
    );
    // Write old photo file
    await File('${storage.photosDirPath}/old_front.jpg').writeAsBytes([1, 1, 1]);
    await storage.addRecord(existingRec);

    // 2. Prepare imported package data: 1 colliding record (updated weight), 1 new record
    final date2 = DateTime(2026, 9, 21, 12, 0);
    final collidingImportedRec = BodyRecord(
      id: 'rec-existing', // same ID -> collision
      date: date1,
      weight: 73.5, // updated weight
      frontImagePath: 'photos/new_front_20.jpg',
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      createdAt: date1,
    );
    final newImportedRec = BodyRecord(
      id: 'rec-brand-new',
      date: date2,
      weight: 74.0,
      frontImagePath: 'photos/new_front_21.jpg',
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      createdAt: date2,
    );

    final packageData = ExportPackageData(
      version: 1,
      exportedAt: DateTime.now(),
      records: [collidingImportedRec, newImportedRec],
      photos: {
        'photos/new_front_20.jpg': [2, 2, 2],
        'photos/new_front_21.jpg': [3, 3, 3],
      },
    );

    // Test findCollisions
    final collisions = ExportImportService.instance.findCollisions(
      storage.records,
      packageData.records,
    );
    expect(collisions.length, 1);
    expect(collisions.first.id, 'rec-existing');

    // Restore with overwriteCollisions: true
    final count = await ExportImportService.instance.restoreAndMergePackage(
      packageData: packageData,
      overwriteCollisions: true,
    );

    expect(count, 2);
    expect(storage.records.length, 2);

    // Overwritten record should have updated weight
    final updatedRec = storage.records.firstWhere((r) => r.id == 'rec-existing');
    expect(updatedRec.weight, 73.5);
    expect(updatedRec.frontImagePath, '${storage.photosDirPath}/new_front_20.jpg');

    // New photo files should exist on disk
    expect(File('${storage.photosDirPath}/new_front_20.jpg').existsSync(), isTrue);
    expect(File('${storage.photosDirPath}/new_front_21.jpg').existsSync(), isTrue);
    expect(await File('${storage.photosDirPath}/new_front_20.jpg').readAsBytes(), [2, 2, 2]);

    // Old photo should have been cleaned up because it was replaced
    expect(File('${storage.photosDirPath}/old_front.jpg').existsSync(), isFalse);
  });

  test('restoreAndMergePackage with overwriteCollisions: false keeps existing record', () async {
    final storage = StorageService.instance;
    await storage.init();
    await storage.clearAllData();

    final date1 = DateTime(2026, 9, 20, 10, 0);
    final existingRec = BodyRecord(
      id: 'rec-existing',
      date: date1,
      weight: 70.0,
      frontImagePath: '',
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      createdAt: date1,
    );
    await storage.addRecord(existingRec);

    final collidingImportedRec = BodyRecord(
      id: 'rec-existing',
      date: date1,
      weight: 75.0,
      frontImagePath: '',
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      createdAt: date1,
    );
    final nonCollidingRec = BodyRecord(
      id: 'rec-new',
      date: DateTime(2026, 9, 21),
      weight: 68.0,
      frontImagePath: '',
      leftImagePath: '',
      backImagePath: '',
      rightImagePath: '',
      createdAt: DateTime(2026, 9, 21),
    );

    final packageData = ExportPackageData(
      version: 1,
      exportedAt: DateTime.now(),
      records: [collidingImportedRec, nonCollidingRec],
      photos: {},
    );

    final count = await ExportImportService.instance.restoreAndMergePackage(
      packageData: packageData,
      overwriteCollisions: false,
    );

    // Only non-colliding record added
    expect(count, 1);
    expect(storage.records.length, 2);
    final preservedRec = storage.records.firstWhere((r) => r.id == 'rec-existing');
    expect(preservedRec.weight, 70.0); // Not overwritten
  });

  test('decryptPackage throws InvalidPackageFormatException on invalid header or version', () async {
    const password = 'test';
    // Wrong magic bytes: 'XX' instead of 'BT'
    final wrongMagic = Uint8List.fromList([
      0x58, 0x58, 0x01,
      ...List.filled(16, 0),
      ...List.filled(32, 0),
    ]);
    expect(
      () => ExportImportService.instance.decryptPackage(
        packageBytes: wrongMagic,
        password: password,
      ),
      throwsA(isA<InvalidPackageFormatException>()),
    );

    // Unsupported format version: 99
    final wrongVersion = Uint8List.fromList([
      0x42, 0x54, 0x63, // 0x63 = 99
      ...List.filled(16, 0),
      ...List.filled(32, 0),
    ]);
    expect(
      () => ExportImportService.instance.decryptPackage(
        packageBytes: wrongVersion,
        password: password,
      ),
      throwsA(isA<InvalidPackageFormatException>()),
    );
  });
}
