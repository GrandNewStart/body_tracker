import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_strings.dart';
import '../models/body_record.dart';
import '../models/face_mask_region.dart';
import '../services/config_service.dart';
import '../services/ml_service.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import 'face_adjustment_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => CaptureScreenState();
}

class CaptureScreenState extends State<CaptureScreen> with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = -1;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;

  // Session state
  int _currentAngleIndex = 0; // 0: Front, 1: Left, 2: Back, 3: Right
  bool _isSessionActive = false;
  int? _countdownValue;
  Timer? _countdownTimer;
  bool _isCountingDown = false;
  int _consecutiveReadyFrames = 0;
  int _nonReadyFrameCount = 0;
  int _countdownSessionId = 0;

  @visibleForTesting
  int get consecutiveReadyFrames => _consecutiveReadyFrames;

  @visibleForTesting
  int get nonReadyFrameCount => _nonReadyFrameCount;

  @visibleForTesting
  int get countdownSessionId => _countdownSessionId;

  @visibleForTesting
  bool get isCountingDown => _isCountingDown;

  @visibleForTesting
  int? get countdownValue => _countdownValue;

  @visibleForTesting
  void setSessionActiveForTest(bool active) {
    _isSessionActive = active;
  }

  @visibleForTesting
  void handlePoseResultForTest(PoseAnalysisResult result) {
    _handlePoseGuidanceAndCountdown(result);
  }

  @visibleForTesting
  void cancelCountdownForTest() {
    _cancelCountdown();
  }

  // Real-time analysis status
  PoseAnalysisResult _latestPoseResult = const PoseAnalysisResult(status: PoseStatus.noBody);
  DateTime _lastGuidanceTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Captured photos (original and masked)
  final List<String> _originalPhotos = [];
  final List<String> _maskedPhotos = [];
  final List<FaceMaskRegion> _faceMaskRegions = [];
  final List<FaceMaskRegion> _autoDetectedRegions = [];
  bool _isReviewing = false;
  bool _isMaskFaces = true;
  bool _isProcessingMasks = false;

  // Weight entry
  final TextEditingController _weightController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  String? _weightError;

  // Shutter flash effect
  late AnimationController _flashController;

  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _initCamera();
  }

  @override
  void dispose() {
    _countdownSessionId++;
    _isCountingDown = false;
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    _flashController.dispose();
    _weightController.dispose();
    _weightFocusNode.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _isCameraInitialized = false);
        return;
      }

      // Select rear camera
      _cameraIndex = _cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex == -1) _cameraIndex = 0;

      final camera = _cameras[_cameraIndex];
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() => _isCameraInitialized = true);

      // Start stream
      await _cameraController!.startImageStream(_processCameraFrame);
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (mounted) {
        setState(() => _isCameraInitialized = false);
      }
    }
  }

  void _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _isReviewing) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final result = await MlService.instance.processCameraImage(
        inputImage,
        imageSize,
        isCountingDown: _isCountingDown,
      );

      if (mounted) {
        setState(() {
          _latestPoseResult = result;
        });

        _handlePoseGuidanceAndCountdown(result);
      }
    } catch (e) {
      debugPrint('Error processing stream frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null || _cameraIndex == -1) return null;
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    } else {
      rotation = InputImageRotation.rotation0deg;
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _handlePoseGuidanceAndCountdown(PoseAnalysisResult result) {
    final strings = AppStrings(ConfigService.instance.config.language);

    if (!_isSessionActive) {
      // Passive guidance before user presses Shoot
      return;
    }

    // HOLD NEXT ACTION: If TTS voice playback is in progress for session prompts, hold actions
    if (!_isCountingDown && TtsService.instance.isSpeaking) {
      _consecutiveReadyFrames = 0;
      return;
    }

    // If countdown is active:
    if (_isCountingDown) {
      if (result.status == PoseStatus.ready) {
        // Posture maintained - reset non-ready glitch counter
        _nonReadyFrameCount = 0;
      } else {
        _nonReadyFrameCount++;

        // At final count (1), lock in unless user completely left frame
        if (_countdownValue == 1) {
          if (result.status == PoseStatus.noBody && _nonReadyFrameCount >= 6) {
            _cancelCountdown();
            _speakGuidance(result, strings);
          }
          return;
        }

        // For counts 3 and 2, tolerate transient glitches:
        // Immediate departure (noBody): tolerate up to 4 frames (~150-200ms)
        // Sway or occlusion (notCentered / notFullBody): tolerate up to 8 frames (~300-400ms)
        final threshold = (result.status == PoseStatus.noBody) ? 4 : 8;
        if (_nonReadyFrameCount >= threshold) {
          _cancelCountdown();
          _speakGuidance(result, strings);
        }
      }
      return;
    }

    // Guidance when session is active and countdown is NOT active
    switch (result.status) {
      case PoseStatus.noBody:
      case PoseStatus.multipleBodies:
      case PoseStatus.notFullBody:
      case PoseStatus.notCentered:
        _consecutiveReadyFrames = 0;
        _speakGuidance(result, strings);
        break;

      case PoseStatus.ready:
        // Require steady posture across 4 consecutive frames (~200ms)
        // to prevent premature countdown starts when turning or walking into frame
        _consecutiveReadyFrames++;
        if (_consecutiveReadyFrames >= 4) {
          _consecutiveReadyFrames = 0;
          _nonReadyFrameCount = 0;
          _startCountdown();
        }
        break;
    }
  }

  void _speakGuidance(PoseAnalysisResult result, AppStrings strings) {
    // Hold if already speaking
    if (TtsService.instance.isSpeaking) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastGuidanceTime) < const Duration(seconds: 3)) {
      return;
    }
    _lastGuidanceTime = now;

    String text;
    switch (result.status) {
      case PoseStatus.noBody:
        text = strings.ttsNoBody;
        break;
      case PoseStatus.multipleBodies:
        text = strings.ttsMultipleBodies;
        break;
      case PoseStatus.notFullBody:
        text = strings.ttsMoveFurtherAway;
        break;
      case PoseStatus.notCentered:
        text = strings.ttsMoveToCenter;
        break;
      case PoseStatus.ready:
        text = strings.ttsReady;
        break;
    }

    TtsService.instance.speak(text, isGuidance: true);
  }

  Future<void> _startShootSession() async {
    final strings = AppStrings(ConfigService.instance.config.language);
    _consecutiveReadyFrames = 0;
    _nonReadyFrameCount = 0;
    _countdownSessionId++;
    setState(() {
      _isSessionActive = true;
      _currentAngleIndex = 0;
      _originalPhotos.clear();
      _maskedPhotos.clear();
    });

    // Hold actions until initial prompt "Stand in front of the camera" is completely spoken
    await TtsService.instance.speak(strings.ttsStandInFront);
  }

  Future<void> _startCountdown() async {
    if (_isCountingDown || TtsService.instance.isSpeaking) return;

    final strings = AppStrings(ConfigService.instance.config.language);
    final sessionId = ++_countdownSessionId;
    _isCountingDown = true;
    _nonReadyFrameCount = 0;

    for (int count = 3; count >= 1; count--) {
      if (!mounted || !_isCountingDown || _countdownSessionId != sessionId) break;

      setState(() {
        _countdownValue = count;
      });

      final countText = count == 3
          ? strings.ttsCountdown3
          : (count == 2 ? strings.ttsCountdown2 : strings.ttsCountdown1);

      // Hold each countdown step until the voice playback finishes completely!
      await TtsService.instance.speak(countText);

      if (!mounted || !_isCountingDown || _countdownSessionId != sessionId) break;

      // Brief gap between numbers if not cancelled
      if (count > 1 && _isCountingDown) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    if (!mounted || !_isCountingDown || _countdownSessionId != sessionId) return;

    setState(() {
      _countdownValue = null;
      _isCountingDown = false;
    });

    // Take photo only after countdown audio finishes
    await _takePhoto();
  }

  void _cancelCountdown() {
    _countdownSessionId++;
    _isCountingDown = false;
    _consecutiveReadyFrames = 0;
    _nonReadyFrameCount = 0;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    unawaited(TtsService.instance.stop());
    if (mounted) {
      setState(() {
        _countdownValue = null;
      });
    }
  }

  Future<void> _takePhoto() async {
    final strings = AppStrings(ConfigService.instance.config.language);

    try {
      // Explicitly play mechanical camera shutter sound (configured for silent mode playback)
      unawaited(SoundService.instance.playShutter());

      // Visual flash
      _flashController.forward(from: 0.0).then((_) => _flashController.reverse());

      XFile photo;
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        // Stop stream briefly to capture high-res photo
        await _cameraController!.stopImageStream();
        photo = await _cameraController!.takePicture();
      } else {
        // Fallback for simulation/testing
        photo = XFile('');
      }

      _originalPhotos.add(photo.path);

      if (_currentAngleIndex < 3) {
        // Brief pause after shutter sound before giving the turn prompt
        await Future.delayed(const Duration(milliseconds: 300));

        setState(() {
          _currentAngleIndex++;
        });

        // Reset stabilization counters for new angle
        _consecutiveReadyFrames = 0;
        _nonReadyFrameCount = 0;
        _isCountingDown = false;
        _countdownValue = null;

        // Hold next action until "Turn left" voice is completely finished playing!
        await TtsService.instance.speak(strings.ttsTurnLeft);

        // Pause to give user time to turn
        await Future.delayed(const Duration(milliseconds: 2000));

        // Reset debounce once again right before resuming frame stream
        _consecutiveReadyFrames = 0;
        _nonReadyFrameCount = 0;

        // Resume camera stream ONLY AFTER the voice has ended and user has turned
        if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
          try {
            await _cameraController!.startImageStream(_processCameraFrame);
          } catch (_) {}
        }
      } else {
        // All 4 photos captured!
        _finishCaptureSession();
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.startImageStream(_processCameraFrame);
        } catch (_) {}
      }
    }
  }

  Future<void> _finishCaptureSession() async {
    setState(() {
      _isSessionActive = false;
      _isReviewing = true;
      _isProcessingMasks = true;
    });

    // Run face detection & masking on all 4 photos
    final tempDir = Directory.systemTemp;
    _maskedPhotos.clear();
    _faceMaskRegions.clear();
    _autoDetectedRegions.clear();

    for (int i = 0; i < _originalPhotos.length; i++) {
      final origPath = _originalPhotos[i];
      final maskedPath = '${tempDir.path}/masked_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final region = await MlService.instance.detectFaceRegion(origPath);
      _faceMaskRegions.add(region);
      _autoDetectedRegions.add(region);

      final resultPath = await MlService.instance.applyFaceMask(
        originalImagePath: origPath,
        maskedOutputPath: maskedPath,
        region: region,
      );
      _maskedPhotos.add(resultPath);
    }

    if (mounted) {
      setState(() {
        _isProcessingMasks = false;
      });
    }
  }

  Future<void> _openFaceAdjustment(int index) async {
    if (index >= _originalPhotos.length || !File(_originalPhotos[index]).existsSync()) {
      return;
    }

    final strings = AppStrings(ConfigService.instance.config.language);
    final angleLabels = [
      strings.angleFront,
      strings.angleLeft,
      strings.angleBack,
      strings.angleRight,
    ];
    final angleLabel = index < angleLabels.length ? angleLabels[index] : '';

    final currentRegion = index < _faceMaskRegions.length
        ? _faceMaskRegions[index]
        : FaceMaskRegion.defaultHead;
    final autoRegion = index < _autoDetectedRegions.length
        ? _autoDetectedRegions[index]
        : currentRegion;

    final newRegion = await Navigator.of(context).push<FaceMaskRegion>(
      MaterialPageRoute(
        builder: (context) => FaceAdjustmentScreen(
          imagePath: _originalPhotos[index],
          angleLabel: angleLabel,
          initialRegion: currentRegion,
          autoDetectedRegion: autoRegion,
        ),
      ),
    );

    if (newRegion != null && mounted) {
      setState(() {
        _isProcessingMasks = true;
      });

      final tempDir = Directory.systemTemp;
      final maskedPath = '${tempDir.path}/masked_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      await MlService.instance.applyFaceMask(
        originalImagePath: _originalPhotos[index],
        maskedOutputPath: maskedPath,
        region: newRegion,
      );

      if (mounted) {
        setState(() {
          if (index < _faceMaskRegions.length) {
            _faceMaskRegions[index] = newRegion;
          }
          if (index < _maskedPhotos.length) {
            _maskedPhotos[index] = maskedPath;
          }
          _isMaskFaces = true;
          _isProcessingMasks = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.faceBlurUpdated),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _retakeAll() async {
    _countdownSessionId++;
    _isCountingDown = false;
    _consecutiveReadyFrames = 0;
    _nonReadyFrameCount = 0;
    TtsService.instance.stop();
    setState(() {
      _isReviewing = false;
      _isSessionActive = false;
      _currentAngleIndex = 0;
      _originalPhotos.clear();
      _maskedPhotos.clear();
      _faceMaskRegions.clear();
      _autoDetectedRegions.clear();
      _countdownValue = null;
      _weightError = null;
    });

    if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.startImageStream(_processCameraFrame);
      } catch (e) {
        debugPrint('Error resuming stream: $e');
      }
    }
  }

  Future<void> _saveRecord() async {
    final strings = AppStrings(ConfigService.instance.config.language);
    final weightText = _weightController.text.trim();
    final weight = double.tryParse(weightText);

    if (weight == null || weight <= 0 || weight > 500) {
      setState(() {
        _weightError = strings.invalidWeight;
      });
      return;
    }

    // Selected photo paths: masked or original based on user choice
    final chosenPhotos = _isMaskFaces ? _maskedPhotos : _originalPhotos;
    final photosDir = StorageService.instance.photosDirPath;
    final recordId = const Uuid().v4();
    final now = DateTime.now();

    final persistentPaths = <String>[];
    final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    for (int i = 0; i < 4; i++) {
      final angleName = ['front', 'left', 'back', 'right'][i];
      final srcPath = (i < chosenPhotos.length) ? chosenPhotos[i] : '';
      final fileName = '${datePrefix}_${recordId.substring(0, 8)}_$angleName.jpg';
      final destPath = '$photosDir/$fileName';

      if (srcPath.isNotEmpty && File(srcPath).existsSync()) {
        await File(srcPath).copy(destPath);
      } else {
        // Fallback placeholder file
        final file = File(destPath);
        await file.writeAsBytes([]);
      }
      persistentPaths.add(destPath);
    }

    final newRecord = BodyRecord(
      id: recordId,
      date: now,
      weight: weight,
      frontImagePath: persistentPaths[0],
      leftImagePath: persistentPaths[1],
      backImagePath: persistentPaths[2],
      rightImagePath: persistentPaths[3],
      isMasked: _isMaskFaces,
      createdAt: now,
    );

    await StorageService.instance.addRecord(newRecord);
    await NotificationService.instance.updateSchedules(
      ConfigService.instance.config,
      true,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ConfigService.instance.config.language);

    if (_isReviewing) {
      return _buildReviewScreen(strings);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Viewfinder
          if (_isCameraInitialized && _cameraController != null)
            Center(
              child: CameraPreview(_cameraController!),
            )
          else
            _buildCameraFallback(strings),

          // 2. Viewfinder Silhouette / Center Guides
          _buildCenterGuides(),

          // 3. Shutter Flash Animation
          AnimatedBuilder(
            animation: _flashController,
            builder: (context, child) => Container(
              color: Colors.white.withValues(alpha: _flashController.value * 0.9),
            ),
          ),

          // 4. Header Overlay (Angle step & Close button)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeaderOverlay(strings),
          ),

          // 5. Center Big Countdown
          if (_countdownValue != null)
            Center(
              child: AnimatedScale(
                scale: 1.2,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$_countdownValue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // 6. Bottom Guidance Banner & Shoot Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomOverlay(strings),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderOverlay(AppStrings strings) {
    final angleNames = [
      strings.angleFront,
      strings.angleLeft,
      strings.angleBack,
      strings.angleRight,
    ];
    final currentAngleName = angleNames[_currentAngleIndex];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${strings.angleStep(_currentAngleIndex + 1)}: $currentAngleName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48), // Balance close button
          ],
        ),
      ),
    );
  }

  Widget _buildCenterGuides() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75,
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            border: Border.all(
              color: _latestPoseResult.status == PoseStatus.ready
                  ? Colors.greenAccent
                  : Colors.white.withValues(alpha: 0.4),
              width: _latestPoseResult.status == PoseStatus.ready ? 3 : 1.5,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top head marker
              Container(
                margin: const EdgeInsets.only(top: 16),
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
              // Bottom feet marker
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 100,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(AppStrings strings) {
    String guideText = '';
    Color badgeColor = Colors.black54;

    switch (_latestPoseResult.status) {
      case PoseStatus.noBody:
        guideText = strings.ttsNoBody;
        badgeColor = Colors.orange.withValues(alpha: 0.8);
        break;
      case PoseStatus.multipleBodies:
        guideText = strings.ttsMultipleBodies;
        badgeColor = Colors.red.withValues(alpha: 0.8);
        break;
      case PoseStatus.notFullBody:
        guideText = strings.ttsMoveFurtherAway;
        badgeColor = Colors.orange.withValues(alpha: 0.8);
        break;
      case PoseStatus.notCentered:
        guideText = strings.ttsMoveToCenter;
        badgeColor = Colors.orange.withValues(alpha: 0.8);
        break;
      case PoseStatus.ready:
        guideText = strings.ttsReady;
        badgeColor = Colors.green.withValues(alpha: 0.8);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 16, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live guidance badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  guideText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Shoot button (or progress indicator if session is active)
              if (!_isSessionActive)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: Text(
                    strings.shoot,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _startShootSession,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isDone = index < _currentAngleIndex;
                    final isCurrent = index == _currentAngleIndex;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: isCurrent ? 24 : 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDone
                            ? Colors.greenAccent
                            : (isCurrent ? Colors.white : Colors.white24),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraFallback(AppStrings strings) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_outlined, size: 64, color: Colors.white54),
          const SizedBox(height: 12),
          Text(
            strings.isKorean ? '카메라를 준비 중입니다...' : 'Initializing camera...',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          // Simulation trigger button for desktop / emulator environments
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () {
              // Simulate taking 4 placeholder photos
              final tempDir = Directory.systemTemp;
              for (int i = 0; i < 4; i++) {
                final f = File('${tempDir.path}/simulated_$i.jpg');
                if (!f.existsSync()) f.writeAsBytesSync([]);
                _originalPhotos.add(f.path);
              }
              _finishCaptureSession();
            },
            child: Text(strings.isKorean ? '시뮬레이션으로 계속하기' : 'Continue with Simulation'),
          ),
        ],
      ),
    );
  }

  // ---------------- Review & Face Masking Screen ----------------
  Widget _buildReviewScreen(AppStrings strings) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayedPhotos = _isMaskFaces ? _maskedPhotos : _originalPhotos;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.reviewPhotos),
        leading: IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: strings.retake,
          onPressed: _retakeAll,
        ),
      ),
      body: _isProcessingMasks
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    strings.isKorean
                        ? '얼굴 감지 및 마스킹 처리 중...'
                        : 'Detecting faces and applying mask...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hint banner to adjust face blur
                  if (_isMaskFaces) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (_originalPhotos.isNotEmpty) {
                          _openFaceAdjustment(0);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.touch_app_rounded, size: 20, color: colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                strings.tapToAdjustFaceBlur,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 4 photo preview grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 3 / 4,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final path = (index < displayedPhotos.length) ? displayedPhotos[index] : '';
                      final label = [
                        strings.angleFront,
                        strings.angleLeft,
                        strings.angleBack,
                        strings.angleRight,
                      ][index];
                      final file = File(path);

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openFaceAdjustment(index),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colorScheme.outlineVariant),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: file.existsSync()
                                  ? Image.file(file, fit: BoxFit.cover)
                                  : const Center(child: Icon(Icons.image)),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (_isMaskFaces)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24, width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.tune_rounded, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        strings.adjustFaceBlurShort,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Face Masking Toggle
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      title: Text(
                        strings.maskFacePrompt,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        strings.isKorean
                            ? '얼굴 영역을 자동으로 블러/모자이크 처리합니다'
                            : 'Automatically pixelates/blurs detected faces',
                      ),
                      value: _isMaskFaces,
                      onChanged: (val) {
                        setState(() => _isMaskFaces = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Body Weight Input
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.enterWeightTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _weightController,
                            focusNode: _weightFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: strings.enterWeightHint,
                              suffixText: strings.weightUnit,
                              prefixIcon: const Icon(Icons.monitor_weight_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorText: _weightError,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons: Retake or Finish
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _retakeAll,
                          child: Text(strings.retake),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _saveRecord,
                          child: Text(
                            strings.finishRecord,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
