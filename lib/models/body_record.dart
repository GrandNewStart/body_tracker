class BodyRecord {
  final String id;
  final DateTime date;
  final double weight;
  final String frontImagePath;
  final String leftImagePath;
  final String backImagePath;
  final String rightImagePath;
  final bool isMasked;
  final DateTime createdAt;

  const BodyRecord({
    required this.id,
    required this.date,
    required this.weight,
    required this.frontImagePath,
    required this.leftImagePath,
    required this.backImagePath,
    required this.rightImagePath,
    this.isMasked = false,
    required this.createdAt,
  });

  BodyRecord copyWith({
    String? id,
    DateTime? date,
    double? weight,
    String? frontImagePath,
    String? leftImagePath,
    String? backImagePath,
    String? rightImagePath,
    bool? isMasked,
    DateTime? createdAt,
  }) {
    return BodyRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      frontImagePath: frontImagePath ?? this.frontImagePath,
      leftImagePath: leftImagePath ?? this.leftImagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      rightImagePath: rightImagePath ?? this.rightImagePath,
      isMasked: isMasked ?? this.isMasked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  List<String> get allImagePaths => [
    frontImagePath,
    leftImagePath,
    backImagePath,
    rightImagePath,
  ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'weight': weight,
      'front_image_path': frontImagePath,
      'left_image_path': leftImagePath,
      'back_image_path': backImagePath,
      'right_image_path': rightImagePath,
      'is_masked': isMasked,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BodyRecord.fromJson(Map<String, dynamic> json) {
    return BodyRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      weight: (json['weight'] as num).toDouble(),
      frontImagePath: json['front_image_path'] as String,
      leftImagePath: json['left_image_path'] as String,
      backImagePath: json['back_image_path'] as String,
      rightImagePath: json['right_image_path'] as String,
      isMasked: json['is_masked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
