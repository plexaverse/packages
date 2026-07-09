import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide find;
import 'package:in_app_automation/in_app_automation.dart';

void main() {
  testWidgets('returns immediately when the target is already visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('here'))));

    var returned = false;
    await tester.runAsync(() async {
      await AutomationEngine.instance.scrollUntilVisible('here');
      returned = true;
    });

    expect(returned, isTrue);
  });

  testWidgets('throws NotActionableException when there is no scrollable', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('other'))));

    await tester.runAsync(() async {
      await expectLater(
        AutomationEngine.instance.scrollUntilVisible('missing', maxScrolls: 3),
        throwsA(isA<NotActionableException>()),
      );
    });
  });

  testWidgets('the no-scrollable error names the requested axis', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));

    await tester.runAsync(() async {
      try {
        await AutomationEngine.instance.scrollUntilVisible('missing', axis: Axis.horizontal, maxScrolls: 1);
        fail('expected a NotActionableException');
      } on NotActionableException catch (e) {
        expect(e.message, contains('horizontal'));
      }
    });
  });
}
