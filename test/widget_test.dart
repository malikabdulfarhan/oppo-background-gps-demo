import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_background_gps_demo/main.dart';

void main() {
  testWidgets('tracking screen starts and generates a fake sample', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text('Map Track Demo'), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.text('5000 ms'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Tracking'));
    await tester.pump();

    expect(find.text('Running'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.scrollUntilVisible(
      find.text('MOV 5s'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('MOV 5s'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
