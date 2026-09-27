import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/body_record.dart';
import 'storage_service.dart';

/// Custom exception thrown when decryption fails due to an invalid password.
class InvalidPasswordException implements Exception {
  final String message;
  const InvalidPasswordException([this.message = 'Invalid password for backup file']);

  @override
  String toString() => message;
}

/// Custom exception thrown when the file is not a valid BodyTracker package.
class InvalidPackageFormatException implements Exception {
  final String message;
  const InvalidPackageFormatException([this.message = 'Invalid package format']);

  @override
  String toString() => message;
}

/// Custom exception thrown when trying to export with no records.
class NoRecordsToExportException implements Exception {
  final String message;
  const NoRecordsToExportException([this.message = 'No records available to export']);

  @override
  String toString() => message;
}

/// Data extracted from an exported package file.
class ExportPackageData {
  final int version;
  final DateTime exportedAt;
  final List<BodyRecord> records;
  final Map<String, List<int>> photos; // relative path -> file bytes

  const ExportPackageData({
    required this.version,
    required this.exportedAt,
    required this.records,
    required this.photos,
  });
}

class ExportImportService {
  static final ExportImportService instance = ExportImportService._internal();
  ExportImportService._internal();

  /// Magic header bytes: 'BT' (BodyTracker)
  static const List<int> magicBytes = [0x42, 0x54];
  static const int currentFormatVersion = 1;
  static const String packageExtension = '.bodytracker';

  /// Generates the 256-bit AES encryption key from the SHA-256 hash of the password.
  enc.Key deriveKeyFromPassword(String password) {
    final hashBytes = sha256.convert(utf8.encode(password)).bytes;
    return enc.Key(Uint8List.fromList(hashBytes));
  }

  /// Exports all records and photos into a compressed, AES-encrypted `.bodytracker` package file.
  Future<File> exportRecords({
    required String password,
    void Function(double progress, String status)? onProgress,
  }) async {
    final storage = StorageService.instance;
    final records = storage.records;

    if (records.isEmpty) {
      throw const NoRecordsToExportException();
    }

    onProgress?.call(0.1, 'Collecting records and photos...');

    final archive = Archive();
    final sanitizedRecords = <Map<String, dynamic>>[];
    final addedPhotoFiles = <String>{};

    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      final recordJson = record.toJson();

      // Helper to add each angle's photo to archive if it exists
      String processPhoto(String rawPath, String angleSuffix) {
        if (rawPath.isEmpty) return '';
        final resolvedPath = storage.resolveImagePath(rawPath);
        final file = File(resolvedPath);
        if (file.existsSync()) {
          final fileName = resolvedPath.split(RegExp(r'[/\\]')).last;
          final relPath = 'photos/$fileName';
          if (!addedPhotoFiles.contains(relPath)) {
            try {
              final bytes = file.readAsBytesSync();
              archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
              addedPhotoFiles.add(relPath);
            } catch (e) {
              debugPrint('Error reading photo $resolvedPath: $e');
            }
          }
          return relPath;
        }
        return '';
      }

      recordJson['front_image_path'] = processPhoto(record.frontImagePath, 'front');
      recordJson['left_image_path'] = processPhoto(record.leftImagePath, 'left');
      recordJson['back_image_path'] = processPhoto(record.backImagePath, 'back');
      recordJson['right_image_path'] = processPhoto(record.rightImagePath, 'right');

      sanitizedRecords.add(recordJson);
    }

    onProgress?.call(0.4, 'Creating metadata archive...');

    final metaMap = {
      'version': currentFormatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'record_count': records.length,
      'records': sanitizedRecords,
    };

