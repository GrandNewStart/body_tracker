class AppStrings {
  final String language;

  AppStrings(this.language);

  bool get isKorean => language.toUpperCase() == 'KR';

  // General
  String get appName => 'Body Tracker';
  String get ok => isKorean ? '확인' : 'OK';
  String get cancel => isKorean ? '취소' : 'Cancel';
  String get save => isKorean ? '저장' : 'Save';
  String get delete => isKorean ? '삭제' : 'Delete';
  String get error => isKorean ? '오류' : 'Error';
  String get success => isKorean ? '완료' : 'Success';

  // Splash & Auth
  String get enterPin => isKorean ? '6자리 PIN 번호를 입력하세요' : 'Enter 6-digit PIN';
  String get setupPinTitle => isKorean ? '새 6자리 PIN 설정' : 'Set New 6-digit PIN';
  String get setupPinSubtitle => isKorean ? '앱 보호를 위해 6자리 PIN을 설정해주세요' : 'Set a 6-digit PIN to protect your records';
  String get confirmPinTitle => isKorean ? 'PIN 번호 확인' : 'Confirm 6-digit PIN';
  String get confirmPinSubtitle => isKorean ? 'PIN 번호를 다시 한 번 입력하세요' : 'Please re-enter your 6-digit PIN';
  String get pinMismatch => isKorean ? 'PIN 번호가 일치하지 않습니다. 다시 시도해주세요.' : 'PINs do not match. Please try again.';
  String get invalidPin => isKorean ? '잘못된 PIN 번호입니다' : 'Incorrect PIN';
  String get authenticateBiometricsReason => isKorean ? 'Body Tracker 잠금 해제' : 'Unlock Body Tracker';
  String get useBiometrics => isKorean ? '생체 인증 사용' : 'Use Biometrics';

  // Navigation
  String get profileTab => isKorean ? '프로필' : 'Profile';
  String get settingsTab => isKorean ? '설정' : 'Settings';

  // Profile Screen
  String get emptyRecordsTitle => isKorean ? '몸 기록을 시작해보세요!' : 'Start Recording Your Body!';
  String get emptyRecordsSubtitle => isKorean ? '매일 4방향 사진과 몸무게를 기록하고 변화를 영상으로 확인하세요.' : 'Take 4-angle photos and track your body transformation over time.';
  String get recordToday => isKorean ? '오늘의 기록하기' : 'Record Today';
  String get recordedToday => isKorean ? '오늘 기록 완료' : 'Recorded Today';
  String get renderVideo => isKorean ? '영상 렌더링' : 'Render Video';
  String get deleteRecordTitle => isKorean ? '기록 삭제' : 'Delete Record';
  String get deleteRecordConfirm => isKorean ? '이 기록을 삭제하시겠습니까? 삭제된 데이터는 복구할 수 없습니다.' : 'Are you sure you want to delete this record? This cannot be undone.';
  String get noRecordsToRender => isKorean ? '렌더링할 기록이 없습니다. 먼저 기록을 생성해주세요.' : 'No records to render. Please create a record first.';
  String get totalRecords => isKorean ? '총 기록' : 'Total Records';
  String get currentWeight => isKorean ? '최근 몸무게' : 'Latest Weight';
  String get weightUnit => isKorean ? 'kg' : 'kg';

  // Render Video Dialog
  String get renderVideoDialogTitle => isKorean ? '타임라인 영상 만들기' : 'Create Timeline Video';
  String get slideIntervalPrompt => isKorean ? '슬라이드 표시 시간 (초):' : 'Slide display interval (seconds):';
  String get slideIntervalHint => isKorean ? '예: 1.0 (0.2초 ~ 5.0초)' : 'e.g. 1.0 (0.2s - 5.0s)';
  String get renderingVideo => isKorean ? '영상 렌더링 중...' : 'Rendering video...';
  String get exportVideo => isKorean ? '영상 공유하기' : 'Share Video';
  String get selectProfilesPrompt => isKorean ? '포함할 각도 선택:' : 'Select profiles to include:';
  String get selectAtLeastOneProfile => isKorean ? '최소 1개 이상의 각도를 선택해주세요.' : 'Please select at least one profile.';

  // Capture Screen
  String get shoot => isKorean ? '촬영 시작' : 'Shoot';
  String get retake => isKorean ? '다시 촬영' : 'Retake';
  String get angleFront => isKorean ? '정면' : 'Front';
  String get angleLeft => isKorean ? '좌측' : 'Left';
  String get angleBack => isKorean ? '후면' : 'Back';
  String get angleRight => isKorean ? '우측' : 'Right';
  String angleStep(int step) => isKorean ? '$step/4 단계' : 'Step $step/4';
  String get maskFacePrompt => isKorean ? '얼굴 가리기 (마스킹)' : 'Mask Face';
  String get enterWeightTitle => isKorean ? '몸무게 입력' : 'Enter Body Weight';
  String get enterWeightHint => isKorean ? '예: 65.5' : 'e.g. 65.5';
  String get finishRecord => isKorean ? '기록 완료' : 'Finish Record';
  String get reviewPhotos => isKorean ? '촬영 결과 확인' : 'Review Photos';
  String get invalidWeight => isKorean ? '유효한 몸무게를 입력해주세요' : 'Please enter a valid weight';
  String get adjustFaceBlur => isKorean ? '얼굴 블러 위치 조정' : 'Adjust Face Blur';
  String get adjustFaceBlurShort => isKorean ? '블러 조정' : 'Adjust';
  String get adjustFaceBlurHint => isKorean ? '원을 드래그하여 얼굴 위치에 맞춰주세요' : 'Drag the circle over the face to adjust blur';
  String get tapToAdjustFaceBlur => isKorean ? '사진을 탭하여 얼굴 블러 위치를 조정할 수 있습니다' : 'Tap any photo to adjust face blur position';
  String get resetPosition => isKorean ? '초기화' : 'Reset';
  String get circleSize => isKorean ? '크기' : 'Size';
  String get apply => isKorean ? '적용' : 'Apply';
  String get faceBlurUpdated => isKorean ? '얼굴 블러 위치가 변경되었습니다' : 'Face blur position updated';
  String get loadingPhoto => isKorean ? '사진 불러오는 중...' : 'Loading photo...';

  // TTS Phrases
  String get ttsStandInFront => isKorean ? '카메라 앞에 서 주세요.' : 'Please stand in front of the camera.';
  String get ttsNoBody => isKorean ? '신체가 감지되지 않았습니다.' : 'No body is detected.';
  String get ttsMultipleBodies => isKorean ? '여러 명이 감지되었습니다.' : 'Multiple bodies detected.';
  String get ttsMoveToCenter => isKorean ? '화면 중앙으로 이동해 주세요.' : 'Please move to the center.';
  String get ttsMoveFurtherAway => isKorean ? '발부터 머리까지 전신이 보이도록 카메라에서 더 멀리 떨어져 주세요.' : 'Please move further away from the camera so that your feet to head is within the frame.';
  String get ttsTurnLeft => isKorean ? '왼쪽으로 돌아주세요.' : 'Please turn left.';
  String get ttsReady => isKorean ? '자세를 유지하세요.' : 'Hold still.';
  String get ttsCountdown3 => isKorean ? '셋' : '3';
  String get ttsCountdown2 => isKorean ? '둘' : '2';
  String get ttsCountdown1 => isKorean ? '하나' : '1';

  // Settings Screen
  String get settingsTitle => isKorean ? '설정' : 'Settings';
  String get languageTitle => isKorean ? '언어' : 'Language';
  String get themeTitle => isKorean ? '테마' : 'Theme';
  String get lightTheme => isKorean ? '라이트 모드' : 'Light Mode';
  String get darkTheme => isKorean ? '다크 모드' : 'Dark Mode';
  String get securitySection => isKorean ? '보안' : 'Security';
  String get changePin => isKorean ? 'PIN 번호 변경' : 'Change PIN';
  String get useLocalAuthTitle => isKorean ? '생체 인증 사용' : 'Use Biometric Authentication';
  String get useLocalAuthSubtitle => isKorean ? 'FaceID / TouchID 또는 지문으로 잠금 해제' : 'Unlock with FaceID / TouchID or Fingerprint';
  String get captureModeSection => isKorean ? '촬영 모드' : 'Capture Mode';
  String get freeCapture => isKorean ? '자유 촬영' : 'Free Capture';
  String get freeCaptureDesc => isKorean ? '언제든지 자유롭게 촬영' : 'Capture anytime as desired';
  String get fixedTimeCapture => isKorean ? '정해진 시간 촬영' : 'Fixed Time Capture';
  String get fixedTimeCaptureDesc => isKorean ? '지정한 시간에 알림을 받고 촬영' : 'Notify and capture at a scheduled time everyday';
  String get captureTime => isKorean ? '촬영 시간' : 'Capture Time';
  String get dataManagement => isKorean ? '데이터 관리' : 'Data Management';
  String get clearAllData => isKorean ? '모든 데이터 초기화' : 'Clear All Data';
  String get clearAllDataConfirm => isKorean ? '정말로 모든 사진과 기록을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.' : 'Are you sure you want to delete all photos and records? This cannot be undone.';
  String get configJsonSection => isKorean ? 'config.json 설정 파일' : 'config.json File';
  String get copyConfigJson => isKorean ? '설정 복사' : 'Copy Config';
  String get configCopied => isKorean ? '설정이 클립보드에 복사되었습니다.' : 'Config copied to clipboard.';
  String get editRawConfig => isKorean ? '직접 JSON 편집' : 'Edit Raw JSON';

  // Record Detail Screen
  String get recordDetailTitle => isKorean ? '기록 상세' : 'Record Details';
  String get recordedOn => isKorean ? '기록 날짜' : 'Recorded Date';
  String get weight => isKorean ? '몸무게' : 'Weight';
  String get enableFaceBlur => isKorean ? '얼굴 블러 적용' : 'Enable Face Blur';
  String get enableFaceBlurTitle => isKorean ? '얼굴 블러 적용' : 'Apply Facial Blur';
  String get enableFaceBlurWarning => isKorean
      ? '이 작업은 되돌릴 수 없습니다.\n앱에 원본 사진이 백업되지 않으므로, 얼굴 블러가 사진 파일에 영구적으로 적용됩니다.'
      : 'This process cannot be reverted.\nBecause the app does not back up original photos, facial blur will be permanently applied to the photo files.';
  String get enableFaceBlurPrompt => isKorean
      ? '얼굴 블러 위치를 직접 확인 및 조정한 후 적용하거나, 바로 자동 적용할 수 있습니다.'
      : 'You can review and adjust the blur position before applying, or apply automatically.';
  String get applyAuto => isKorean ? '자동 적용' : 'Auto Apply';
  String get adjustAndApply => isKorean ? '위치 확인 및 조정' : 'Review & Adjust';
  String get applyingFaceBlur => isKorean ? '얼굴 블러 적용 중...' : 'Applying facial blur...';
  String get faceBlurAppliedSuccess => isKorean ? '얼굴 블러가 영구적으로 적용되었습니다.' : 'Facial blur has been permanently applied.';
  String get permanentBlurConfirmTitle => isKorean ? '영구 적용 확인' : 'Confirm Permanent Blur';
  String get permanentBlurConfirmContent => isKorean
      ? '선택한 위치로 4장의 사진에 얼굴 블러를 영구적으로 적용합니다.\n원본 사진으로 복구할 수 없습니다. 계속하시겠습니까?'
      : 'Permanently apply facial blur to all 4 photos at the selected positions?\nThis cannot be undone and original photos cannot be restored. Proceed?';
  String get applyPermanent => isKorean ? '영구 적용' : 'Apply Permanently';
  String get reviewFaceBlurTitle => isKorean ? '얼굴 블러 확인 및 조정' : 'Review & Adjust Face Blur';
  String get reviewFaceBlurWarningBanner => isKorean
      ? '⚠️ 이 작업은 되돌릴 수 없습니다. 원본 사진이 백업되지 않으므로 사진에 영구 적용됩니다. 사진을 탭하여 블러 위치를 조정한 후 적용하세요.'
      : '⚠️ This action cannot be undone. Photos will be permanently blurred. Tap any photo to adjust blur position before applying.';

  // Notifications
  String get reminderFixedTimeTitle => isKorean ? '오늘의 몸 기록 시간입니다!' : 'Time to record your body today!';
  String get reminderFixedTimeBody => isKorean ? '오늘의 4방향 사진과 몸무게를 기록해보세요.' : 'Take your daily 4 photos and record your weight.';
  String get reminderLateTitle => isKorean ? '오늘 기록을 잊으셨나요?' : 'Forgot to record, today?';
  String get reminderLateBody => isKorean ? '하루가 지나기 전에 오늘 몸의 변화를 기록해두세요!' : 'Record your body changes before the day ends!';

  // Rewarded Ads & Video Render
  String get watchAdToRender => isKorean ? '광고 시청 후 비디오 생성' : 'Watch Ad to Render';
  String get watchAdPromptMessage => isKorean
      ? '짧은 리워드 광고(15~30초)를 시청한 후 고화질 타임랩스 비디오를 생성합니다.'
      : 'Watch a short video ad (15~30s) to render your progression time-lapse.';
  String get adMustBeWatchedToRender => isKorean
      ? '광고를 끝까지 시청해야 비디오를 생성할 수 있습니다.'
      : 'You must watch the full ad to render the video.';

  // Privacy & Legal
  String get privacySection => isKorean ? '개인정보 보호 및 약관' : 'Privacy & Legal';
  String get privacyPolicyTitle => isKorean ? '개인정보 처리방침' : 'Privacy Policy';
  String get privacyPolicySubtitle => isKorean
      ? '모든 사진과 측정 데이터는 기기 내에만 안전하게 보관됩니다.'
      : 'All photos and measurements remain 100% on your device.';
  String get adConsentSettingsTitle => isKorean ? '광고 개인정보 및 동의 설정' : 'Ad Privacy & Consent';
  String get adConsentSettingsSubtitle => isKorean
      ? '개인 맞춤형 광고 동의 여부를 관리합니다.'
      : 'Manage your advertising consent choices.';
  String get adConsentNotRequiredMessage => isKorean
      ? '현재 거주 지역(대한민국 등)에서는 광고 동의 설정이 필요하지 않습니다 (EU/EEA 및 영국 지역 사용자 전용).'
      : 'Ad consent management is not required in your region (only applicable to EU/EEA and UK users).';
}
