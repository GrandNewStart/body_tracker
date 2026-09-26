import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages Google Mobile Ads (AdMob) initialization, Google UMP user consent,
/// preloading, and displaying Rewarded Ads for video rendering.
class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  int _retryAttempt = 0;
  static const int _maxRetries = 3;

  /// Official Google AdMob Sample Rewarded Ad Unit ID for Android testing.
  static const String _androidTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  /// Production Android Rewarded Ad Unit ID.
  /// Can be injected via secret: --dart-define=ADMOB_ANDROID_REWARDED_AD_UNIT_ID=...
  static const String _androidProductionRewardedAdUnitId =
      String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-1505069800787234/9551660101',
  );

  /// Production iOS Rewarded Ad Unit ID.
  /// Can be injected via secret: --dart-define=ADMOB_IOS_REWARDED_AD_UNIT_ID=...
  static const String _iosProductionRewardedAdUnitId =
      String.fromEnvironment(
    'ADMOB_IOS_REWARDED_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-1505069800787234/6070656652',
  );

  /// Official Google AdMob Sample Rewarded Ad Unit ID for iOS testing.
  static const String _iosTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  /// Returns the configured Rewarded Ad Unit ID.
  /// Uses official Google test IDs in debug mode to prevent unapproved account errors,
  /// and automatically switches to your live production ID in release mode.
  String get rewardedAdUnitId {
    const envAdId = String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: '');
    if (envAdId.isNotEmpty) {
      return envAdId;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return kReleaseMode
          ? _androidProductionRewardedAdUnitId
          : _androidTestRewardedAdUnitId;
    }
    if (!kIsWeb && Platform.isIOS) {
      return kReleaseMode
          ? _iosProductionRewardedAdUnitId
          : _iosTestRewardedAdUnitId;
    }
    return '';
  }

  /// Indicates whether a rewarded ad is loaded and ready to display.
  bool get isAdReady => _rewardedAd != null;

  /// Whether the current platform supports Google Mobile Ads.
  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Initializes Google Mobile Ads and gathers User Consent via the Google
  /// User Messaging Platform (UMP) SDK (required for GDPR/EEA/UK/ATT compliance).
  Future<void> init() async {
    if (!isSupportedPlatform) {
      debugPrint('[AdService] Platform is not Android/iOS. Ads disabled.');
      return;
    }

    try {
      final params = ConsentRequestParameters();

      // Request updated consent info from Google UMP
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // If consent is required (e.g. users in the EU/EEA/UK), present the certified form
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) async {
            if (formError != null) {
              debugPrint('[AdService] UMP Consent Form error: ${formError.errorCode}: ${formError.message}');
            }
            await _initializeMobileAdsIfPermitted();
          });
        },
        (FormError error) async {
          debugPrint('[AdService] UMP ConsentInfoUpdate error: ${error.errorCode}: ${error.message}');
          // In case of network errors, attempt initializing if cached consent allows it
          await _initializeMobileAdsIfPermitted();
        },
      );
    } catch (e) {
      debugPrint('[AdService] Error during consent update: $e');
      await _initializeMobileAdsIfPermitted();
    }
  }

  /// Checks consent status and initializes MobileAds SDK if permitted by the user.
  Future<void> _initializeMobileAdsIfPermitted() async {
    if (!isSupportedPlatform) return;

    try {
      final canRequest = await ConsentInformation.instance.canRequestAds();
      debugPrint('[AdService] Can request ads according to consent: $canRequest');

      if (canRequest) {
        await MobileAds.instance.initialize();
        debugPrint('[AdService] MobileAds initialized successfully.');
        loadRewardedAd();
      }
    } catch (e) {
      debugPrint('[AdService] Error initializing MobileAds: $e');
    }
  }

  /// Checks whether the user is in a jurisdiction where privacy options should be exposed (e.g. GDPR).
  Future<bool> isPrivacyOptionsRequired() async {
    if (!isSupportedPlatform) return false;
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      return false;
    }
  }

  /// Displays the UMP Privacy Options Form so users can review or revoke ad consent at any time.
  /// If the user is outside the EEA/UK where consent is not legally required, [onNotRequired] is invoked.
  Future<void> showPrivacyOptionsForm({
    VoidCallback? onNotRequired,
    void Function(String message)? onError,
  }) async {
    if (!isSupportedPlatform) {
      onNotRequired?.call();
      return;
    }

    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      if (status != PrivacyOptionsRequirementStatus.required) {
        debugPrint('[AdService] Privacy options form is not required for this region ($status).');
        onNotRequired?.call();
        return;
      }

      ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (error != null) {
          debugPrint('[AdService] Privacy options form error: ${error.message}');
          onError?.call(error.message);
        }
      });
    } catch (e) {
      debugPrint('[AdService] Privacy options error: $e');
      onError?.call(e.toString());
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
