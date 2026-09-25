import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  test('Test DateFormat en_US without initialization', () {
    final str = DateFormat.yMMMMd('en_US').format(DateTime.now());
    expect(str, isNotEmpty);
  });
}
