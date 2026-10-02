import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/app_config.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/config_service.dart';
import 'services/ml_service.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';
import 'services/storage_service.dart';
import 'services/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set portrait orientation as preferred for body tracking
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize date formatting for internationalization (e.g. ko_KR)
  await initializeDateFormatting();

  // Initialize core services
  try {
    await ConfigService.instance.init();
  } catch (e) {
    debugPrint('ConfigService init failed: $e');
  }

  try {
    await StorageService.instance.init();
  } catch (e) {
    debugPrint('StorageService init failed: $e');
  }

  try {
    await SoundService.instance.init();
  } catch (e) {
    debugPrint('SoundService init failed: $e');
  }

  try {
    await TtsService.instance.init(ConfigService.instance.config.language);
  } catch (e) {
    debugPrint('TtsService init failed: $e');
  }

  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }

  try {
    MlService.instance.init();
  } catch (e) {
    debugPrint('MlService init failed: $e');
  }

  try {
    await AdService.instance.init();
  } catch (e) {
    debugPrint('AdService init failed: $e');
  }

  // Schedule reminders based on config
  try {
    final hasRecordedToday = StorageService.instance.hasRecordedToday();
    await NotificationService.instance.updateSchedules(
      ConfigService.instance.config,
      hasRecordedToday,
    );
  } catch (e) {
    debugPrint('updateSchedules failed: $e');
  }

  runApp(const BodyTrackerApp());
}

class BodyTrackerApp extends StatelessWidget {
  const BodyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppConfig>(
      valueListenable: ConfigService.instance.configNotifier,
      builder: (context, config, child) {
        final isDark = config.theme == 'dark';

        // Update TTS language whenever config language changes
        TtsService.instance.setLanguage(config.language);

        return MaterialApp(
          title: 'Body Tracker',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.light,
            ),
            fontFamily: 'Roboto',
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B82F6),
              brightness: Brightness.dark,
            ),
            fontFamily: 'Roboto',
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
