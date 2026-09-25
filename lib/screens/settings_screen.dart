import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_strings.dart';
import '../models/app_config.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canBio = await AuthService.instance.canUseBiometrics();
    if (mounted) {
      setState(() {
        _canUseBiometrics = canBio;
      });
    }
  }

  Future<void> _updateConfig(AppConfig newConfig) async {
    await ConfigService.instance.updateConfig(newConfig);
    final hasRecordedToday = StorageService.instance.hasRecordedToday();
    await NotificationService.instance.updateSchedules(newConfig, hasRecordedToday);
    setState(() {});
  }

  Future<void> _selectCaptureTime(BuildContext context, AppConfig config) async {
    final initialTime = TimeOfDay(
      hour: config.captureHour,
      minute: config.captureMinute,
    );

    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selected != null) {
      final hourStr = selected.hour.toString().padLeft(2, '0');
      final minuteStr = selected.minute.toString().padLeft(2, '0');
      final timeFormatted = '$hourStr.$minuteStr'; // "hh.mm" as per config.json spec
      await _updateConfig(config.copyWith(captureTime: timeFormatted));
    }
  }

  Future<void> _changePin(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AuthScreen(isChangingPin: true),
      ),
    );

    if (result == true && mounted) {
      final strings = AppStrings(ConfigService.instance.config.language);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.success)),
        );
      }
      setState(() {});
    }
  }

  Future<void> _confirmClearAllData(BuildContext context) async {
    final strings = AppStrings(ConfigService.instance.config.language);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.clearAllData),
        content: Text(strings.clearAllDataConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await StorageService.instance.clearAllData();
      final hasRecordedToday = StorageService.instance.hasRecordedToday();
      await NotificationService.instance.updateSchedules(
        ConfigService.instance.config,
        hasRecordedToday,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.success)),
        );
      }
    }
  }

  Future<void> _showRawJsonEditor(BuildContext context) async {
    final strings = AppStrings(ConfigService.instance.config.language);
    final rawJson = await ConfigService.instance.readRawConfigJson();
    final jsonController = TextEditingController(text: rawJson);
    String? errorText;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(strings.editRawConfig),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: jsonController,
                      maxLines: 14,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final text = jsonController.text;
                      jsonDecode(text); // validate JSON syntax
                      await ConfigService.instance.saveConfigJsonString(text);
                      final hasToday = StorageService.instance.hasRecordedToday();
                      await NotificationService.instance.updateSchedules(
                        ConfigService.instance.config,
                        hasToday,
                      );
                      if (context.mounted) {
                        Navigator.of(ctx).pop();
                        setState(() {});
                      }
                    } catch (e) {
                      setDialogState(() {
                        errorText = 'Invalid JSON: $e';
                      });
                    }
                  },
                  child: Text(strings.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService.instance.config;
    final strings = AppStrings(config.language);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Language & Theme Section
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${strings.languageTitle} & ${strings.themeTitle}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Language selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(strings.languageTitle),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'EN', label: Text('English')),
                          ButtonSegment(value: 'KR', label: Text('한국어')),
                        ],
                        selected: {config.language},
                        onSelectionChanged: (selected) {
                          _updateConfig(config.copyWith(language: selected.first));
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Theme selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(strings.themeTitle),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'light',
                            label: Text(strings.lightTheme),
                            icon: const Icon(Icons.light_mode, size: 16),
                          ),
                          ButtonSegment(
                            value: 'dark',
                            label: Text(strings.darkTheme),
                            icon: const Icon(Icons.dark_mode, size: 16),
                          ),
                        ],
                        selected: {config.theme},
                        onSelectionChanged: (selected) {
                          _updateConfig(config.copyWith(theme: selected.first));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Security Section (PIN & Biometrics)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.securitySection,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pin),
                    title: Text(strings.changePin),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _changePin(context),
                  ),
                  const Divider(height: 16),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.fingerprint),
                    title: Text(strings.useLocalAuthTitle),
                    subtitle: Text(strings.useLocalAuthSubtitle),
                    value: config.useLocalAuth,
                    onChanged: _canUseBiometrics
                        ? (val) {
                            _updateConfig(config.copyWith(useLocalAuth: val));
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Capture Mode & Schedule Section
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.captureModeSection,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  RadioGroup<String>(
                    groupValue: config.mode,
                    onChanged: (val) {
                      if (val != null) {
                        _updateConfig(config.copyWith(mode: val));
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(strings.freeCapture),
                          subtitle: Text(strings.freeCaptureDesc),
                          value: 'free_capture',
                        ),
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(strings.fixedTimeCapture),
                          subtitle: Text(strings.fixedTimeCaptureDesc),
                          value: 'fixed_time_capture',
                        ),
                      ],
                    ),
                  ),

                  if (config.mode == 'fixed_time_capture') ...[
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alarm),
                      title: Text(strings.captureTime),
                      trailing: FilledButton.tonal(
                        onPressed: () => _selectCaptureTime(context, config),
                        child: Text(
                          '${config.captureHour.toString().padLeft(2, '0')}:${config.captureMinute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Data Management
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.dataManagement,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
                    title: Text(
                      strings.clearAllData,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    onTap: () => _confirmClearAllData(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. config.json Visualizer & Raw Editor
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        strings.configJsonSection,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            tooltip: strings.copyConfigJson,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: config.toPrettyJson()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(strings.configCopied)),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: strings.editRawConfig,
                            onPressed: () => _showRawJsonEditor(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: SelectableText(
                      config.toPrettyJson(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
