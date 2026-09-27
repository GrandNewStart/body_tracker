import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/body_record.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  static const String _recordsFileName = 'records.json';
  static const String _photosFolderName = 'photos';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  late File _recordsFile;
  late Directory _photosDir;

  final ValueNotifier<List<BodyRecord>> recordsNotifier = ValueNotifier<List<BodyRecord>>([]);

  List<BodyRecord> get records => recordsNotifier.value;
  String get photosDirPath => _isInitialized ? _photosDir.path : '';

  Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    _recordsFile = File('${docsDir.path}/$_recordsFileName');
    _photosDir = Directory('${docsDir.path}/$_photosFolderName');

    if (!await _photosDir.exists()) {
      await _photosDir.create(recursive: true);
    }

    _isInitialized = true;
    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    if (await _recordsFile.exists()) {
      try {
        final content = await _recordsFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        bool needsResave = false;

        final list = jsonList.map((item) {
          final record = BodyRecord.fromJson(item as Map<String, dynamic>);
          final resolvedFront = resolveImagePath(record.frontImagePath);
          final resolvedLeft = resolveImagePath(record.leftImagePath);
          final resolvedBack = resolveImagePath(record.backImagePath);
          final resolvedRight = resolveImagePath(record.rightImagePath);

          if (resolvedFront != record.frontImagePath ||
              resolvedLeft != record.leftImagePath ||
              resolvedBack != record.backImagePath ||
              resolvedRight != record.rightImagePath) {
            needsResave = true;
          }

          return record.copyWith(
            frontImagePath: resolvedFront,
            leftImagePath: resolvedLeft,
            backImagePath: resolvedBack,
            rightImagePath: resolvedRight,
          );
        }).toList();

        // Sort descending by date so newest is first
        list.sort((a, b) => b.date.compareTo(a.date));
        recordsNotifier.value = list;

        if (needsResave) {
          await _saveRecordsToDisk();
        }
      } catch (e) {
        debugPrint('Error reading records.json: $e');
        recordsNotifier.value = [];
      }
    } else {
      recordsNotifier.value = [];
    }
  }

  /// Resolves an image path dynamically. On iOS and other platforms,
  /// sandbox container directories change on app updates/reinstalls.
  /// If the stored absolute path no longer exists, this locates the file
  /// by its basename in the current photos directory.
  String resolveImagePath(String storedPath) {
    if (storedPath.isEmpty) return '';

    // 1. Direct path check
    final directFile = File(storedPath);
    if (directFile.existsSync()) {
      return storedPath;
    }

    if (!_isInitialized) {
      return storedPath;
    }

    // 2. Extract file name
    final fileName = storedPath.split(RegExp(r'[/\\]')).last;
    if (fileName.isEmpty) return storedPath;

    // 3. Search in current photos directory
    final inPhotos = File('${_photosDir.path}/$fileName');
    if (inPhotos.existsSync()) {
      return inPhotos.path;
    }

    // 4. Search in parent documents directory
    final inDocs = File('${_recordsFile.parent.path}/$fileName');
    if (inDocs.existsSync()) {
      return inDocs.path;
    }

    // Return the expected photos directory path as fallback
    return inPhotos.path;
  }

  Future<void> addRecord(BodyRecord record) async {
    final currentList = List<BodyRecord>.from(recordsNotifier.value);
    currentList.insert(0, record);
    // Sort descending by date
    currentList.sort((a, b) => b.date.compareTo(a.date));
    recordsNotifier.value = currentList;
    await _saveRecordsToDisk();
  }

  Future<void> saveRecords(List<BodyRecord> newRecords) async {
    final currentList = List<BodyRecord>.from(newRecords);
    currentList.sort((a, b) => b.date.compareTo(a.date));
    recordsNotifier.value = currentList;
    await _saveRecordsToDisk();
  }

  Future<void> updateRecord(BodyRecord updatedRecord) async {
    final currentList = List<BodyRecord>.from(recordsNotifier.value);
    final index = currentList.indexWhere((r) => r.id == updatedRecord.id);
    if (index != -1) {
      currentList[index] = updatedRecord;
      currentList.sort((a, b) => b.date.compareTo(a.date));
      recordsNotifier.value = currentList;
      await _saveRecordsToDisk();
    }
  }

  Future<void> deleteRecord(String recordId) async {
    final recordToDelete = recordsNotifier.value.firstWhere(
      (r) => r.id == recordId,
      orElse: () => throw Exception('Record not found'),
    );

    // Delete image files from disk
    for (final rawPath in recordToDelete.allImagePaths) {
      final path = resolveImagePath(rawPath);
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting photo file $path: $e');
      }
    }

    final currentList = List<BodyRecord>.from(recordsNotifier.value);
    currentList.removeWhere((r) => r.id == recordId);
    recordsNotifier.value = currentList;
    await _saveRecordsToDisk();
  }

  Future<void> clearAllData() async {
    // Delete all photo files in the photos directory
    if (await _photosDir.exists()) {
      try {
        final entities = _photosDir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            await entity.delete();
          }
        }
      } catch (e) {
        debugPrint('Error clearing photos directory: $e');
      }
    }

    recordsNotifier.value = [];
    await _saveRecordsToDisk();
  }

  bool hasRecordedToday() {
    final now = DateTime.now();
    for (final record in recordsNotifier.value) {
      if (record.date.year == now.year &&
          record.date.month == now.month &&
          record.date.day == now.day) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveRecordsToDisk() async {
    if (!_isInitialized) return;
    final jsonList = recordsNotifier.value.map((r) => r.toJson()).toList();
    await _recordsFile.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
  }
}
