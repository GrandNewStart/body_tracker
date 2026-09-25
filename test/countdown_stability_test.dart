import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_tracker/screens/capture_screen.dart';
import 'package:body_tracker/services/ml_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> ttsMethodCalls = [];

  setUp(() {
    ttsMethodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
      ttsMethodCalls.add(call);
      return 1;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  testWidgets('Countdown Debouncing and Stability State Machine Tests', (tester) async {
    final key = GlobalKey<CaptureScreenState>();

    await tester.pumpWidget(
      MaterialApp(
        home: CaptureScreen(key: key),
      ),
    );
    await tester.pumpAndSettle();

    final state = key.currentState!;
    expect(state.isCountingDown, isFalse);
    expect(state.consecutiveReadyFrames, 0);

    // 1. Inactive session: frames do nothing
    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.ready));
    expect(state.consecutiveReadyFrames, 0);
    expect(state.isCountingDown, isFalse);

    // 2. Activate session
    state.setSessionActiveForTest(true);

    // 3. Readiness Debounce: require 4 consecutive ready frames before countdown starts
    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.ready));
    expect(state.consecutiveReadyFrames, 1);
    expect(state.isCountingDown, isFalse);

    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.ready));
    expect(state.consecutiveReadyFrames, 2);
    expect(state.isCountingDown, isFalse);

    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.ready));
    expect(state.consecutiveReadyFrames, 3);
    expect(state.isCountingDown, isFalse);

    // If interrupted before 4th frame, counter resets!
    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.notCentered));
    expect(state.consecutiveReadyFrames, 0);
    expect(state.isCountingDown, isFalse);

    // Now send 4 consecutive ready frames
    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.ready));
    expect(state.consecutiveReadyFrames, 1);
    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.ready));
    expect(state.consecutiveReadyFrames, 2);
    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.ready));
    expect(state.consecutiveReadyFrames, 3);
    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.ready));

    // 4th frame triggers countdown!
    expect(state.isCountingDown, isTrue);
    expect(state.consecutiveReadyFrames, 0);
    final initialSessionId = state.countdownSessionId;

    // 4. Glitch Tolerance during countdown:
    // A single noisy frame or 3 noisy frames do NOT cancel countdown!
    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.notCentered));
    expect(state.isCountingDown, isTrue);
    expect(state.nonReadyFrameCount, 1);

    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.notFullBody));
    expect(state.isCountingDown, isTrue);
    expect(state.nonReadyFrameCount, 2);

    // User stabilizes -> nonReadyFrameCount resets!
    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.ready));
    expect(state.isCountingDown, isTrue);
    expect(state.nonReadyFrameCount, 0);

    // 5. Persistent Departure (>= 8 frames of non-ready): cancels countdown
    for (int i = 1; i <= 7; i++) {
      state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.notCentered));
      expect(state.isCountingDown, isTrue, reason: 'Should tolerate glitch frame $i');
      expect(state.nonReadyFrameCount, i);
    }

    // 8th frame exceeds tolerance threshold -> countdown is cancelled!
    state.handlePoseResultForTest(const PoseAnalysisResult(status: PoseStatus.notCentered));
    expect(state.isCountingDown, isFalse);
    expect(state.consecutiveReadyFrames, 0);
    expect(state.nonReadyFrameCount, 0);

    // Session ID is incremented and audio stop was dispatched
    expect(state.countdownSessionId, greaterThan(initialSessionId));
    final stopCalls = ttsMethodCalls.where((c) => c.method == 'stop').toList();
    expect(stopCalls.isNotEmpty, isTrue);

    // Clean up
    state.cancelCountdownForTest();
  });
}
