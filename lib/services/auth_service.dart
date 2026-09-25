import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'config_service.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometrics capability: $e');
      return false;
    }
  }

  Future<bool> authenticateBiometrics(String localizedReason) async {
    try {
      final isAvailable = await canUseBiometrics();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  bool verifyPin(String pin) {
    return ConfigService.instance.verifyPin(pin);
  }

  Future<void> setupPin(String pin) async {
    await ConfigService.instance.setPin(pin);
  }

  bool isPinConfigured() {
    return ConfigService.instance.isPinSet();
  }
}
