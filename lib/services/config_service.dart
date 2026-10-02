import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_config.dart';

class ConfigService {
  static final ConfigService instance = ConfigService._internal();
  ConfigService._internal();

  static const String _nonceKey = 'app_nonce';
  static const String _configFileName = 'config.json';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );
  late File _configFile;
  late String _appNonce;

  final ValueNotifier<AppConfig> configNotifier = ValueNotifier<AppConfig>(const AppConfig());

  AppConfig get config => configNotifier.value;
  String get appNonce => _appNonce;

  Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    _configFile = File('${docsDir.path}/$_configFileName');

    // Load or generate app_nonce (32 random bytes stored in Keychain / Keystore)
    String? storedNonce;
    try {
      storedNonce = await _secureStorage.read(key: _nonceKey);
    } catch (e) {
      debugPrint('Error reading app_nonce from secure storage: $e');
    }

    if (storedNonce == null || storedNonce.isEmpty) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      storedNonce = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      try {
        await _secureStorage.write(key: _nonceKey, value: storedNonce);
      } catch (e) {
        debugPrint('Error writing app_nonce to secure storage: $e');
      }
    }
    _appNonce = storedNonce;

    // Load config.json
    if (await _configFile.exists()) {
      try {
        final content = await _configFile.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(content);
        configNotifier.value = AppConfig.fromJson(jsonMap);
      } catch (e) {
        debugPrint('Error reading config.json: $e');
        configNotifier.value = const AppConfig();
        await _saveConfigToDisk(configNotifier.value);
      }
    } else {
      // Default config
      configNotifier.value = const AppConfig();
      await _saveConfigToDisk(configNotifier.value);
    }
  }

  String hashPin(String pin) {
    // SHA256(PIN | app_nonce)
    final input = '$pin$_appNonce';
    return sha256.convert(utf8.encode(input)).toString();
  }

  bool verifyPin(String pin) {
    if (config.pinHash.isEmpty) return false;
    final hashed = hashPin(pin);
    return hashed == config.pinHash;
  }

  Future<void> setPin(String newPin) async {
    final newHash = hashPin(newPin);
    await updateConfig(config.copyWith(pinHash: newHash));
  }

  bool isPinSet() {
    return config.pinHash.isNotEmpty;
  }

  Future<void> updateConfig(AppConfig newConfig) async {
    configNotifier.value = newConfig;
    await _saveConfigToDisk(newConfig);
  }

  Future<void> saveConfigJsonString(String rawJson) async {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final parsed = AppConfig.fromJson(decoded);
    configNotifier.value = parsed;
    await _configFile.writeAsString(parsed.toPrettyJson());
  }

  Future<String> readRawConfigJson() async {
    if (await _configFile.exists()) {
      return await _configFile.readAsString();
    }
    return config.toPrettyJson();
  }

  Future<void> _saveConfigToDisk(AppConfig cfg) async {
    await _configFile.writeAsString(cfg.toPrettyJson());
  }
}
