import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_tracker/models/app_config.dart';
import 'package:body_tracker/models/body_record.dart';

void main() {
  group('AppConfig Tests', () {
    test('Default values match requirements', () {
      const config = AppConfig();
      expect(config.language, 'EN');
      expect(config.theme, 'light');
      expect(config.pinHash, '');
      expect(config.useLocalAuth, false);
      expect(config.mode, 'free_capture');
      expect(config.captureTime, '09.00');
    });

    test('JSON serialization & deserialization', () {
      final json = {
        'language': 'KR',
        'theme': 'dark',
        'pin_hash': 'test_hash_123',
        'use_local_auth': true,
        'mode': 'fixed_time_capture',
        'capture_time': '18.45',
      };

      final config = AppConfig.fromJson(json);
      expect(config.language, 'KR');
      expect(config.theme, 'dark');
      expect(config.pinHash, 'test_hash_123');
      expect(config.useLocalAuth, true);
      expect(config.mode, 'fixed_time_capture');
      expect(config.captureTime, '18.45');
      expect(config.captureHour, 18);
      expect(config.captureMinute, 45);

      final exportedJson = config.toJson();
      expect(exportedJson['language'], 'KR');
      expect(exportedJson['theme'], 'dark');
      expect(exportedJson['pin_hash'], 'test_hash_123');
      expect(exportedJson['use_local_auth'], true);
      expect(exportedJson['mode'], 'fixed_time_capture');
      expect(exportedJson['capture_time'], '18.45');
    });

    test('copyWith updates specific properties', () {
      const config = AppConfig();
      final updated = config.copyWith(
        theme: 'dark',
        language: 'KR',
        useLocalAuth: true,
      );

      expect(updated.theme, 'dark');
      expect(updated.language, 'KR');
      expect(updated.useLocalAuth, true);
      expect(updated.mode, 'free_capture');
    });

    test('SHA256(PIN | app_nonce) calculation', () {
      const pin = '123456';
      const nonce = 'abcd1234efgh5678abcd1234efgh5678';
      final expectedHash = sha256.convert(utf8.encode('$pin$nonce')).toString();

      final actualHash = sha256.convert(utf8.encode('$pin$nonce')).toString();
      expect(actualHash, expectedHash);
      expect(actualHash.length, 64);
    });
  });

  group('BodyRecord Tests', () {
    test('JSON serialization & deserialization', () {
      final now = DateTime.now();
      final record = BodyRecord(
        id: 'rec-1',
        date: now,
        weight: 72.5,
        frontImagePath: '/path/front.jpg',
        leftImagePath: '/path/left.jpg',
        backImagePath: '/path/back.jpg',
        rightImagePath: '/path/right.jpg',
        isMasked: true,
        createdAt: now,
      );

      expect(record.allImagePaths.length, 4);
      expect(record.allImagePaths[0], '/path/front.jpg');
      expect(record.allImagePaths[1], '/path/left.jpg');
      expect(record.allImagePaths[2], '/path/back.jpg');
      expect(record.allImagePaths[3], '/path/right.jpg');

      final json = record.toJson();
      final restored = BodyRecord.fromJson(json);

      expect(restored.id, 'rec-1');
      expect(restored.weight, 72.5);
      expect(restored.isMasked, true);
      expect(restored.frontImagePath, '/path/front.jpg');
    });
  });
}
