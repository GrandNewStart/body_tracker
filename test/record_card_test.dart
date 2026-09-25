import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_tracker/models/body_record.dart';
import 'package:body_tracker/widgets/record_card.dart';

void main() {
  testWidgets('RecordCard builds without crashing when isKorean is true', (tester) async {
    final now = DateTime.now();
    final record = BodyRecord(
      id: 'test-1',
      date: now,
      createdAt: now,
      weight: 70.0,
      frontImagePath: '/dummy/front.jpg',
      leftImagePath: '/dummy/left.jpg',
      backImagePath: '/dummy/back.jpg',
      rightImagePath: '/dummy/right.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordCard(
            record: record,
            isKorean: true,
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.byType(RecordCard), findsOneWidget);
  });
}
