import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automation/automation.dart';

void main() {
  // Note: the "returns immediately when the UI is idle" happy-path cannot be
  // unit-tested under the automated flutter_test binding, because that binding
  // always keeps a frame pending between explicit pumps - so hasScheduledFrame
  // never reads false here the way it does in a live app. That path is
  // exercised by the live runtime (and the example integration test). What we
  // CAN and must guarantee is that the guard terminates instead of hanging
  // forever when frames never stop being scheduled:
  testWidgets('pumpAndSettle throws AutomationTimeoutException if frames never stop', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));

    await tester.runAsync(() async {
      await expectLater(
        AutomationEngine.instance.pumpAndSettle(timeout: const Duration(milliseconds: 300)),
        throwsA(isA<AutomationTimeoutException>()),
      );
    });
  });
}
