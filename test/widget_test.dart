import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_tracker/widgets/pin_pad.dart';

void main() {
  testWidgets('PinPad widget renders digits and responds to taps', (WidgetTester tester) async {
    String enteredPin = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PinPad(
                pinLength: 6,
                currentPin: enteredPin,
                onPinChanged: (newPin) {
                  setState(() {
                    enteredPin = newPin;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    // Verify keypad digits 1 to 9 and 0 are present
    for (int i = 0; i <= 9; i++) {
      expect(find.text('$i'), findsOneWidget);
    }

    // Tap '1', '2', '3'
    await tester.tap(find.text('1'));
    await tester.pump();
    expect(enteredPin, '1');

    await tester.tap(find.text('2'));
    await tester.pump();
    expect(enteredPin, '12');

    await tester.tap(find.text('3'));
    await tester.pump();
    expect(enteredPin, '123');

    // Tap backspace
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(enteredPin, '12');
  });
}
