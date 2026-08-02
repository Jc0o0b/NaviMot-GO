import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navimot_go/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo golden (motocykl)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 150, height: 150, child: AppLogo(swoosh: 1)),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(AppLogo),
      matchesGoldenFile('goldens/app_logo.png'),
    );
  });
}
