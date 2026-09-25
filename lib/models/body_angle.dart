import 'body_record.dart';

enum BodyAngle {
  front,
  left,
  back,
  right;

  String label(bool isKorean) {
    switch (this) {
      case BodyAngle.front:
        return isKorean ? '정면' : 'Front';
      case BodyAngle.left:
        return isKorean ? '좌측' : 'Left';
      case BodyAngle.back:
        return isKorean ? '후면' : 'Back';
      case BodyAngle.right:
        return isKorean ? '우측' : 'Right';
    }
  }

  String getImagePath(BodyRecord record) {
    switch (this) {
      case BodyAngle.front:
        return record.frontImagePath;
      case BodyAngle.left:
        return record.leftImagePath;
      case BodyAngle.back:
        return record.backImagePath;
      case BodyAngle.right:
        return record.rightImagePath;
    }
  }
}
