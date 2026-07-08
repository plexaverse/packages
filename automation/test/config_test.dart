import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automation/automation.dart';

void main() {
  test('enabled defaults to true outside release; enable/disable toggle it', () {
    AutomationConfig.resetToDefault();
    expect(AutomationConfig.enabled, isTrue); // tests run in debug/JIT

    AutomationConfig.disable();
    expect(AutomationConfig.enabled, isFalse);

    AutomationConfig.enable();
    expect(AutomationConfig.enabled, isTrue);

    AutomationConfig.resetToDefault();
  });

  testWidgets('engine actions throw AutomationDisabledException when disabled', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ElevatedButton(key: const Key('b'), onPressed: () {}, child: const Text('Go'))),
    ));

    AutomationConfig.disable();
    addTearDown(AutomationConfig.resetToDefault);

    await tester.runAsync(() async {
      await expectLater(
        AutomationEngine.instance.tap(const Key('b')),
        throwsA(isA<AutomationDisabledException>()),
      );
      await expectLater(
        AutomationEngine.instance.enterText(const Key('b'), 'x'),
        throwsA(isA<AutomationDisabledException>()),
      );
    });
  });

  testWidgets('opting back in with enable() restores normal tapping', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ElevatedButton(key: const Key('b'), onPressed: () => taps++, child: const Text('Go'))),
    ));

    AutomationConfig.disable();
    AutomationConfig.enable();
    addTearDown(AutomationConfig.resetToDefault);

    await tester.runAsync(() async {
      await AutomationEngine.instance.tap(const Key('b'), timeout: const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(taps, 1);
  });
}
