import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../l10n/app_strings.dart';
import '../widgets/pin_pad.dart';
import 'main_screen.dart';

enum AuthMode {
  unlock,
  setupNew,
  setupConfirm,
}

class AuthScreen extends StatefulWidget {
  final bool isChangingPin;

  const AuthScreen({
    super.key,
    this.isChangingPin = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final GlobalKey<State<PinPad>> _pinPadKey = GlobalKey<State<PinPad>>();

  late AuthMode _mode;
  String _enteredPin = '';
  String _firstEnteredPin = '';
  String? _errorMessage;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    final isPinConfigured = AuthService.instance.isPinConfigured();
    if (widget.isChangingPin || !isPinConfigured) {
      _mode = AuthMode.setupNew;
    } else {
      _mode = AuthMode.unlock;
    }

    _checkBiometricsAndAutoPrompt();
  }

  Future<void> _checkBiometricsAndAutoPrompt() async {
    final canBio = await AuthService.instance.canUseBiometrics();
    if (mounted) {
      setState(() {
        _canUseBiometrics = canBio;
      });
    }

    // Auto-prompt biometrics if in unlock mode and user enabled it in config
    if (_mode == AuthMode.unlock &&
        ConfigService.instance.config.useLocalAuth &&
        canBio) {
      // Small delay to allow transition animation to settle
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _triggerBiometricAuth();
      }
    }
  }

  Future<void> _triggerBiometricAuth() async {
    final strings = AppStrings(ConfigService.instance.config.language);
    final success = await AuthService.instance.authenticateBiometrics(
      strings.authenticateBiometricsReason,
    );
    if (success && mounted) {
      _navigateToMain();
    }
  }

  void _onPinChanged(String pin) {
    setState(() {
      _enteredPin = pin;
      _errorMessage = null;
    });

    if (pin.length == 6) {
      _handlePinComplete(pin);
    }
  }

  void _handlePinComplete(String pin) async {
    final strings = AppStrings(ConfigService.instance.config.language);

    switch (_mode) {
      case AuthMode.unlock:
        final isValid = AuthService.instance.verifyPin(pin);
        if (isValid) {
          _navigateToMain();
        } else {
          setState(() {
            _errorMessage = strings.invalidPin;
            _enteredPin = '';
          });
        }
        break;

      case AuthMode.setupNew:
        setState(() {
          _firstEnteredPin = pin;
          _enteredPin = '';
          _mode = AuthMode.setupConfirm;
        });
        break;

      case AuthMode.setupConfirm:
        if (pin == _firstEnteredPin) {
          await AuthService.instance.setupPin(pin);
          if (widget.isChangingPin) {
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          } else {
            _navigateToMain();
          }
        } else {
          setState(() {
            _errorMessage = strings.pinMismatch;
            _enteredPin = '';
            _firstEnteredPin = '';
            _mode = AuthMode.setupNew;
          });
        }
        break;
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings(ConfigService.instance.config.language);

    String title;
    String subtitle;

    switch (_mode) {
      case AuthMode.unlock:
        title = strings.enterPin;
        subtitle = strings.appName;
        break;
      case AuthMode.setupNew:
        title = strings.setupPinTitle;
        subtitle = strings.setupPinSubtitle;
        break;
      case AuthMode.setupConfirm:
        title = strings.confirmPinTitle;
        subtitle = strings.confirmPinSubtitle;
        break;
    }

    return Scaffold(
      appBar: widget.isChangingPin
          ? AppBar(
              title: Text(strings.changePin),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _mode == AuthMode.unlock ? Icons.lock_outline : Icons.lock_reset,
                    size: 36,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Error message
                AnimatedOpacity(
                  opacity: _errorMessage != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    height: 28,
                    alignment: Alignment.center,
                    child: Text(
                      _errorMessage ?? '',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // PIN Pad
                PinPad(
                  key: _pinPadKey,
                  pinLength: 6,
                  currentPin: _enteredPin,
                  onPinChanged: _onPinChanged,
                  showBiometric: _mode == AuthMode.unlock &&
                      _canUseBiometrics &&
                      ConfigService.instance.config.useLocalAuth,
                  onBiometricPressed: _triggerBiometricAuth,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
