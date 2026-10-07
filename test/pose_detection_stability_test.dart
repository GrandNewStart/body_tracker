import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:body_tracker/services/ml_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const imageSize = Size(720, 1280);

  PoseLandmark createLm(PoseLandmarkType type, double x, double y, double likelihood) {
    return PoseLandmark(
      type: type,
      x: x,
      y: y,
      z: 0.0,
      likelihood: likelihood,
    );
  }

  Map<PoseLandmarkType, PoseLandmark> createFullFrontLandmarks({
    double centerX = 360,
    double headY = 100,
    double feetY = 1100,
  }) {
    final map = <PoseLandmarkType, PoseLandmark>{};
    // Head / Face
    map[PoseLandmarkType.nose] = createLm(PoseLandmarkType.nose, centerX, headY, 0.95);
    map[PoseLandmarkType.leftEye] = createLm(PoseLandmarkType.leftEye, centerX - 10, headY - 5, 0.95);
    map[PoseLandmarkType.rightEye] = createLm(PoseLandmarkType.rightEye, centerX + 10, headY - 5, 0.95);
    map[PoseLandmarkType.leftEar] = createLm(PoseLandmarkType.leftEar, centerX - 25, headY, 0.9);
    map[PoseLandmarkType.rightEar] = createLm(PoseLandmarkType.rightEar, centerX + 25, headY, 0.9);
    map[PoseLandmarkType.leftMouth] = createLm(PoseLandmarkType.leftMouth, centerX - 8, headY + 15, 0.9);
    map[PoseLandmarkType.rightMouth] = createLm(PoseLandmarkType.rightMouth, centerX + 8, headY + 15, 0.9);

    // Shoulders
    map[PoseLandmarkType.leftShoulder] = createLm(PoseLandmarkType.leftShoulder, centerX - 50, headY + 80, 0.95);
    map[PoseLandmarkType.rightShoulder] = createLm(PoseLandmarkType.rightShoulder, centerX + 50, headY + 80, 0.95);

    // Hips
    map[PoseLandmarkType.leftHip] = createLm(PoseLandmarkType.leftHip, centerX - 35, headY + 300, 0.95);
    map[PoseLandmarkType.rightHip] = createLm(PoseLandmarkType.rightHip, centerX + 35, headY + 300, 0.95);

    // Knees
    map[PoseLandmarkType.leftKnee] = createLm(PoseLandmarkType.leftKnee, centerX - 30, headY + 550, 0.95);
    map[PoseLandmarkType.rightKnee] = createLm(PoseLandmarkType.rightKnee, centerX + 30, headY + 550, 0.95);

    // Ankles & Feet
    map[PoseLandmarkType.leftAnkle] = createLm(PoseLandmarkType.leftAnkle, centerX - 25, feetY, 0.95);
    map[PoseLandmarkType.rightAnkle] = createLm(PoseLandmarkType.rightAnkle, centerX + 25, feetY, 0.95);
    map[PoseLandmarkType.leftHeel] = createLm(PoseLandmarkType.leftHeel, centerX - 25, feetY + 15, 0.95);
    map[PoseLandmarkType.rightHeel] = createLm(PoseLandmarkType.rightHeel, centerX + 25, feetY + 15, 0.95);
    map[PoseLandmarkType.leftFootIndex] = createLm(PoseLandmarkType.leftFootIndex, centerX - 25, feetY + 20, 0.95);
    map[PoseLandmarkType.rightFootIndex] = createLm(PoseLandmarkType.rightFootIndex, centerX + 25, feetY + 20, 0.95);

    return map;
  }

  group('Pose Detection Profile & Stability Tests', () {
    test('Empty poses returns noBody', () {
      final result = MlService.instance.analyzePoses([], imageSize);
      expect(result.status, PoseStatus.noBody);
    });

    test('Multiple poses returns multipleBodies', () {
      final p1 = Pose(landmarks: createFullFrontLandmarks());
      final p2 = Pose(landmarks: createFullFrontLandmarks());
      final result = MlService.instance.analyzePoses([p1, p2], imageSize);
      expect(result.status, PoseStatus.multipleBodies);
    });

    test('Standard front view body is ready', () {
      final pose = Pose(landmarks: createFullFrontLandmarks());
      final result = MlService.instance.analyzePoses([pose], imageSize);
      expect(result.status, PoseStatus.ready);
      expect(result.bodyCenterX, closeTo(0.5, 0.05));
    });

    test('Side profile view: far side occluded remains ready and centers on visible landmarks', () {
      final map = <PoseLandmarkType, PoseLandmark>{};
      const centerX = 360.0;
      const headY = 100.0;
      const feetY = 1100.0;

      // Profile landmarks (left side visible)
      map[PoseLandmarkType.nose] = createLm(PoseLandmarkType.nose, centerX + 15, headY, 0.9);
      map[PoseLandmarkType.leftEye] = createLm(PoseLandmarkType.leftEye, centerX + 5, headY - 5, 0.85);
      map[PoseLandmarkType.leftEar] = createLm(PoseLandmarkType.leftEar, centerX - 10, headY, 0.85);
      map[PoseLandmarkType.leftShoulder] = createLm(PoseLandmarkType.leftShoulder, centerX, headY + 80, 0.9);
      map[PoseLandmarkType.leftHip] = createLm(PoseLandmarkType.leftHip, centerX, headY + 300, 0.9);
      map[PoseLandmarkType.leftKnee] = createLm(PoseLandmarkType.leftKnee, centerX, headY + 550, 0.9);
      map[PoseLandmarkType.leftAnkle] = createLm(PoseLandmarkType.leftAnkle, centerX, feetY, 0.9);
      map[PoseLandmarkType.leftHeel] = createLm(PoseLandmarkType.leftHeel, centerX, feetY + 15, 0.9);

      // Occluded right side landmarks with low likelihood and phantom coordinates
      map[PoseLandmarkType.rightEye] = createLm(PoseLandmarkType.rightEye, 10, 10, 0.05);
      map[PoseLandmarkType.rightShoulder] = createLm(PoseLandmarkType.rightShoulder, 20, 20, 0.1);
      map[PoseLandmarkType.rightHip] = createLm(PoseLandmarkType.rightHip, 50, 50, 0.08);
      map[PoseLandmarkType.rightKnee] = createLm(PoseLandmarkType.rightKnee, 40, 40, 0.05);
      map[PoseLandmarkType.rightAnkle] = createLm(PoseLandmarkType.rightAnkle, 30, 30, 0.04);

      final pose = Pose(landmarks: map);
      final result = MlService.instance.analyzePoses([pose], imageSize);

      expect(result.status, PoseStatus.ready);
      // CenterX should not be pulled towards phantom rightHip at 50!
      // CenterX must correctly correspond to leftHip at 360 (360 / 720 = 0.5)
      expect(result.bodyCenterX, closeTo(0.5, 0.05));
    });

    test('Back view: face occluded but shoulders and feet visible remains ready', () {
      final map = <PoseLandmarkType, PoseLandmark>{};
      const centerX = 360.0;
      const headY = 100.0;
      const feetY = 1100.0;

      // Facial landmarks are invisible/occluded from behind
      map[PoseLandmarkType.nose] = createLm(PoseLandmarkType.nose, centerX, headY, 0.05);
      map[PoseLandmarkType.leftEye] = createLm(PoseLandmarkType.leftEye, centerX - 10, headY, 0.05);
      map[PoseLandmarkType.rightEye] = createLm(PoseLandmarkType.rightEye, centerX + 10, headY, 0.05);
      map[PoseLandmarkType.leftMouth] = createLm(PoseLandmarkType.leftMouth, centerX - 5, headY, 0.02);
      map[PoseLandmarkType.rightMouth] = createLm(PoseLandmarkType.rightMouth, centerX + 5, headY, 0.02);

      // Back of head / ears / shoulders visible
      map[PoseLandmarkType.leftEar] = createLm(PoseLandmarkType.leftEar, centerX - 25, headY, 0.6);
      map[PoseLandmarkType.rightEar] = createLm(PoseLandmarkType.rightEar, centerX + 25, headY, 0.6);
      map[PoseLandmarkType.leftShoulder] = createLm(PoseLandmarkType.leftShoulder, centerX - 50, headY + 80, 0.92);
      map[PoseLandmarkType.rightShoulder] = createLm(PoseLandmarkType.rightShoulder, centerX + 50, headY + 80, 0.92);

      // Hips, knees, feet
      map[PoseLandmarkType.leftHip] = createLm(PoseLandmarkType.leftHip, centerX - 35, headY + 300, 0.9);
      map[PoseLandmarkType.rightHip] = createLm(PoseLandmarkType.rightHip, centerX + 35, headY + 300, 0.9);
      map[PoseLandmarkType.leftKnee] = createLm(PoseLandmarkType.leftKnee, centerX - 30, headY + 550, 0.9);
      map[PoseLandmarkType.rightKnee] = createLm(PoseLandmarkType.rightKnee, centerX + 30, headY + 550, 0.9);
      map[PoseLandmarkType.leftAnkle] = createLm(PoseLandmarkType.leftAnkle, centerX - 25, feetY, 0.9);
      map[PoseLandmarkType.rightAnkle] = createLm(PoseLandmarkType.rightAnkle, centerX + 25, feetY, 0.9);

      final pose = Pose(landmarks: map);
      final result = MlService.instance.analyzePoses([pose], imageSize);

      expect(result.status, PoseStatus.ready);
      expect(result.bodyCenterX, closeTo(0.5, 0.05));
    });

    test('Profile feet occlusion: ankle occluded but heel/footIndex visible remains ready', () {
      final map = <PoseLandmarkType, PoseLandmark>{};
      const centerX = 360.0;
      const headY = 100.0;
      const feetY = 1100.0;

      map[PoseLandmarkType.nose] = createLm(PoseLandmarkType.nose, centerX, headY, 0.9);
      map[PoseLandmarkType.leftShoulder] = createLm(PoseLandmarkType.leftShoulder, centerX, headY + 80, 0.9);
      map[PoseLandmarkType.leftHip] = createLm(PoseLandmarkType.leftHip, centerX, headY + 300, 0.9);
      map[PoseLandmarkType.leftKnee] = createLm(PoseLandmarkType.leftKnee, centerX, headY + 550, 0.9);

      // Both ankles occluded / low likelihood
      map[PoseLandmarkType.leftAnkle] = createLm(PoseLandmarkType.leftAnkle, centerX, feetY, 0.1);
      map[PoseLandmarkType.rightAnkle] = createLm(PoseLandmarkType.rightAnkle, centerX, feetY, 0.05);

      // But heel is clearly visible!
      map[PoseLandmarkType.leftHeel] = createLm(PoseLandmarkType.leftHeel, centerX, feetY + 15, 0.85);

      final pose = Pose(landmarks: map);
      final result = MlService.instance.analyzePoses([pose], imageSize);

      expect(result.status, PoseStatus.ready);
    });

    test('Centering Hysteresis: 0.32 is rejected when not counting down, but accepted during countdown', () {
      // 0.32 * 720 = 230.4
      const x = 230.4;
      final pose = Pose(landmarks: createFullFrontLandmarks(centerX: x));

      // 1. Fresh trigger: entry corridor is [0.35, 0.65], so 0.32 must be notCentered
      final freshResult = MlService.instance.analyzePoses([pose], imageSize, isCountingDown: false);
      expect(freshResult.status, PoseStatus.notCentered);

      // 2. Active countdown: corridor widens to [0.28, 0.72], so 0.32 must remain ready!
      final countdownResult = MlService.instance.analyzePoses([pose], imageSize, isCountingDown: true);
      expect(countdownResult.status, PoseStatus.ready);
    });

    test('Centering Hysteresis: 0.68 is rejected when not counting down, but accepted during countdown', () {
      // 0.68 * 720 = 489.6
      const x = 489.6;
      final pose = Pose(landmarks: createFullFrontLandmarks(centerX: x));

      // 1. Fresh trigger: entry corridor is [0.35, 0.65], so 0.68 must be notCentered
      final freshResult = MlService.instance.analyzePoses([pose], imageSize, isCountingDown: false);
      expect(freshResult.status, PoseStatus.notCentered);

      // 2. Active countdown: corridor widens to [0.28, 0.72], so 0.68 must remain ready!
      final countdownResult = MlService.instance.analyzePoses([pose], imageSize, isCountingDown: true);
      expect(countdownResult.status, PoseStatus.ready);
    });

    test('Frame Cutoff Hysteresis: 0.985 edge cutoff is rejected normally, but accepted during countdown', () {
      // maxY will be feetY + 20 = 1240.8 + 20 = 1260.8 (1280 * 0.985)
      // Normal threshold is 0.98 (1254.4) -> rejected as notFullBody
      // Countdown threshold is 0.995 (1273.6) -> accepted as ready!
      const feetY = 1240.8;
      final pose = Pose(landmarks: createFullFrontLandmarks(feetY: feetY));

      final freshResult = MlService.instance.analyzePoses([pose], imageSize, isCountingDown: false);
      expect(freshResult.status, PoseStatus.notFullBody);

      final countdownResult = MlService.instance.analyzePoses([pose], imageSize, isCountingDown: true);
      expect(countdownResult.status, PoseStatus.ready);
    });

    test('Android landscape sensor buffer (1280x720) with 90deg rotation produces ready pose when upright size (720x1280) is used', () {
      final pose = Pose(landmarks: createFullFrontLandmarks());

      // If unrotated buffer dimensions (1280, 720) were mistakenly passed:
      const rawLandscapeBuffer = Size(1280, 720);
      final buggyResult = MlService.instance.analyzePoses([pose], rawLandscapeBuffer);
      // maxY (~1120) > 720 * 0.98 (705.6) -> permanently notFullBody!
      expect(buggyResult.status, PoseStatus.notFullBody);

      // When rotation is accounted for (swapping 1280x720 to upright 720x1280):
      final uprightSize = Size(rawLandscapeBuffer.height, rawLandscapeBuffer.width);
      final correctedResult = MlService.instance.analyzePoses([pose], uprightSize);
      expect(correctedResult.status, PoseStatus.ready);
      expect(correctedResult.bodyCenterX, closeTo(0.5, 0.05));
    });
  });
}
