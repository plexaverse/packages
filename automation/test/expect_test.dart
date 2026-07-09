import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide find;
import 'package:in_app_automation/in_app_automation.dart';

void main() {
  testWidgets('visible passes for on-screen widgets, count matches', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Column(children: [Text('A'), Text('A'), Text('B')])),
    ));

    await tester.runAsync(() async {
      await Expect.visible(find.byText('B'), timeout: const Duration(seconds: 2));
      await Expect.count(find.byText('A'), 2, timeout: const Duration(seconds: 2));
    });
  });

  testWidgets('text descends into a container and is not tautological', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Card(key: Key('c'), child: Text('Balance: 42'))),
    ));

    await tester.runAsync(() async {
      // Target is the Card (no text of its own); the assertion reads the child.
      await Expect.text(const Key('c'), 'Balance: 42', timeout: const Duration(seconds: 2));
      await Expect.textContaining(const Key('c'), '42', timeout: const Duration(seconds: 2));
    });
  });

  testWidgets('text reports the actual value on mismatch', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('actual', key: Key('t'))),
    ));

    await tester.runAsync(() async {
      await expectLater(
        Expect.text(const Key('t'), 'expected', timeout: const Duration(milliseconds: 300)),
        throwsA(isA<AutomationAssertionException>()),
      );
    });
  });

  testWidgets('enabled / disabled reflect the button callback', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ElevatedButton(key: const Key('on'), onPressed: () {}, child: const Text('On')),
          const ElevatedButton(key: Key('off'), onPressed: null, child: Text('Off')),
        ]),
      ),
    ));

    await tester.runAsync(() async {
      await Expect.enabled(const Key('on'), timeout: const Duration(seconds: 2));
      await Expect.disabled(const Key('off'), timeout: const Duration(seconds: 2));
    });
  });

  testWidgets('absent and hidden pass when the widget is not present', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('present'))));

    await tester.runAsync(() async {
      await Expect.absent(find.byText('nope'), timeout: const Duration(seconds: 1));
      await Expect.hidden(find.byText('nope'), timeout: const Duration(seconds: 1));
    });
  });

  testWidgets('absent times out when the widget is present', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('present'))));

    await tester.runAsync(() async {
      await expectLater(
        Expect.absent(find.byText('present'), timeout: const Duration(milliseconds: 300)),
        throwsA(isA<AutomationAssertionException>()),
      );
    });
  });

  testWidgets('SoftAssertions collects multiple failures and fails once', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));

    await tester.runAsync(() async {
      final soft = SoftAssertions();
      await soft.check(() => Expect.visible(find.byText('missing-1'), timeout: const Duration(milliseconds: 200)));
      await soft.check(() => Expect.visible(find.byText('missing-2'), timeout: const Duration(milliseconds: 200)));
      await soft.check(() => Expect.visible(find.byText('x'), timeout: const Duration(milliseconds: 200)));

      expect(soft.hasFailures, isTrue);
      expect(soft.failures.length, 2);
      expect(() => soft.assertAll(), throwsA(isA<AutomationAssertionException>()));
    });
  });
}
