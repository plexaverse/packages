import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automation/automation.dart';

void main() {
  testWidgets('tap fires a button callback via real pointer dispatch', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('go'),
            onPressed: () => taps++,
            child: const Text('Go'),
          ),
        ),
      ),
    ));

    await tester.runAsync(() async {
      await AutomationEngine.instance.tap(const Key('go'), timeout: const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('tap resolves the enclosing button from a text label', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => taps++,
            child: const Text('LOGIN'),
          ),
        ),
      ),
    ));

    await tester.runAsync(() async {
      await AutomationEngine.instance.tap('LOGIN', timeout: const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('tapping a disabled button throws NotActionableException', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            key: Key('go'),
            onPressed: null,
            child: Text('Go'),
          ),
        ),
      ),
    ));

    await tester.runAsync(() async {
      await expectLater(
        AutomationEngine.instance.tap(const Key('go'), timeout: const Duration(milliseconds: 800)),
        throwsA(isA<NotActionableException>()),
      );
    });
  });

  testWidgets('tap on a button covered by an opaque overlay is not actionable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Center(
              child: ElevatedButton(
                key: const Key('go'),
                onPressed: () => taps++,
                child: const Text('Go'),
              ),
            ),
            // A full-screen opaque layer sits on top and swallows all pointers.
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
    ));

    await tester.runAsync(() async {
      await expectLater(
        AutomationEngine.instance.tap(const Key('go'), timeout: const Duration(milliseconds: 600)),
        throwsA(isA<NotActionableException>()),
      );
    });

    // The covered button must never fire - proof that hit-testing is real and
    // the old false-green (direct-callback) behavior is gone.
    expect(taps, 0);
  });
}
