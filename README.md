# Body Tracker (바디 트래커) 📸🏋️‍♂️

A privacy-first, 100% on-device Flutter mobile application designed for fitness enthusiasts to capture, track, and visualize their physique progression over time. 

Powered by on-device computer vision (Google ML Kit), **Body Tracker** guides users through standardized 4-angle photo captures (Front, Left, Back, Right), provides customizable facial mosaic blur to protect identity, and compiles historical records into smooth, watermark-annotated progression time-lapse videos.

---

## 🌟 Key Features

### 1. Hands-Free, 4-Angle Guided Capture Flow
* **Standardized 4-Angle Recording:** Guided sequence capturing Front, Left Profile, Back, and Right Profile for complete physique documentation.
* **Real-Time Pose Assessment:** Evaluates body alignment and full-body visibility before triggering capture.
* **Audio & Voice Guidance:** Bilingual Text-to-Speech (Korean & English) voice cues and audible shutter playback guide the user from a distance.
* **Jitter-Resistant Countdown:** Uses multi-frame debounce and hysteresis thresholds so micro-movements don't repeatedly reset the capture countdown.

### 2. Privacy-First Identity Protection (Face Blur)
* **Automatic Facial Detection:** Detects faces in captured photos and automatically overlays a privacy mosaic mask.
* **Interactive Drag-and-Resize Adjustment:** Users can drag the circular mask and resize its radius on the screen to ensure perfect coverage.
* **Post-Capture / Retroactive Facial Blur:** Enables permanent facial blur on previously saved records at any time directly from the record viewer. The mosaic is permanently burned into the underlying image file to ensure facial biometrics cannot be recovered.

### 3. Local-First Security & App Lock
* **PIN Protection:** Numerical PIN keypad with option for number randomization to prevent shoulder surfing.
* **Biometric Authentication:** Face ID / Touch ID (iOS) and Fingerprint / BiometricPrompt (Android).
* **Zero Cloud Dependency:** All photos, weights, and timestamps stay exclusively in the device's sandboxed local storage (`getApplicationDocumentsDirectory()`) and encrypted hardware keystore (`flutter_secure_storage`).

### 4. Progression Time-Lapse Video Synthesis
* **Dynamic Angle Filtering:** Select which angles to include in the video (e.g., Front-only, Profiles, or all 4 angles).
* **Smooth Cross-Fade Transitions:** Custom alpha-blended frame transitions between consecutive progress records.
* **Watermark & Splash Intro/Outro:** Automatically burns date, elapsed days, and body weight onto each frame, complete with branded animated splash screens.
* **Native Export:** Exports MP4 videos directly to the system photo library or share sheet.

### 5. Internationalization & Utilities
* **Bilingual Support:** Complete localization in Korean and English.
* **Configurable Reminders:** Scheduled local notifications for daily or weekly progress check-ins.

---

## 🔬 Computer Vision & Image Processing Techniques

Body Tracker combines real-time machine learning inference with digital image processing pipelines running entirely on the user's mobile device:

### 1. 33-Landmark Skeletal Pose Estimation
* **Inference Engine:** Google ML Kit Pose Detection (BlazePose architecture).
* **3D Coordinate Mapping:** Tracks 33 anatomical landmarks (shoulders, elbows, wrists, hips, knees, ankles, heels, and foot indices) from live camera frames.
* **Sensor-to-Screen Projection:** Automatically normalizes and transforms coordinates across device camera aspect ratios and sensor orientations.

### 2. Angle-Adaptive Landmark Validation & Occlusion Handling
* **Profile-Specific Heuristics:** Validates poses based on the target angle:
  * *Front/Back:* Requires bilateral symmetry (both shoulders, hips, and lower limbs visible within normalized boundary boxes).
  * *Side Profiles:* Automatically detects and handles self-occlusion. Relaxed bilateral requirements dynamically focus tracking on the facing shoulder, hip, and foot landmarks.
* **Occlusion Fallback Chains:** If ankle joints are occluded by clothing or footwear, the validator falls back to heel and foot index landmarks to avoid false rejections.
* **Edge Cutoff Detection:** Prevents capture if critical body extremities extend outside the viewfinder margins.

### 3. Temporal Debouncing & Hysteresis Filtering
* **State Machine:** Governs transitions between `No Body Detected`, `Multiple Bodies`, `Adjusting Position`, `Ready`, and `Counting Down`.
* **Hysteresis Bands:** Establishes dual confidence thresholds ($T_{enter} > T_{exit}$) to eliminate rapid toggling between ready and non-ready states caused by sensor noise.
* **Countdown Latch:** Once countdown begins, positional tolerance relaxes slightly to allow the user to settle into their final pose without cancelling the shot.

### 4. Pixelation / Mosaic Downsampling Pipeline
* **Facial Detection:** Leverages Google ML Kit Face Detection to extract facial bounding boxes and landmarks.
* **Multi-Pass Downsampling & Upscaling:**
  1. Crops the target subregion bounded by the user-adjusted circle/ellipse.
  2. Downsamples the region by a factor of 8×–12× using area averaging, eliminating high-frequency biometric details.
  3. Upscales the downsampled block back to original dimensions using nearest-neighbor interpolation, producing clean, sharp privacy mosaic tiles.
