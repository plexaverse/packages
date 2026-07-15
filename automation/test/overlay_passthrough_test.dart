import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_automation/in_app_automation.dart';

void main() {
  testWidgets('engine can tap an app button sitting under the inspector overlay', (tester) async {
    var taps = 0;

    // The inspector wand sits in the bottom-left corner. Put an app button in
    // exactly that corner so its center is beneath the wand - the case that
    // used to fail with NotActionable because the overlay obscured the target.
    await tester.pumpWidget(
      AutomationInspectorWrapper(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: ElevatedButton(
                      key: const Key('under_overlay'),
                      onPressed: () => taps++,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await AutomationEngine.instance.tap(const Key('under_overlay'), timeout: const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(taps, 1, reason: 'the inspector overlay must not block a tap on the app beneath it');
  });

  testWidgets('a genuine app overlay still blocks the tap (fix is overlay-specific)', (tester) async {
    var taps = 0;

    // A real, app-owned opaque layer on top must STILL be reported not
    // actionable - the fix only makes the automation overlay transparent, not
    // arbitrary app widgets.
    await tester.pumpWidget(
      AutomationInspectorWrapper(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: ElevatedButton(
                    key: const Key('covered'),
                    onPressed: () => taps++,
                    child: const Text('Go'),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await expectLater(
        AutomationEngine.instance.tap(const Key('covered'), timeout: const Duration(milliseconds: 600)),
        throwsA(isA<NotActionableException>()),
      );
    });
    expect(taps, 0);
  });
}
