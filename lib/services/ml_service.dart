import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import '../models/face_mask_region.dart';

enum PoseStatus {
  noBody,
  multipleBodies,
  notFullBody,
  notCentered,
  ready,
}

class PoseAnalysisResult {
  final PoseStatus status;
  final String? guideMessageEn;
  final String? guideMessageKr;
  final double? bodyCenterX;
  final Rect? bodyBounds;
  final List<Pose> poses;

  const PoseAnalysisResult({
    required this.status,
    this.guideMessageEn,
    this.guideMessageKr,
    this.bodyCenterX,
    this.bodyBounds,
    this.poses = const [],
  });
}

class MlService {
  static final MlService instance = MlService._internal();
  MlService._internal();

  PoseDetector? _poseDetector;
  FaceDetector? _faceDetector;

  void init() {
    try {
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.base,
        ),
      );

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableClassification: false,
          performanceMode: FaceDetectorMode.accurate,
          minFaceSize: 0.01,
        ),
      );
    } catch (e) {
      debugPrint('ML Kit initialization error: $e');
    }
  }

  Future<PoseAnalysisResult> processCameraImage(
    InputImage inputImage,
    Size imageSize, {
    bool isCountingDown = false,
  }) async {
    if (_poseDetector == null) {
      init();
    }

    try {
      final poses = await _poseDetector!.processImage(inputImage);
      return analyzePoses(poses, imageSize, isCountingDown: isCountingDown);
    } catch (e) {
      debugPrint('Error analyzing pose: $e');
      return const PoseAnalysisResult(
        status: PoseStatus.ready,
      );
    }
  }

  PoseAnalysisResult analyzePoses(
    List<Pose> poses,
    Size imageSize, {
    bool isCountingDown = false,
  }) {
    try {
      if (poses.isEmpty) {
      return const PoseAnalysisResult(
        status: PoseStatus.noBody,
        guideMessageEn: 'No body is detected',
        guideMessageKr: '신체가 감지되지 않았습니다',
      );
    }

    if (poses.length > 1) {
      return PoseAnalysisResult(
        status: PoseStatus.multipleBodies,
        guideMessageEn: 'Multiple bodies detected',
        guideMessageKr: '여러 명이 감지되었습니다',
        poses: poses,
      );
    }

    final pose = poses.first;
    final landmarks = pose.landmarks;

      // Extract key points
      final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
      final leftHip = landmarks[PoseLandmarkType.leftHip];
      final rightHip = landmarks[PoseLandmarkType.rightHip];

      // Calculate bounding box of visible body landmarks
      double minX = double.infinity;
      double maxX = -double.infinity;
      double minY = double.infinity;
      double maxY = -double.infinity;
      int visibleCount = 0;

      // Lower threshold during countdown to tolerate minor motion blur/glitches
      final minLikelihood = isCountingDown ? 0.25 : 0.30;

      for (final lm in landmarks.values) {
        if (lm.likelihood > minLikelihood) {
          visibleCount++;
          if (lm.x < minX) minX = lm.x;
          if (lm.x > maxX) maxX = lm.x;
          if (lm.y < minY) minY = lm.y;
          if (lm.y > maxY) maxY = lm.y;
        }
      }

      if (visibleCount < 5) {
        return const PoseAnalysisResult(
          status: PoseStatus.noBody,
          guideMessageEn: 'No body is detected',
          guideMessageKr: '신체가 감지되지 않았습니다',
        );
      }

      final bodyBounds = Rect.fromLTRB(minX, minY, maxX, maxY);

      // Check if head is visible across front, profile, and back angles:
      // - Front/Back: shoulders and/or facial/ear landmarks are visible.
      // - Profile: one shoulder and profile facial/ear landmarks are visible (far shoulder is occluded).
      // - Back: nose/mouth are occluded, but shoulders and/or ears are clearly visible.
      final headLandmarks = [
        landmarks[PoseLandmarkType.nose],
        landmarks[PoseLandmarkType.leftEye],
        landmarks[PoseLandmarkType.rightEye],
        landmarks[PoseLandmarkType.leftEar],
        landmarks[PoseLandmarkType.rightEar],
        landmarks[PoseLandmarkType.leftMouth],
        landmarks[PoseLandmarkType.rightMouth],
      ];
      final hasFacialOrCranial = headLandmarks.any((lm) => lm != null && lm.likelihood > 0.22);
      final hasShoulder = (leftShoulder != null && leftShoulder.likelihood > 0.25) ||
          (rightShoulder != null && rightShoulder.likelihood > 0.25);
      final hasHead = hasFacialOrCranial || hasShoulder;

      // Check if feet are visible across front, profile, and back angles:
      // In profile view, one leg/foot may occlude the other. Check ankles, heels, and foot indices.
      final feetLandmarks = [
        landmarks[PoseLandmarkType.leftAnkle],
        landmarks[PoseLandmarkType.rightAnkle],
        landmarks[PoseLandmarkType.leftHeel],
        landmarks[PoseLandmarkType.rightHeel],
        landmarks[PoseLandmarkType.leftFootIndex],
        landmarks[PoseLandmarkType.rightFootIndex],
      ];
      final hasFeet = feetLandmarks.any((lm) => lm != null && lm.likelihood > 0.22);

      // Also check margin from edges of image with hysteresis during countdown
      final imgWidth = imageSize.width > 0 ? imageSize.width : 720.0;
      final imgHeight = imageSize.height > 0 ? imageSize.height : 1280.0;

      final feetCutoffFactor = isCountingDown ? 0.995 : 0.98;
      final headCutoffFactor = isCountingDown ? 0.005 : 0.02;

      final isFeetCutOff = maxY > (imgHeight * feetCutoffFactor);
      final isHeadCutOff = minY < (imgHeight * headCutoffFactor);

      if (!hasFeet || !hasHead || isFeetCutOff || isHeadCutOff) {
        return PoseAnalysisResult(
          status: PoseStatus.notFullBody,
          guideMessageEn:
              'Please move further away from the camera so that feet to head is within the frame.',
          guideMessageKr:
              '전신이 보이도록 카메라에서 더 멀리 떨어져 주세요.',
          bodyBounds: bodyBounds,
          poses: poses,
        );
      }

      // Check horizontal centering:
      // In profile views, occluded hip or shoulder landmarks have low likelihood and must not be averaged.
      final leftHipValid = leftHip != null && leftHip.likelihood > 0.25;
      final rightHipValid = rightHip != null && rightHip.likelihood > 0.25;
      final leftShoulderValid = leftShoulder != null && leftShoulder.likelihood > 0.25;
      final rightShoulderValid = rightShoulder != null && rightShoulder.likelihood > 0.25;

      double centerX;
      if (leftHipValid && rightHipValid) {
        centerX = (leftHip.x + rightHip.x) / 2.0;
      } else if (leftShoulderValid && rightShoulderValid) {
        centerX = (leftShoulder.x + rightShoulder.x) / 2.0;
      } else if (leftHipValid) {
        centerX = leftHip.x;
      } else if (rightHipValid) {
        centerX = rightHip.x;
      } else if (leftShoulderValid) {
        centerX = leftShoulder.x;
      } else if (rightShoulderValid) {
        centerX = rightShoulder.x;
      } else {
        centerX = (minX + maxX) / 2.0;
      }

      final normalizedCenterX = centerX / imgWidth;

      // Allow 35% to 65% as the entry center corridor.
      // During countdown, widen corridor to 28% to 72% (hysteresis) to avoid minor sway restarts.
      final minCorridor = isCountingDown ? 0.28 : 0.35;
      final maxCorridor = isCountingDown ? 0.72 : 0.65;

      if (normalizedCenterX < minCorridor || normalizedCenterX > maxCorridor) {
        return PoseAnalysisResult(
          status: PoseStatus.notCentered,
          guideMessageEn: 'Please move to the center.',
          guideMessageKr: '화면 중앙으로 이동해 주세요.',
          bodyCenterX: normalizedCenterX,
          bodyBounds: bodyBounds,
          poses: poses,
        );
      }

      // Body is centered and full body in frame!
      return PoseAnalysisResult(
        status: PoseStatus.ready,
        guideMessageEn: 'Hold still',
        guideMessageKr: '자세를 유지하세요',
        bodyCenterX: normalizedCenterX,
        bodyBounds: bodyBounds,
        poses: poses,
      );
    } catch (e) {
      debugPrint('Error analyzing pose: $e');
      return const PoseAnalysisResult(
        status: PoseStatus.ready,
      );
    }
  }

  /// Detects the face/head region in [originalImagePath] and returns normalized [FaceMaskRegion].
  /// Falls back to pose detector landmarks or [FaceMaskRegion.defaultHead] if not detected.
  Future<FaceMaskRegion> detectFaceRegion(String originalImagePath) async {
    if (_faceDetector == null || _poseDetector == null) {
      init();
    }

    try {
      final inputImage = InputImage.fromFilePath(originalImagePath);
      final faces = await _faceDetector!.processImage(inputImage);

      Rect? detectedBox;
      if (faces.isNotEmpty) {
        detectedBox = faces.first.boundingBox;
      }

      // If face detector found nothing (e.g. back of body, profile angle, or far distance),
      // fall back to pose detector landmarks to identify head / neck location
      if (detectedBox == null && _poseDetector != null) {
        try {
          final poses = await _poseDetector!.processImage(inputImage);
          if (poses.isNotEmpty) {
            final pose = poses.first;
            final landmarks = pose.landmarks;

            final nose = landmarks[PoseLandmarkType.nose];
            final leftEye = landmarks[PoseLandmarkType.leftEye];
            final rightEye = landmarks[PoseLandmarkType.rightEye];
            final leftEar = landmarks[PoseLandmarkType.leftEar];
            final rightEar = landmarks[PoseLandmarkType.rightEar];
            final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
            final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

            // Collect detected facial/head points
            final headPoints = [nose, leftEye, rightEye, leftEar, rightEar]
                .where((p) => p != null && p.likelihood > 0.25)
                .cast<PoseLandmark>()
                .toList();

            if (headPoints.isNotEmpty) {
              double minX = headPoints.map((p) => p.x).reduce((a, b) => a < b ? a : b);
              double maxX = headPoints.map((p) => p.x).reduce((a, b) => a > b ? a : b);
              double minY = headPoints.map((p) => p.y).reduce((a, b) => a < b ? a : b);
              double maxY = headPoints.map((p) => p.y).reduce((a, b) => a > b ? a : b);

              double shoulderSpan = 0;
              if (leftShoulder != null &&
                  rightShoulder != null &&
                  leftShoulder.likelihood > 0.25 &&
                  rightShoulder.likelihood > 0.25) {
                shoulderSpan = (leftShoulder.x - rightShoulder.x).abs();
              }

              final estimatedRadius = shoulderSpan > 30 ? (shoulderSpan * 0.35) : 80.0;
              final centerX = (minX + maxX) / 2;
              final centerY = (minY + maxY) / 2;

              final boxW = (maxX - minX).clamp(estimatedRadius * 1.5, estimatedRadius * 2.5);
              final boxH = (maxY - minY).clamp(estimatedRadius * 1.8, estimatedRadius * 2.8);

              detectedBox = Rect.fromCenter(
                center: Offset(centerX, centerY),
                width: boxW,
                height: boxH,
              );
            } else if (leftShoulder != null &&
                rightShoulder != null &&
                leftShoulder.likelihood > 0.25 &&
                rightShoulder.likelihood > 0.25) {
              // Back of head view (no face landmarks visible)
              // Head is positioned directly above the midpoint of shoulders
              final midShoulderX = (leftShoulder.x + rightShoulder.x) / 2;
              final midShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
              final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs().clamp(50.0, 500.0);

              final headWidth = shoulderWidth * 0.65;
              final headHeight = shoulderWidth * 0.85;
              final headCenterY = midShoulderY - (headHeight * 0.6);

              detectedBox = Rect.fromCenter(
                center: Offset(midShoulderX, headCenterY),
                width: headWidth,
                height: headHeight,
              );
            }
          }
        } catch (e) {
          debugPrint('Pose fallback detection error: $e');
        }
      }

      final originalFile = File(originalImagePath);
      final bytes = originalFile.readAsBytesSync();
      var decodedImage = img.decodeImage(bytes);
      if (decodedImage != null) {
        decodedImage = img.bakeOrientation(decodedImage);
      }

      final imgW = (decodedImage?.width ?? 1080).toDouble();
      final imgH = (decodedImage?.height ?? 1920).toDouble();

      if (detectedBox != null) {
        final cx = detectedBox.left + detectedBox.width / 2;
        final cy = detectedBox.top + detectedBox.height / 2;
        final r = math.max(detectedBox.width, detectedBox.height) * 0.65;

        return FaceMaskRegion(
          x: (cx / imgW).clamp(0.05, 0.95),
          y: (cy / imgH).clamp(0.05, 0.95),
          radius: (r / imgW).clamp(0.06, 0.35),
        );
      }

      return FaceMaskRegion.defaultHead;
    } catch (e) {
      debugPrint('Face region detection error: $e');
      return FaceMaskRegion.defaultHead;
    }
  }

  /// Applies circular mosaic pixelation at [region] on [originalImagePath] and saves to [maskedOutputPath].
  Future<String> applyFaceMask({
    required String originalImagePath,
    required String maskedOutputPath,
    required FaceMaskRegion region,
  }) async {
    try {
      final originalFile = File(originalImagePath);
      final bytes = originalFile.readAsBytesSync();
      var decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        originalFile.copySync(maskedOutputPath);
        return maskedOutputPath;
      }

      // Bake EXIF orientation so pixel coordinates align
      decodedImage = img.bakeOrientation(decodedImage);

      final imgW = decodedImage.width;
      final imgH = decodedImage.height;

      final cx = (region.x * imgW).round();
      final cy = (region.y * imgH).round();
      final radius = (region.radius * imgW).round().clamp(10, imgW ~/ 2);

      final minX = (cx - radius).clamp(0, imgW - 1);
      final minY = (cy - radius).clamp(0, imgH - 1);
      final maxX = (cx + radius).clamp(0, imgW - 1);
      final maxY = (cy + radius).clamp(0, imgH - 1);

      // Pixelate/mosaic effect for clean, aesthetic privacy masking
      final blockSize = (radius * 2 / 10).clamp(10, 40).toInt();
      final r2 = radius * radius;

      for (int py = minY; py <= maxY; py += blockSize) {
        for (int px = minX; px <= maxX; px += blockSize) {
          final sampleX = (px + blockSize ~/ 2).clamp(0, imgW - 1);
          final sampleY = (py + blockSize ~/ 2).clamp(0, imgH - 1);

          final dx = sampleX - cx;
          final dy = sampleY - cy;
          if (dx * dx + dy * dy <= r2) {
            final pixel = decodedImage.getPixel(sampleX, sampleY);

            final blockW = (px + blockSize <= imgW) ? blockSize : (imgW - px);
            final blockH = (py + blockSize <= imgH) ? blockSize : (imgH - py);

            img.fillRect(
              decodedImage,
              x1: px,
              y1: py,
              x2: px + blockW,
              y2: py + blockH,
              color: pixel,
            );
          }
        }
      }

      final encodedJpg = img.encodeJpg(decodedImage, quality: 90);
      final maskedFile = File(maskedOutputPath);
      maskedFile.writeAsBytesSync(encodedJpg);
      return maskedOutputPath;
    } catch (e) {
      debugPrint('Apply face mask error: $e');
      final originalFile = File(originalImagePath);
      originalFile.copySync(maskedOutputPath);
      return maskedOutputPath;
    }
  }

  /// Detects face in [originalImagePath] and creates a masked version saved at [maskedOutputPath].
  /// If [customRegion] is provided, applies mosaic mask at that region directly.
  Future<String> maskFaceInImage({
    required String originalImagePath,
    required String maskedOutputPath,
    FaceMaskRegion? customRegion,
  }) async {
    final region = customRegion ?? await detectFaceRegion(originalImagePath);
    return applyFaceMask(
      originalImagePath: originalImagePath,
      maskedOutputPath: maskedOutputPath,
      region: region,
    );
  }

  void dispose() {
    _poseDetector?.close();
    _faceDetector?.close();
  }
}
