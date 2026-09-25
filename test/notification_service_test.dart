import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('Timezone & Notification Scheduling Tests', () {
    test('Default tz.initializeTimeZones sets tz.local to UTC', () {
      // By default without setLocalLocation, tz.local is UTC
      tz.initializeTimeZones();
      expect(tz.local.name, 'Etc/UTC');
    });

    test('Setting local location configures tz.local properly for local schedule', () {
      final seoulLocation = tz.getLocation('Asia/Seoul');
      tz.setLocalLocation(seoulLocation);

      expect(tz.local.name, 'Asia/Seoul');

      final now = tz.TZDateTime.now(tz.local);
      final scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        7,
        0,
      );

      expect(scheduled.timeZoneOffset.inHours, 9);
      expect(scheduled.hour, 7);
      expect(scheduled.minute, 0);
      expect(scheduled.location.name, 'Asia/Seoul');
    });
  });
}
