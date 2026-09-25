import 'dart:ui';

/// Represents a circular face/head region for privacy masking.
/// Coordinates [x] and [y] are normalized (0.0 to 1.0) relative to image width and height.
/// [radius] is normalized relative to image width.
class FaceMaskRegion {
  final double x;
  final double y;
  final double radius;

  const FaceMaskRegion({
    required this.x,
    required this.y,
    required this.radius,
  });

  /// Default region centered at top center of photo (typical head location)
  static const FaceMaskRegion defaultHead = FaceMaskRegion(
    x: 0.5,
    y: 0.18,
    radius: 0.14,
  );

  Offset get center => Offset(x, y);

  FaceMaskRegion copyWith({
    double? x,
    double? y,
    double? radius,
  }) {
    return FaceMaskRegion(
      x: x ?? this.x,
      y: y ?? this.y,
      radius: radius ?? this.radius,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'radius': radius,
  };

  factory FaceMaskRegion.fromJson(Map<String, dynamic> json) {
    return FaceMaskRegion(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceMaskRegion &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          radius == other.radius;

  @override
  int get hashCode => Object.hash(x, y, radius);

  @override
  String toString() => 'FaceMaskRegion(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, radius: ${radius.toStringAsFixed(3)})';
}
