import 'dart:convert';

class AppConfig {
  final String language; // "EN" or "KR"
  final String theme; // "light" or "dark"
  final String pinHash; // SHA256(PIN | app_nonce)
  final bool useLocalAuth; // true or false
  final String mode; // "free_capture" or "fixed_time_capture"
  final String captureTime; // "hh.mm" e.g. "09.00"

  const AppConfig({
    this.language = 'EN',
    this.theme = 'light',
    this.pinHash = '',
    this.useLocalAuth = false,
    this.mode = 'free_capture',
    this.captureTime = '09.00',
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      language: (json['language'] as String?)?.toUpperCase() == 'KR' ? 'KR' : 'EN',
      theme: (json['theme'] as String?)?.toLowerCase() == 'dark' ? 'dark' : 'light',
      pinHash: json['pin_hash'] as String? ?? '',
      useLocalAuth: json['use_local_auth'] as bool? ?? false,
      mode: (json['mode'] as String?) == 'fixed_time_capture' ? 'fixed_time_capture' : 'free_capture',
      captureTime: json['capture_time'] as String? ?? '09.00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'theme': theme,
      'pin_hash': pinHash,
      'use_local_auth': useLocalAuth,
      'mode': mode,
      'capture_time': captureTime,
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  AppConfig copyWith({
    String? language,
    String? theme,
    String? pinHash,
    bool? useLocalAuth,
    String? mode,
    String? captureTime,
  }) {
    return AppConfig(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      pinHash: pinHash ?? this.pinHash,
      useLocalAuth: useLocalAuth ?? this.useLocalAuth,
      mode: mode ?? this.mode,
      captureTime: captureTime ?? this.captureTime,
    );
  }

  int get captureHour {
    try {
      final parts = captureTime.replaceAll(':', '.').split('.');
      return int.parse(parts[0]);
    } catch (_) {
      return 9;
    }
  }

  int get captureMinute {
    try {
      final parts = captureTime.replaceAll(':', '.').split('.');
      return parts.length > 1 ? int.parse(parts[1]) : 0;
    } catch (_) {
      return 0;
    }
  }
}