    final metaBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(metaMap));
    archive.addFile(ArchiveFile('records.json', metaBytes.length, metaBytes));

    onProgress?.call(0.6, 'Compressing package...');

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    onProgress?.call(0.8, 'Encrypting package with AES...');

    // Derive 256-bit AES key from SHA-256(password)
    final key = deriveKeyFromPassword(password);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(zipBytes, iv: iv);

    // Package format: [2 bytes Magic 'BT'] + [1 byte Format Version] + [16 bytes IV] + [Ciphertext]
    final payload = BytesBuilder(copy: false)
      ..add(magicBytes)
      ..addByte(currentFormatVersion)
      ..add(iv.bytes)
      ..add(encrypted.bytes);

    final packageBytes = payload.toBytes();

    onProgress?.call(0.95, 'Writing package file to disk...');

    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    // File name format: date string of the moment (e.g. 20260927_223000.bodytracker)
    final dateString = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final exportFile = File('${exportDir.path}/$dateString$packageExtension');
    await exportFile.writeAsBytes(packageBytes, flush: true);

    onProgress?.call(1.0, 'Export complete!');
    return exportFile;
  }

  /// Decrypts and unpacks a `.bodytracker` package, returning its records and photos.
  Future<ExportPackageData> decryptPackage({
    required Uint8List packageBytes,
    required String password,
  }) async {
    // Minimum header size: 2 bytes magic + 1 byte version + 16 bytes IV = 19 bytes
    if (packageBytes.length < 19) {
      throw const InvalidPackageFormatException('File size is too small to be a valid backup');
    }

    // Verify magic bytes 'BT'
    if (packageBytes[0] != magicBytes[0] || packageBytes[1] != magicBytes[1]) {
      throw const InvalidPackageFormatException('Not a valid BodyTracker package file');
    }

    final version = packageBytes[2];
    if (version > currentFormatVersion) {
      throw InvalidPackageFormatException('Unsupported package version: $version');
    }

    final ivBytes = packageBytes.sublist(3, 19);
    final cipherText = packageBytes.sublist(19);

    final key = deriveKeyFromPassword(password);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    List<int> decryptedBytes;
    try {
      decryptedBytes = encrypter.decryptBytes(enc.Encrypted(cipherText), iv: iv);
    } catch (e) {
      // PKCS7 padding failure or corrupted block
      throw const InvalidPasswordException();
    }

    // Verify ZIP magic header: 0x50, 0x4B, 0x03, 0x04 ('PK\x03\x04')
    if (decryptedBytes.length < 4 ||
        decryptedBytes[0] != 0x50 ||
        decryptedBytes[1] != 0x4B ||
        decryptedBytes[2] != 0x03 ||
        decryptedBytes[3] != 0x04) {
      throw const InvalidPasswordException();
    }

    // Unpack ZIP archive
    final archive = ZipDecoder().decodeBytes(decryptedBytes);
    final metaFile = archive.findFile('records.json');
    if (metaFile == null) {
      throw const InvalidPackageFormatException('records.json not found in package');
    }

    final metaJson = jsonDecode(utf8.decode(metaFile.content as List<int>)) as Map<String, dynamic>;
    final recordsJsonList = metaJson['records'] as List<dynamic>? ?? [];
    final exportedAt = DateTime.tryParse(metaJson['exported_at'] as String? ?? '') ?? DateTime.now();

    final List<BodyRecord> parsedRecords = [];
    for (final item in recordsJsonList) {
      parsedRecords.add(BodyRecord.fromJson(item as Map<String, dynamic>));
    }

    final Map<String, List<int>> photos = {};
    for (final file in archive.files) {
      if (file.name.startsWith('photos/') && !file.isDirectory) {
        photos[file.name] = file.content as List<int>;
      }
    }

    return ExportPackageData(
      version: version,
      exportedAt: exportedAt,
      records: parsedRecords,
      photos: photos,
    );
  }

  /// Triggers the system share sheet to save or share the exported file.
  Future<ShareResult> shareExportedFile(File file, {String? subject}) async {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject ?? file.path.split(RegExp(r'[/\\]')).last,
      ),
    );
  }
}