* **Permanent Destruction:** Blits mosaic pixels directly onto the raw JPEG image bitmap buffer before file writing, permanently sanitizing sensitive imagery.

### 5. Alpha-Blended Frame Interpolation for Video Rendering
* **Linear Alpha Blending:** Computes intermediate transition frames between consecutive dates:
  $$I_{\text{blend}}(x, y) = (1 - \alpha) \cdot I_{A}(x, y) + \alpha \cdot I_{B}(x, y) \quad \text{where } \alpha \in [0, 1]$$
* **Metadata Watermark Rasterization:** Renders localized text strings (date, body weight, progression day count) directly onto RGB frame buffers prior to hardware encoding.

---

## 📦 3rd Party Libraries & Architecture

| Package | Version | Purpose |
| :--- | :--- | :--- |
| **[`google_mlkit_pose_detection`](https://pub.dev/packages/google_mlkit_pose_detection)** | `^0.16.1` | On-device 33-landmark body pose estimation and posture analysis. |
| **[`google_mlkit_face_detection`](https://pub.dev/packages/google_mlkit_face_detection)** | `^0.15.1` | On-device face detection for identity privacy masking. |
| **[`camera`](https://pub.dev/packages/camera)** | `^0.12.1` | Native camera streaming and high-resolution photo capture. |
| **[`flutter_quick_video_encoder`](https://pub.dev/packages/flutter_quick_video_encoder)** | `^1.7.2` | High-performance native hardware video encoder (H.264/MP4). |
| **[`image`](https://pub.dev/packages/image)** | `^4.10.1` | Pure Dart image manipulation, mosaic pixelation, watermarking, and crossfade synthesis. |
| **[`local_auth`](https://pub.dev/packages/local_auth)** | `^3.0.2` | Biometric authentication (Face ID, Touch ID, Fingerprint). |
| **[`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)** | `^11.1.1` | Encrypted storage for PIN codes and sensitive settings (Keychain / Keystore). |
| **[`flutter_tts`](https://pub.dev/packages/flutter_tts)** | `^4.2.5` | Native Text-to-Speech voice instructions during capture flow. |
| **[`audioplayers`](https://pub.dev/packages/audioplayers)** | `^6.8.1` | Low-latency audio cues and camera shutter playback (supports silent mode playback). |
| **[`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications)** | `^22.3.1` | Local scheduled notifications and daily/weekly tracking reminders. |
| **[`path_provider`](https://pub.dev/packages/path_provider)** | `^2.1.6` | Resolution of sandboxed platform directories for photo and video storage. |
| **[`share_plus`](https://pub.dev/packages/share_plus)** | `^13.3.0` | Native OS share sheet integration for exported time-lapse videos. |
| **[`shared_preferences`](https://pub.dev/packages/shared_preferences)** | `^2.5.5` | Persistence of non-sensitive app configurations and preferences. |
| **[`intl`](https://pub.dev/packages/intl)** | `^0.20.3` | Localization, date formatting, and number formatting. |
| **[`timezone`](https://pub.dev/packages/timezone)** / **[`flutter_timezone`](https://pub.dev/packages/flutter_timezone)** | `^0.11.1` / `^5.1.0` | Timezone-aware local notification scheduling. |

---

## 🚀 Setup & Run Guide

### Prerequisites
* **Flutter SDK:** `>= 3.12.0` (Dart `>= 3.0.0`)
* **macOS:** Xcode 15+ & CocoaPods (for iOS build)
* **Android:** Android Studio with Android SDK (minSdk `23`, compileSdk `34`, Java `17`)
* **Hardware:** A physical iOS or Android smartphone is strongly recommended for camera feed and ML Kit inference testing.

### 1. Clone the Repository
```bash
git clone https://github.com/<your-username>/body_tracker.git
cd body_tracker
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Platform Setup

#### iOS
Ensure camera, microphone, face ID, and photo library permissions are configured in `ios/Runner/Info.plist` (already configured in this repository). Then install CocoaPods:
```bash
cd ios
pod install
cd ..
```

#### Android
Ensure your device is running Android 6.0+ (API level 23+). Android permissions for Camera, Notifications, and Biometrics are pre-configured in `android/app/src/main/AndroidManifest.xml`.

### 4. Run the Application
Connect your physical device via USB or wireless debugging and run:
```bash
flutter run
```

### 5. Running the Test Suite
The repository includes comprehensive unit and widget tests covering pose stabilization, blur processing, video frame generation, and state management:
```bash
flutter test
```

To run static analysis:
```bash
flutter analyze
```

---

## 🔒 Privacy & Architecture Note

Body Tracker operates under a strict **Zero-Knowledge / Local-First** architecture:
* No cloud servers, no third-party telemetry, and no remote databases are used.
* Photographs and video exports never leave the device unless explicitly exported by the user through the system share sheet.
* Biometric authentication is handled exclusively by native iOS LocalAuthentication and Android BiometricPrompt security enclaves.

---

## 📄 License

Copyright (c) 2026. All rights reserved.

This project is proprietary and confidential. Unauthorized copying, distribution, or commercial use of this software via any medium is strictly prohibited.
