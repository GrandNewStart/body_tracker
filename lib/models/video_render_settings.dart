import 'body_angle.dart';

class VideoRenderSettings {
  final double slideInterval;
  final Set<BodyAngle> selectedAngles;

  const VideoRenderSettings({
    required this.slideInterval,
    required this.selectedAngles,
  });
}
