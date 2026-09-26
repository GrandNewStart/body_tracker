import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages Google Mobile Ads (AdMob) initialization, preloading,
/// and displaying Rewarded Ads for video rendering.
class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  int _retryAttempt = 0;
  static const int _maxRetries = 3;

  /// Official Google AdMob Sample Rewarded Ad Unit IDs for testing.
  static const String _androidDefaultRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosDefaultRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  /// Returns the configured Rewarded Ad Unit ID.
  /// Falls back to official Google test IDs if no environment override is provided.
  String get rewardedAdUnitId {
    const envAdId = String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: '');
    if (envAdId.isNotEmpty) {
      return envAdId;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return _androidDefaultRewardedAdUnitId;
    }
    if (!kIsWeb && Platform.isIOS) {
      return _iosDefaultRewardedAdUnitId;
    }
    return '';
  }

  /// Indicates whether a rewarded ad is loaded and ready to display.
  bool get isAdReady => _rewardedAd != null;

  /// Whether the current platform supports Google Mobile Ads.
  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Initializes the Google Mobile Ads SDK and pre-loads the first rewarded ad.
  Future<void> init() async {
    if (!isSupportedPlatform) {
      debugPrint('[AdService] Platform is not Android/iOS. Ads disabled.');
      return;
    }

    try {
      await MobileAds.instance.initialize();
      debugPrint('[AdService] MobileAds initialized successfully.');
      loadRewardedAd();
    } catch (e) {
      debugPrint('[AdService] Error initializing MobileAds: $e');
    }
  }

  /// Pre-loads a rewarded ad in the background.
  void loadRewardedAd() {
    if (!isSupportedPlatform) return;
    if (_rewardedAd != null || _isAdLoading) return;

    _isAdLoading = true;
    debugPrint('[AdService] Pre-loading RewardedAd with ID: $rewardedAdUnitId');

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('[AdService] RewardedAd loaded successfully.');
          _rewardedAd = ad;
          _isAdLoading = false;
          _retryAttempt = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('[AdService] RewardedAd failed to load: $error');
          _rewardedAd = null;
          _isAdLoading = false;
          _retryAttempt++;

          if (_retryAttempt <= _maxRetries) {
            // Exponential backoff retry
            final delay = Duration(seconds: 2 * _retryAttempt);
            Future.delayed(delay, () => loadRewardedAd());
          }
        },
      ),
    );
  }

  /// Displays the rewarded ad.
  ///
  /// - [onRewardEarned] is invoked when the user finishes watching the ad and earns the reward.
  /// - [onAdDismissedWithoutReward] is invoked if the user closes the ad before the reward threshold.
  /// - If on an unsupported platform or if the ad is unavailable (e.g. offline/network failure),
  ///   gracefully invokes [onRewardEarned] so the user is never blocked.
  Future<void> showRewardedAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onAdDismissedWithoutReward,
  }) async {
    // Graceful pass-through on non-mobile platforms (e.g. macOS desktop, simulator, tests)
    if (!isSupportedPlatform) {
      debugPrint('[AdService] Non-mobile platform. Granting reward automatically.');
      onRewardEarned();
      return;
    }

    // If ad is ready, show it
    if (_rewardedAd != null) {
      bool earnedReward = false;
      final adToShow = _rewardedAd!;
      _rewardedAd = null; // Clear reference before showing

      adToShow.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          debugPrint('[AdService] RewardedAd showed full screen.');
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('[AdService] RewardedAd dismissed. Earned: $earnedReward');
          ad.dispose();
          loadRewardedAd(); // Immediately pre-load the next ad

          if (earnedReward) {
            onRewardEarned();
          } else {
            onAdDismissedWithoutReward?.call();
          }
        },
        onAdFailedToShowFullScreenContent: (ad, AdError error) {
          debugPrint('[AdService] RewardedAd failed to show: $error');
          ad.dispose();
          loadRewardedAd();

          // Graceful fallback: don't penalize the user if the ad network fails
          onRewardEarned();
        },
      );

      adToShow.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
          earnedReward = true;
        },
      );
    } else {
      // Ad was not ready yet (e.g. offline, initial startup, or fill error).
      // Fallback: trigger background load and allow user to continue without blocking.
      debugPrint('[AdService] Ad not ready when requested. Proceeding gracefully.');
      loadRewardedAd();
      onRewardEarned();
    }
  }

  /// Disposes of any currently loaded ad.
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoading = false;
  }
}
