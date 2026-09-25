import 'package:flutter/material.dart';

class PinPad extends StatefulWidget {
  final int pinLength;
  final String currentPin;
  final ValueChanged<String> onPinChanged;
  final VoidCallback? onBiometricPressed;
  final bool showBiometric;

  const PinPad({
    super.key,
    this.pinLength = 6,
    required this.currentPin,
    required this.onPinChanged,
    this.onBiometricPressed,
    this.showBiometric = false,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void shake() {
    _shakeController.forward(from: 0.0);
  }

  void _onDigitPressed(String digit) {
    if (widget.currentPin.length < widget.pinLength) {
      widget.onPinChanged('${widget.currentPin}$digit');
    }
  }

  void _onDeletePressed() {
    if (widget.currentPin.isNotEmpty) {
      widget.onPinChanged(widget.currentPin.substring(0, widget.currentPin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dots indicator
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final offset = _shakeAnimation.value * (_shakeController.isAnimating ? 1 : 0);
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.pinLength, (index) {
              final isFilled = index < widget.currentPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 36),

        // Keypad
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            children: [
              _buildRow(['1', '2', '3']),
              const SizedBox(height: 16),
              _buildRow(['4', '5', '6']),
              const SizedBox(height: 16),
              _buildRow(['7', '8', '9']),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Biometric or empty
                  if (widget.showBiometric && widget.onBiometricPressed != null)
                    _buildIconButton(
                      icon: Icons.fingerprint,
                      onPressed: widget.onBiometricPressed!,
                    )
                  else
                    const SizedBox(width: 72, height: 72),

                  _buildDigitButton('0'),

                  _buildIconButton(
                    icon: Icons.backspace_outlined,
                    onPressed: _onDeletePressed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildDigitButton).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onDigitPressed(digit),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: 28,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
