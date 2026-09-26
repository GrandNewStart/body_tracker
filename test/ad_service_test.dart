import 'package:flutter_test/flutter_test.dart';
import 'package:body_tracker/services/ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdService Unit Tests', () {
    test('Singleton instance is accessible', () {
      final instance1 = AdService.instance;
      final instance2 = AdService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('rewardedAdUnitId defaults to official test IDs or empty on non-mobile', () {
      final unitId = AdService.instance.rewardedAdUnitId;
      // In host test runner (macOS VM), isSupportedPlatform is false
      expect(AdService.instance.isSupportedPlatform, isFalse);
      expect(unitId, isEmpty);
    });

    test('showRewardedAd gracefully passes through on non-mobile test runner', () async {
      bool rewardEarned = false;
      bool dismissed = false;

      await AdService.instance.showRewardedAd(
        onRewardEarned: () {
          rewardEarned = true;
        },
        onAdDismissedWithoutReward: () {
          dismissed = true;
        },
      );

      // Should automatically pass through and grant reward on test/desktop runner
      expect(rewardEarned, isTrue);
      expect(dismissed, isFalse);
    });

    test('loadRewardedAd and dispose handle non-mobile environment safely', () {
      expect(() => AdService.instance.loadRewardedAd(), returnsNormally);
      expect(() => AdService.instance.dispose(), returnsNormally);
    });
  });
}
