import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../models/app_config.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../services/export_import_service.dart';
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

  Future<void> _handleExport(BuildContext context) async {
    final strings = AppStrings(ConfigService.instance.config.language);
    final records = StorageService.instance.records;

    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.noRecordsToExport)),
      );
      return;
    }

    final password = await _showExportPasswordDialog(context, strings);
    if (password == null || password.isEmpty) return;

    if (!context.mounted) return;

    // Show loading progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(strings.exportingRecords)),
            ],
          ),
        ),
      ),
    );

    try {
      final exportedFile = await ExportImportService.instance.exportRecords(password: password);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        await ExportImportService.instance.shareExportedFile(exportedFile);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${strings.exportFailed}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<String?> _showExportPasswordDialog(BuildContext context, AppStrings strings) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    String? errorMessage;

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(strings.exportPasswordTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.exportPasswordPrompt,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: strings.password,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: strings.confirmPassword,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final pwd = passwordController.text;
                    final confirm = confirmController.text;
                    if (pwd.isEmpty) {
                      setDialogState(() {
                        errorMessage = strings.passwordRequired;
                      });
                      return;
                    }
                    if (pwd != confirm) {
                      setDialogState(() {
                        errorMessage = strings.passwordsDoNotMatch;
                      });
                      return;
                    }
                    Navigator.of(ctx).pop(pwd);
                  },
                  child: Text(strings.export),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /*
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
  */

  static const String _privacyPolicyUrl =
      'https://bluelemonade.co.kr/body-tracker/privacy-policy.html';

  Future<void> _openPrivacyPolicy(BuildContext context, AppStrings strings) async {
    final uri = Uri.parse(_privacyPolicyUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _showPrivacyPolicyDialog(context, strings);
      }
    } catch (_) {
      if (context.mounted) {
        _showPrivacyPolicyDialog(context, strings);
      }
    }
  }

  void _showPrivacyPolicyDialog(BuildContext context, AppStrings strings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(strings.privacyPolicyTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.isKorean
                    ? '1. 100% 로컬 데이터 저장\n사진, 신체 측정값, PIN 및 설정은 외부 서버로 전송되지 않으며 사용자 기기 내에만 안전하게 보관됩니다.\n\n'
                      '2. 기기 내 온디바이스 AI\nGoogle ML Kit 포즈 및 얼굴 감지 기술은 기기 내부(CPU/NPU)에서만 실시간 연산됩니다.\n\n'
                      '3. 리워드 광고 (Google AdMob)\n비디오 생성 시 Google AdMob을 통해 리워드 광고가 제공됩니다. 광고 전달 및 사기 방지를 위해 익명 기기 식별자가 처리될 수 있습니다.\n\n'
                      '공식 웹페이지에서 전체 방침을 확인하세요:\n$_privacyPolicyUrl'
                    : '1. 100% On-Device Storage\nYour photos, body measurements, PIN, and preferences are never transmitted to external servers.\n\n'
                      '2. Local AI Processing\nGoogle ML Kit pose and face detection execute strictly offline on your phone.\n\n'
                      '3. Rewarded Ads (Google AdMob)\nRewarded video ads are served via Google AdMob prior to video rendering. Anonymous device identifiers may be processed for ad delivery and fraud prevention.\n\n'
                      'View full policy on our website:\n$_privacyPolicyUrl',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.ok),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: Text(strings.isKorean ? '웹에서 열기' : 'Open in Browser'),
            onPressed: () {
              Navigator.of(ctx).pop();
              launchUrl(Uri.parse(_privacyPolicyUrl), mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
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
                    leading: const Icon(Icons.upload_file),
                    title: Text(strings.exportRecords),
                    subtitle: Text(strings.exportRecordsSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _handleExport(context),
                  ),
                  const Divider(height: 16),

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

          // 5. Privacy & Legal Section
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.privacySection,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(strings.privacyPolicyTitle),
                    subtitle: Text(strings.privacyPolicySubtitle),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () => _openPrivacyPolicy(context, strings),
                  ),
                  const Divider(height: 16),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune),
                    title: Text(strings.adConsentSettingsTitle),
                    subtitle: Text(strings.adConsentSettingsSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AdService.instance.showPrivacyOptionsForm(
                        onNotRequired: () {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(strings.adConsentNotRequiredMessage),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onError: (msg) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: Theme.of(context).colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 6. config.json Visualizer & Raw Editor (Hidden in production)
          /*
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
          */
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
