import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/app_config.dart';
import 'screens/splash_screen.dart';
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
  await ConfigService.instance.init();
  await StorageService.instance.init();
  await SoundService.instance.init();
  await TtsService.instance.init(ConfigService.instance.config.language);
  await NotificationService.instance.init();
  MlService.instance.init();

  // Schedule reminders based on config
  final hasRecordedToday = StorageService.instance.hasRecordedToday();
  await NotificationService.instance.updateSchedules(
    ConfigService.instance.config,
    hasRecordedToday,
  );

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
