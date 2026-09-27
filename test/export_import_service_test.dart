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
}
